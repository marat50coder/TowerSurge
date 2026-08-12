import 'package:flutter/material.dart';

/// Colors picked to match the original Tower Rush layout.
class P {
  static const topBar = Color(0xFF33322F);
  static const topBarDark = Color(0xFF2A2926);
  static const bottomPanel = Color(0xFF1B1A18);
  static const bottomPanelLight = Color(0xFF2E2C29);

  static const hazardYellow = Color(0xFFF4C020);
  static const hazardBlack = Color(0xFF121212);

  static const gold = Color(0xFFE9B824);
  static const goldLight = Color(0xFFFFE07A);
  static const goldDark = Color(0xFFA9761A);

  static const blue = Color(0xFF1E86E8);
  static const blueLight = Color(0xFF57B4F7);
  static const blueDark = Color(0xFF0B5DAE);

  static const steel = Color(0xFF44607A);
  static const steelLight = Color(0xFF6C8CA8);

  static const pill = Color(0xFF8F8B5E);
  static const pillBorder = Color(0xFFE7CE7E);

  static const red = Color(0xFFE0322B);
  static const ice = Color(0xFF7FD7F5);

  static const skyTop = Color(0xFF3AA0E8);
  static const skyBottom = Color(0xFF9FDCF7);
}

class T {
  static const family = 'Nunito';

  static TextStyle black(
    double size, {
    Color color = Colors.white,
    double? spacing,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w900,
    fontSize: size,
    height: 1.05,
    letterSpacing: spacing,
    color: color,
    shadows: shadows,
  );

  static TextStyle bold(
    double size, {
    Color color = Colors.white,
    double? spacing,
  }) => TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: 1.1,
    letterSpacing: spacing,
    color: color,
  );

  static const List<Shadow> btnShadow = [
    Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 3),
  ];
}

String fmtAmount(double value) {
  final rounded = (value * 100).round() / 100;
  var text = rounded.toStringAsFixed(2);
  if (text.endsWith('00')) {
    text = text.substring(0, text.length - 3);
  } else if (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  final parts = text.split('.');
  final digits = parts.first;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('\u2009');
    buf.write(digits[i]);
  }
  return parts.length > 1 ? '${buf.toString()}.${parts[1]}' : buf.toString();
}

String fmtMultiplier(double value) {
  var text = value.toStringAsFixed(2);
  if (text.endsWith('00')) {
    text = text.substring(0, text.length - 3);
  } else if (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return 'x$text';
}
