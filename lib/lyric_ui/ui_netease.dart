import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';

///Sample Netease style
///should be extends LyricUI implementation your own UI.
///this property only for change UI,if not demand just only overwrite methods.
class UINetease extends LyricUI {
  double defaultSize;
  double defaultExtSize;
  double otherMainSize;
  double bias;
  double lineGap;
  double inlineGap;
  LyricAlign lyricAlign;
  LyricBaseLine lyricBaseLine;
  bool highlight;
  HighlightDirection highlightDirection;
  Color highlightColor;
  TextStyle playingMainTextStyle;
  TextStyle otherMainTextStyle;
  UINetease({
    this.defaultSize = 18,
    this.defaultExtSize = 14,
    this.otherMainSize = 16,
    this.bias = 0.5,
    this.lineGap = 25,
    this.inlineGap = 25,
    this.lyricAlign = LyricAlign.CENTER,
    this.lyricBaseLine = LyricBaseLine.CENTER,
    this.highlight = true,
    this.highlightColor = Colors.amber,
    this.highlightDirection = HighlightDirection.LTR,
    TextStyle? playingMainTextStyle,
    TextStyle? otherMainTextStyle,
  })  : playingMainTextStyle = playingMainTextStyle ??
            TextStyle(color: Colors.white, fontSize: defaultSize),
        otherMainTextStyle = otherMainTextStyle ??
            TextStyle(color: Colors.grey[200], fontSize: otherMainSize);

  UINetease.clone(UINetease uiNetease)
      : this(
            defaultSize: uiNetease.defaultSize,
            defaultExtSize: uiNetease.defaultExtSize,
            otherMainSize: uiNetease.otherMainSize,
            bias: uiNetease.bias,
            lineGap: uiNetease.lineGap,
            inlineGap: uiNetease.inlineGap,
            lyricAlign: uiNetease.lyricAlign,
            lyricBaseLine: uiNetease.lyricBaseLine,
            highlight: uiNetease.highlight,
            highlightDirection: uiNetease.highlightDirection,
            highlightColor: uiNetease.highlightColor,
            playingMainTextStyle: uiNetease.playingMainTextStyle,
            otherMainTextStyle: uiNetease.otherMainTextStyle);

  @override
  TextStyle getPlayingExtTextStyle() =>
      TextStyle(color: Colors.grey[300], fontSize: defaultExtSize);

  @override
  TextStyle getOtherExtTextStyle() => TextStyle(
        color: Colors.grey[300],
        fontSize: defaultExtSize,
      );

  @override
  TextStyle getOtherMainTextStyle() => otherMainTextStyle;

  @override
  TextStyle getPlayingMainTextStyle() => playingMainTextStyle;

  @override
  Color getLyricHightlightColor() => highlightColor;

  @override
  double getInlineSpace() => inlineGap;

  @override
  double getLineSpace() => lineGap;

  @override
  double getPlayingLineBias() => bias;

  @override
  LyricAlign getLyricHorizontalAlign() => lyricAlign;

  @override
  LyricBaseLine getBiasBaseLine() => lyricBaseLine;

  @override
  bool enableHighlight() => highlight;

  @override
  HighlightDirection getHighlightDirection() => highlightDirection;
}
