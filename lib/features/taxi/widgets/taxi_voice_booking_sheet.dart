import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceBookingResult {
  final String voiceNoteDuration;
  final String audioPlaceholderKey;
  final int seats;
  final String simulatedTranscription;

  VoiceBookingResult({
    required this.voiceNoteDuration,
    required this.audioPlaceholderKey,
    required this.seats,
    required this.simulatedTranscription,
  });
}

class TaxiVoiceBookingSheet extends StatefulWidget {
  final Function(VoiceBookingResult result) onConfirmed;

  const TaxiVoiceBookingSheet({
    super.key,
    required this.onConfirmed,
  });

  static Future<VoiceBookingResult?> show(BuildContext context) {
    return showModalBottomSheet<VoiceBookingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: TaxiVoiceBookingSheet(
          onConfirmed: (res) => Navigator.of(ctx).pop(res),
        ),
      ),
    );
  }

  @override
  State<TaxiVoiceBookingSheet> createState() => _TaxiVoiceBookingSheetState();
}

class _TaxiVoiceBookingSheetState extends State<TaxiVoiceBookingSheet> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _hasRecorded = false;
  int _recordSeconds = 0;
  Timer? _timer;
  int _selectedSeats = 1;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _hasRecorded = false;
      _recordSeconds = 0;
    });
    _animController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
      if (_recordSeconds >= 30) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    _animController.stop();
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_rounded, color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'COMMANDE VOCALE DIRECTE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF59E0B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            _isRecording
                ? 'Parlez maintenant...'
                : (_hasRecorded ? 'Message vocal prêt !' : 'Appuyez pour dicter votre course'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isRecording
                ? 'Dites où vous êtes et où vous souhaitez aller'
                : 'Exemple : "Je suis au Débarcadère, je vais au Marché"',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 24),

          // Glowing Mic Button / Waveform
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isRecording) {
                        _stopRecording();
                      } else {
                        _startRecording();
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final scale = _isRecording ? (1.0 + (_animController.value * 0.22)) : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isRecording
                                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                    : (_hasRecorded
                                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                        : [const Color(0xFFF59E0B), const Color(0xFFD97706)]),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording ? Colors.red : const Color(0xFFF59E0B)).withOpacity(0.4),
                                  blurRadius: _isRecording ? 30 : 15,
                                  spreadRadius: _isRecording ? 8 : 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop_rounded : (_hasRecorded ? Icons.check_rounded : Icons.mic_rounded),
                              color: Colors.white,
                              size: 52,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isRecording || _hasRecorded) ...[
                    Text(
                      '${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Seats Selector (1, 2, 3 places)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nombre de places :',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                Row(
                  children: [1, 2, 3].map((s) {
                    final isSel = _selectedSeats == s;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedSeats = s),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFFF59E0B) : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$s place${s > 1 ? 's' : ''}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSel ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _hasRecorded
                  ? () {
                      widget.onConfirmed(VoiceBookingResult(
                        voiceNoteDuration: '$_recordSeconds s',
                        audioPlaceholderKey: 'voice_order_${DateTime.now().millisecondsSinceEpoch}',
                        seats: _selectedSeats,
                        simulatedTranscription: 'Demande vocale Adiaké ($_recordSeconds s)',
                      ));
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                disabledBackgroundColor: Colors.white12,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Envoyer la demande vocale aux taxis',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
