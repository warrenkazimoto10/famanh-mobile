import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SwipeToAcceptSlider extends StatefulWidget {
  const SwipeToAcceptSlider({
    super.key,
    required this.onAccept,
    this.label = 'Glisser pour accepter  >>>',
    this.backgroundColor = const Color(0xFF0F172A),
    this.sliderColor = const Color(0xFF10B981),
    this.height = 58,
  });

  final Future<void> Function() onAccept;
  final String label;
  final Color backgroundColor;
  final Color sliderColor;
  final double height;

  @override
  State<SwipeToAcceptSlider> createState() => _SwipeToAcceptSliderState();
}

class _SwipeToAcceptSliderState extends State<SwipeToAcceptSlider> with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isAccepted = false;
  bool _isLoading = false;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - widget.height;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: widget.sliderColor.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1. Progression colorée
              Container(
                width: _dragPosition + widget.height,
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.sliderColor.withValues(alpha: 0.4),
                      widget.sliderColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),

              // 2. Texte animé central
              Center(
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    final opacity = 0.5 + (_shimmerController.value * 0.5);
                    return Opacity(
                      opacity: _isLoading ? 0.3 : opacity,
                      child: Text(
                        _isLoading ? 'Acceptation en cours...' : widget.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. Bouton coulissant (Knob)
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isAccepted || _isLoading) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) async {
                    if (_isAccepted || _isLoading) return;
                    if (_dragPosition >= maxDrag * 0.8) {
                      // Déclenchement de l'acceptation
                      setState(() {
                        _dragPosition = maxDrag;
                        _isAccepted = true;
                        _isLoading = true;
                      });
                      try {
                        await widget.onAccept();
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            _dragPosition = 0;
                            _isAccepted = false;
                            _isLoading = false;
                          });
                        }
                      }
                    } else {
                      // Retour au point de départ
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  child: Container(
                    width: widget.height,
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: widget.sliderColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 28,
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
