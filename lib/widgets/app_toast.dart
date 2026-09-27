import 'package:flutter/material.dart';
import '../theme/adiake_colors.dart';

class AppToast {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Icons.check_circle_rounded, AdiakeColors.secondary);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Icons.error_rounded, AdiakeColors.error);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Icons.info_rounded, AdiakeColors.primaryContainer);
  }

  static void _show(BuildContext context, String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
