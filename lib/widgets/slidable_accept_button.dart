import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Un bouton coulissant animé ("Slide to accept") moderne et réactif.
class SlidableAcceptButton extends StatefulWidget {
  const SlidableAcceptButton({
    super.key,
    this.label = 'Glisser pour accepter la course',
    required this.onAccept,
    this.height = 52.0,
    this.backgroundColor,
    this.activeColor,
  });

  final String label;
  final Future<void> Function() onAccept;
  final double height;
  final Color? backgroundColor;
  final Color? activeColor;

  @override
  State<SlidableAcceptButton> createState() => _SlidableAcceptButtonState();
}

class _SlidableAcceptButtonState extends State<SlidableAcceptButton> with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final trackBg = widget.backgroundColor ?? const Color(0xFF0052FF);
    final activeBg = widget.activeColor ?? const Color(0xFF003CBF);

    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbSize = widget.height - 8.0;
        final maxDrag = (constraints.maxWidth - thumbSize - 8.0).clamp(1.0, double.infinity);
        final dragRatio = (_dragPosition / maxDrag).clamp(0.0, 1.0);

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: trackBg,
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: trackBg.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Active fill background extending as user slides
              AnimatedContainer(
                duration: const Duration(milliseconds: 40),
                width: (_dragPosition + thumbSize + 8.0).clamp(widget.height, constraints.maxWidth),
                height: widget.height,
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),

              // Centered label text with arrow indicator that fades as drag progresses
              Center(
                child: Opacity(
                  opacity: (1.0 - (dragRatio * 1.3)).clamp(0.0, 1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Sliding Thumb / Knob
              Positioned(
                left: _dragPosition + 4.0,
                top: 4.0,
                child: GestureDetector(
                  onHorizontalDragUpdate: _submitting
                      ? null
                      : (details) {
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: _submitting
                      ? null
                      : (details) async {
                          if (_dragPosition >= maxDrag * 0.68) {
                            // Trigger action
                            setState(() {
                              _dragPosition = maxDrag;
                              _submitting = true;
                            });
                            HapticFeedback.heavyImpact();
                            try {
                              await widget.onAccept();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _submitting = false;
                                  _dragPosition = 0.0;
                                });
                              }
                            }
                          } else {
                            // Snap back smoothly
                            setState(() {
                              _dragPosition = 0.0;
                            });
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _submitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: trackBg,
                              ),
                            )
                          : Icon(
                              Icons.arrow_forward_rounded,
                              color: trackBg,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
