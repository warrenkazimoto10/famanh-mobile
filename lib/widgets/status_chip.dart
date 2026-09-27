import 'package:flutter/material.dart';

import '../domain/delivery_status.dart';
import '../theme/adiake_colors.dart';
import '../theme/ui_tokens.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.compact = true,
  });

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase().trim();
    final bg = DeliveryStatus.chipColor(s);
    final label = DeliveryStatus.labelFr(s).toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(UiTokens.r24),
        border: Border.all(color: AdiakeColors.primaryContainer.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AdiakeColors.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
      ),
    );
  }
}

