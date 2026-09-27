import 'package:flutter/material.dart';

import '../theme/adiake_colors.dart';

class DateText extends StatelessWidget {
  const DateText(
    this.dt, {
    super.key,
    this.color,
    this.bold = false,
  });

  final DateTime dt;
  final Color? color;
  final bool bold;

  static String formatFr(DateTime dt) {
    final d = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');

    if (day == today) return "Aujourd’hui $hh:$mm";
    if (day == today.subtract(const Duration(days: 1))) return "Hier $hh:$mm";

    final dd = d.day.toString().padLeft(2, '0');
    final mo = d.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatFr(dt),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color ?? AdiakeColors.onSurfaceVariant,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
    );
  }
}

