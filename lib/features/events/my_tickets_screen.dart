import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late Future<List<EventBookingDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = EventApi.fetchMyTickets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdiakeColors.background,
      appBar: AppBar(
        backgroundColor: AdiakeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mes Billets & Pass',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _future = EventApi.fetchMyTickets()),
          ),
        ],
      ),
      body: FutureBuilder<List<EventBookingDto>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('${snap.error}', textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _future = EventApi.fetchMyTickets()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          final tickets = snap.data ?? [];
          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎟️', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 16),
                  const Text('Aucun billet pour le moment',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18,
                          color: Color(0xFF131B2E))),
                  const SizedBox(height: 8),
                  Text('Vos billets d\'événements\napparaîtront ici.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AdiakeColors.outline, fontSize: 14)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = EventApi.fetchMyTickets()),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) => _TicketCard(
                booking: tickets[i],
                onTap: () => _showQrFullScreen(tickets[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQrFullScreen(EventBookingDto booking) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _QrFullScreen(booking: booking),
      ),
    );
  }
}

// ─── Ticket Card ──────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final EventBookingDto booking;
  final VoidCallback onTap;
  const _TicketCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPaid = booking.isPaid;
    final isScanned = booking.isScanned;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top: event image strip
            if (booking.eventImageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    Image.network(
                      booking.eventImageUrl!,
                      width: double.infinity,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 110,
                        color: AdiakeColors.surfaceContainer,
                      ),
                    ),
                    Container(
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isScanned ? Colors.grey.shade700
                              : isPaid ? const Color(0xFF006C49)
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isScanned ? '✅ Utilisé' : isPaid ? '🎟️ Valide' : '⏳ En attente',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10, left: 14,
                      child: Text(
                        booking.eventTitle ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 15,
                            shadows: [Shadow(blurRadius: 8, color: Colors.black54)]),
                      ),
                    ),
                  ],
                ),
              ),

            // Dashed separator
            _DashedDivider(),

            // Ticket info + QR preview
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  // QR Code
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isScanned ? Colors.grey.shade100 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isScanned ? Colors.grey.shade300
                              : AdiakeColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: ColorFiltered(
                        colorFilter: isScanned
                            ? const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 1, 0,
                              ])
                            : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                        child: QrImageView(
                          data: booking.qrCodeToken,
                          size: 80,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.bookingReference,
                            style: TextStyle(fontWeight: FontWeight.w800,
                                fontSize: 13, color: AdiakeColors.primary,
                                letterSpacing: 0.8, fontFamily: 'monospace')),
                        const SizedBox(height: 6),
                        _TicketInfoRow(Icons.confirmation_number_rounded,
                            booking.ticketTypeName ?? ''),
                        const SizedBox(height: 3),
                        _TicketInfoRow(Icons.people_rounded, '${booking.quantity} billet(s)'),
                        const SizedBox(height: 3),
                        if (booking.eventStartsAt != null)
                          _TicketInfoRow(Icons.calendar_today_rounded,
                              DateFormat('d MMM y', 'fr').format(booking.eventStartsAt!)),
                        const SizedBox(height: 3),
                        if (booking.eventLocation != null)
                          _TicketInfoRow(Icons.location_on_rounded, booking.eventLocation!),
                        const SizedBox(height: 8),
                        Text(
                          '${NumberFormat('#,###', 'fr').format(booking.totalAmountFcfa)} FCFA',
                          style: TextStyle(fontWeight: FontWeight.w800,
                              fontSize: 16, color: AdiakeColors.secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tap hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isScanned ? Colors.grey.shade100
                    : AdiakeColors.primary.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.zoom_in_rounded,
                      size: 16,
                      color: isScanned ? Colors.grey : AdiakeColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    isScanned ? 'Billet déjà utilisé' : 'Appuyez pour agrandir le QR Code',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isScanned ? Colors.grey : AdiakeColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TicketInfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AdiakeColors.outline),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
        ),
      ],
    );
  }
}

// ─── Dashed Divider (ticket perforation effect) ───────────────────────────────

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: CustomPaint(
        size: const Size(double.infinity, 24),
        painter: _DashedPainter(),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final leftHole = Offset(-14, size.height / 2);
    final rightHole = Offset(size.width + 14, size.height / 2);
    canvas.drawCircle(leftHole, 14, Paint()..color = AdiakeColors.background);
    canvas.drawCircle(rightHole, 14, Paint()..color = AdiakeColors.background);

    double x = 14;
    const dashW = 8.0, gapW = 6.0;
    final y = size.height / 2;
    while (x < size.width - 14) {
      canvas.drawLine(Offset(x, y), Offset(x + dashW, y), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── QR Full Screen ──────────────────────────────────────────────────────────

class _QrFullScreen extends StatelessWidget {
  final EventBookingDto booking;
  const _QrFullScreen({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isScanned = booking.isScanned;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(booking.bookingReference,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                fontSize: 14, fontFamily: 'monospace')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Code
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withOpacity(0.2),
                        blurRadius: 40, spreadRadius: 4),
                  ],
                ),
                child: Column(
                  children: [
                    ColorFiltered(
                      colorFilter: isScanned
                          ? const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                      child: QrImageView(
                        data: booking.qrCodeToken,
                        size: 240,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: isScanned ? Colors.grey : const Color(0xFF006194),
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: isScanned ? Colors.grey : const Color(0xFF131B2E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(booking.bookingReference,
                        style: const TextStyle(fontWeight: FontWeight.w800,
                            fontSize: 18, letterSpacing: 2,
                            color: Color(0xFF006194), fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            if (isScanned)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text('Billet déjà utilisé',
                        style: TextStyle(color: Colors.grey,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              )
            else ...[
              Text(booking.eventTitle ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              Text(booking.ticketTypeName ?? '',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 4),
              if (booking.eventStartsAt != null)
                Text(
                  DateFormat('EEEE d MMMM y • HH:mm', 'fr').format(booking.eventStartsAt!),
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              const SizedBox(height: 4),
              if (booking.eventLocation != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    Text(booking.eventLocation!,
                        style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF006C49),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${booking.quantity} billet(s) valide(s)',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
