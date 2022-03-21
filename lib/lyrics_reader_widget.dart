import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';
import 'package:flutter_lyric/lyric_ui/ui_netease.dart';
import 'package:flutter_lyric/lyrics_log.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:flutter_lyric/lyrics_reader_paint.dart';

///SelectLineBuilder
///[int] is select progress
///[VoidCallback] call VoidCallback.call(),select current
typedef SelectLineBuilder = Widget Function(int, VoidCallback);

///Lyrics Reader Widget
///[size] config widget size,default is screenWidth,screenWidth
///[ui]  config lyric style
///[position] music progress,unit is millisecond
///[selectLineBuilder] call select line widget
///
class LyricsReader extends StatefulWidget {
  final Size size;
  final LyricsReaderModel? model;
  final LyricUI ui;
  final int position;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final SelectLineBuilder? selectLineBuilder;

  @override
  State<StatefulWidget> createState() => LyricReaderState();

  LyricsReader({this.position = 0,
    this.model,
    this.padding,
    this.size = Size.infinite,
    this.selectLineBuilder,
    LyricUI? lyricUi,
    this.onTap})
      : ui = lyricUi ?? UINetease();
}

class LyricReaderState extends State<LyricsReader>
    with TickerProviderStateMixin {
  late LyricsReaderPaint lyricPaint;

  StreamController<int> centerLyricIndexStream = StreamController.broadcast();
  AnimationController? _flingController;
  AnimationController? _lineController;

  var mSize = Size.infinite;

  var isDrag = false;

  /// 等待恢复
  var isWait = false;

  ///缓存下lineIndex避免重复获取
  var cacheLine = -1;

  BoxConstraints? cacheBox;

  @override
  void initState() {
    super.initState();
    lyricPaint = LyricsReaderPaint(widget.model, widget.ui)
      ..centerLyricIndexChangeCall = (index) {
        centerLyricIndexStream.add(index);
      };
  }

  var isShowSelectLineWidget = false;

  ///show select line
  void setSelectLine(bool isShow) {
    if (!mounted) return;
    setState(() {
      isShowSelectLineWidget = isShow;
    });
  }

  @override
  void didUpdateWidget(covariant LyricsReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size.toString() != widget.size.toString() ||
        oldWidget.model != widget.model ||
        oldWidget.ui != widget.ui) {
      lyricPaint.model = widget.model;
      lyricPaint.lyricUI = widget.ui;
      handleSize();
      scrollToPlayLine();
    }

    if (oldWidget.position != widget.position) {
      selectLine(widget.model?.getCurrentLine(widget.position) ?? 0);
      if (cacheLine != lyricPaint.playingIndex) {
        cacheLine = lyricPaint.playingIndex;
        scrollToPlayLine();
      }
    }
  }

  ///select current play line
  void scrollToPlayLine() {
    safeLyricOffset(widget.model?.computeScroll(
        lyricPaint.playingIndex, lyricPaint.playingIndex, widget.ui) ??
        0);
  }

  void selectLine(int line) {
    lyricPaint.playingIndex = line;
  }

  ///update progress after verify
  safeLyricOffset(double offset) {
    if (isDrag || isWait) return;
    if (_flingController?.isAnimating == true) return;
    realUpdateOffset(offset);
  }

  void realUpdateOffset(double offset) {
    if (widget.ui.enableLineAnimation()) {
      animationOffset(offset);
    } else {
      lyricPaint.lyricOffset = offset;
    }
  }

  ///update progress use animation
  void animationOffset(double offset) {
    disposeLine();
    _lineController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    var animate = Tween<double>(
      begin: lyricPaint.lyricOffset,
      end: offset,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_lineController!)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          disposeLine();
        }
      });
    animate
      ..addListener(() {
        var value = animate.value;
        lyricPaint.lyricOffset = value.clamp(lyricPaint.maxOffset, 0);
      });
    _lineController?.forward();
  }

  ///calculate all line draw info
  refreshLyricHeight(Size size) {
    lyricPaint.clearCache();

    widget.model?.lyrics.forEach((element) {
      var drawInfo = LyricDrawInfo()
        ..playingExtTextPainter = getTextPaint(
            element.extText, widget.ui.getPlayingExtTextStyle(),

            size: size)
        ..otherExtTextPainter = getTextPaint(
            element.extText, widget.ui.getOtherExtTextStyle(),
            size: size)
        ..playingMainTextPainter = getTextPaint(
            element.mainText, widget.ui.getPlayingMainTextStyle(),
            size: size)
        ..otherMainTextPainter = getTextPaint(
            element.mainText, widget.ui.getOtherMainTextStyle(),
            size: size);
      if(widget.ui.enableHighlight()){
        setTextInlineInfo(drawInfo, widget.ui, element.mainText!);
      }
      element.drawInfo = drawInfo;
    });
  }

  /// 获取文本高度
  TextPainter getTextPaint(String? text, TextStyle style, {Size? size}) {
    if (text == null) text = "";
    var linePaint = TextPainter(
      textDirection: TextDirection.ltr,
    );
    linePaint.textAlign = lyricPaint.lyricUI.getLyricTextAligin();
    linePaint
      ..text = TextSpan(text: text, style: style.copyWith(height: 1))
      ..layout(maxWidth: (size ?? mSize).width);
    return linePaint;
  }

  void setTextInlineInfo(LyricDrawInfo drawInfo, LyricUI ui, String text) {
    var linePaint = drawInfo.playingMainTextPainter!;
    var metrics = linePaint.computeLineMetrics();
    var targetLineHeight = 0.0;
    var start = 0;
    List<LyricInlineDrawInfo> lineList = [];
    drawInfo.lineWidth = 0;
    metrics.forEach((element) {
      //起始偏移量X
      var startOffsetX = 0.0;
      switch (ui.getLyricTextAligin()) {
        case TextAlign.right:
          startOffsetX = linePaint.width - element.width;
          break;
        case TextAlign.center:
          startOffsetX = (linePaint.width - element.width) / 2;
          break;
        default:
          break;
      }
      //获取总宽度
      drawInfo.lineWidth += element.width;
      var offsetX = element.width;
      switch (ui.getLyricTextAligin()) {
        case TextAlign.right:
          offsetX = linePaint.width;
          break;
        case TextAlign.center:
          offsetX = (linePaint.width - element.width) / 2 + element.width;
          break;
        default:
          break;
      }
      var end = linePaint
          .getPositionForOffset(Offset(offsetX, targetLineHeight))
          .offset;
      var lineText = text.substring(start, end);
      LyricsLog.logD("获取行内信息：第${element.lineNumber}行，内容：${lineText}");
      lineList.add(LyricInlineDrawInfo()
        ..raw = lineText
        ..number = element.lineNumber
        ..width = element.width
        ..height = element.height
        ..offset = Offset(startOffsetX, targetLineHeight));
      start = end;
      targetLineHeight += element.height;
    });
    drawInfo.inlineDrawList = lineList;
  }

  ///handle widget size
  ///default screenWidth,screenWidth
  ///if outside box has limit,then select min value
  handleSize() {
    mSize = widget.size;
    if (mSize.width == double.infinity) {
      mSize = Size(MediaQuery
          .of(context)
          .size
          .width, mSize.height);
    }
    if (mSize.height == double.infinity) {
      mSize = Size(mSize.width, mSize.width);
    }
    if (cacheBox != null) {
      if (cacheBox!.maxWidth != double.infinity) {
        mSize = Size(min(cacheBox!.maxWidth, mSize.width), mSize.height);
      }
      if (cacheBox!.maxHeight != double.infinity) {
        mSize = Size(mSize.width, min(cacheBox!.maxHeight, mSize.height));
      }
    }
    refreshLyricHeight(mSize);
  }

  @override
  Widget build(BuildContext context) {
    return buildTouchReader(Stack(
      children: [
        buildReaderWidget(),
        if (widget.selectLineBuilder != null &&
            isShowSelectLineWidget &&
            lyricPaint.centerY != 0)
          buildSelectLineWidget()
      ],
    ));
  }

  Positioned buildSelectLineWidget() {
    return Positioned(
      child: Container(
        height: lyricPaint.centerY * 2,
        child: Center(
          child: StreamBuilder<int>(
              stream: centerLyricIndexStream.stream,
              builder: (context, snapshot) {
                var centerIndex = snapshot.data ?? 0;
                return widget.selectLineBuilder!.call(
                    lyricPaint.model?.lyrics[centerIndex].startTime ?? 0, () {
                  setSelectLine(false);
                  disposeFiling();
                  disposeSelectLineDelay();
                });
              }),
        ),
      ),
      top: 0,
      left: 0,
      right: 0,
    );
  }

  ///build reader widget
  Container buildReaderWidget() {
    return Container(
      padding: widget.padding ?? EdgeInsets.zero,
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (c, box) {
          if (cacheBox?.toString() != box.toString()) {
            cacheBox = box;
            handleSize();
          }
          return CustomPaint(
            painter: lyricPaint,
            size: mSize,
          );
        },
      ),
    );
  }

  ///support touch event
  Widget buildTouchReader(child) {
    return GestureDetector(
      onVerticalDragEnd: handleDragEnd,
      onTap: widget.onTap,
      onTapDown: (event) {
        disposeSelectLineDelay();
        disposeFiling();
        isDrag = true;
      },
      onTapUp: (event) {
        isDrag = false;
        resumeSelectLineOffset();
      },
      onVerticalDragStart: (event) {
        disposeFiling();
        disposeSelectLineDelay();
        setSelectLine(true);
      },
      onVerticalDragUpdate: (event) =>
      {lyricPaint.lyricOffset += event.primaryDelta ?? 0},
      child: child,
    );
  }

  handleDragEnd(DragEndDetails event) {
    isDrag = false;
    _flingController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (_flingController == null) return;
        var flingOffset = _flingController!.value;
        lyricPaint.lyricOffset = flingOffset.clamp(lyricPaint.maxOffset, 0);
        if (!lyricPaint.checkOffset(flingOffset)) {
          disposeFiling();
          resumeSelectLineOffset();
          return;
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          disposeFiling();
          resumeSelectLineOffset();
        }
      })
      ..animateWith(ClampingScrollSimulation(
        position: lyricPaint.lyricOffset,
        velocity: event.primaryVelocity ?? 0,
      ));
  }

  Timer? waitTimer;

  ///handle select line
  resumeSelectLineOffset() {
    isWait = true;
    var waitSecond = 0;
    waitTimer?.cancel();
    waitTimer = new Timer.periodic(Duration(milliseconds: 100), (timer) {
      waitSecond += 100;
      if (waitSecond == 400) {
        realUpdateOffset(widget.model?.computeScroll(
            lyricPaint.centerLyricIndex,
            lyricPaint.playingIndex,
            widget.ui) ??
            0);
        return;
      }
      if (waitSecond == 3000) {
        disposeSelectLineDelay();
        setSelectLine(false);
        scrollToPlayLine();
      }
    });
  }

  disposeSelectLineDelay() {
    isWait = false;
    waitTimer?.cancel();
  }

  disposeFiling() {
    _flingController?.dispose();
    _flingController = null;
  }

  disposeLine() {
    _lineController?.dispose();
    _lineController = null;
  }

  @override
  void dispose() {
    disposeSelectLineDelay();
    disposeFiling();
    disposeLine();
    centerLyricIndexStream.close();
    super.dispose();
  }
}
