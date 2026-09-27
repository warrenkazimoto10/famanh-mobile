import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';
import '../theme/adiake_colors.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(UiTokens.s16),
    this.borderRadius = UiTokens.r16,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? UiTokens.surface;
    final b = borderColor ?? UiTokens.borderColor.withValues(alpha: 0.55);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: b, width: UiTokens.border1),
        boxShadow: [
          BoxShadow(
            color: AdiakeColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

