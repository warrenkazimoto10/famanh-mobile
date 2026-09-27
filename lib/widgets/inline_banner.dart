import 'package:flutter/material.dart';

import '../theme/adiake_colors.dart';
import 'app_card.dart';

enum BannerTone { info, success, warning, danger }

class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.text,
    this.tone = BannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final BannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color _bg() {
    return switch (tone) {
      BannerTone.success => const Color(0xFFB9EEAB),
      BannerTone.warning => const Color(0xFFFFDEA5),
      BannerTone.danger => AdiakeColors.errorContainer,
      BannerTone.info => const Color(0xFFFFD9D6),
    };
  }

  Color _fg() {
    return switch (tone) {
      BannerTone.danger => AdiakeColors.onErrorContainer,
      _ => AdiakeColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fg();
    return AppCard(
      backgroundColor: _bg().withValues(alpha: 0.70),
      child: Row(
        children: [
          Icon(icon ?? Icons.info_outline, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(color: fg, fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }
}

