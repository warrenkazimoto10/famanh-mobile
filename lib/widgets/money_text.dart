import 'package:flutter/material.dart';

import '../theme/adiake_colors.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amountFcfa, {
    super.key,
    this.bold = true,
    this.prefix = 'FCFA',
    this.color,
    this.style,
    this.fontSize,
  });

  final int amountFcfa;
  final bool bold;
  final String prefix;
  final Color? color;

  /// Style additionnel fusionné par-dessus le style par défaut.
  final TextStyle? style;

  /// Raccourci pour surcharger uniquement la taille de police.
  final double? fontSize;

  static String fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(' ');
    }
    return buf.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    var effectiveStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color ?? AdiakeColors.primaryContainer,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        );
    if (style != null) {
      effectiveStyle = effectiveStyle?.merge(style);
    }
    if (fontSize != null) {
      effectiveStyle = effectiveStyle?.copyWith(fontSize: fontSize);
    }
    return Text(
      '${fmt(amountFcfa)} $prefix',
      style: effectiveStyle,
    );
  }
}

