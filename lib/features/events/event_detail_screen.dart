import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import 'my_tickets_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<EventDto> _future;
  int _selectedTicketIndex = 0;
  int _quantity = 1;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _future = EventApi.fetchEventDetail(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdiakeColors.background,
      body: FutureBuilder<EventDto>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('${snap.error}')),
            );
          }
          final event = snap.data!;
          final selectedTicket = event.ticketTypes.isNotEmpty &&
                  _selectedTicketIndex < event.ticketTypes.length
              ? event.ticketTypes[_selectedTicketIndex]
              : null;
          final totalFcfa = (selectedTicket?.priceFcfa ?? 0) * _quantity;
          final showBottomBar =
              selectedTicket != null && !selectedTicket.isSoldOut;

          return Stack(
            children: [
              _buildScrollContent(event),
              if (showBottomBar)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _BottomBookingBar(
                    ticket: selectedTicket,
                    quantity: _quantity,
                    totalFcfa: totalFcfa,
                    loading: _booking,
                    onBook: () => _doBook(event.id, selectedTicket),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScrollContent(EventDto event) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Hero Image ─────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: const Color(0xFF0A2540),
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.black38,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: IconButton(
                  icon: const Icon(Icons.confirmation_number_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  event.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF1A3A6B)),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB95F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(event.category,
                            style: const TextStyle(
                                color: Color(0xFF2A1700),
                                fontWeight: FontWeight.w800,
                                fontSize: 11)),
                      ),
                      const SizedBox(height: 8),
                      Text(event.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black54)
                              ])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Body Content ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info card
                _InfoCard(event: event),
                const SizedBox(height: 20),

                // Description
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  const Text('À propos',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF131B2E))),
                  const SizedBox(height: 8),
                  Text(event.description!,
                      style: TextStyle(
                          fontSize: 14,
                          color: AdiakeColors.onSurfaceVariant,
                          height: 1.6)),
                  const SizedBox(height: 24),
                ],

                // Ticket types
                if (event.ticketTypes.isNotEmpty) ...[
                  const Text('Choisissez votre billet',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF131B2E))),
                  const SizedBox(height: 12),
                  ...event.ticketTypes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final tt = entry.value;
                    final selected = _selectedTicketIndex == i;
                    return GestureDetector(
                      onTap: tt.isSoldOut
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedTicketIndex = i;
                                _quantity = 1;
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tt.isSoldOut
                              ? Colors.grey.shade100
                              : selected
                                  ? AdiakeColors.primary.withOpacity(0.08)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: tt.isSoldOut
                                ? Colors.grey.shade300
                                : selected
                                    ? AdiakeColors.primary
                                    : AdiakeColors.outlineVariant
                                        .withOpacity(0.6),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Radio indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AdiakeColors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? AdiakeColors.primary
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tt.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: tt.isSoldOut
                                              ? Colors.grey
                                              : const Color(0xFF131B2E))),
                                  if (tt.benefits != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(tt.benefits!,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AdiakeColors.outline)),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tt.isSoldOut
                                        ? 'COMPLET'
                                        : '${tt.remainingQuantity} restant(s)',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: tt.isSoldOut
                                            ? Colors.red
                                            : AdiakeColors.secondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              tt.priceFcfa == 0
                                  ? 'Gratuit'
                                  : '${NumberFormat('#,###', 'fr').format(tt.priceFcfa)}\nFCFA',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: tt.isSoldOut
                                      ? Colors.grey
                                      : AdiakeColors.primary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Quantity picker
                  if (_selectedTicketIndex < event.ticketTypes.length &&
                      !event.ticketTypes[_selectedTicketIndex].isSoldOut) ...[
                    _QuantityPicker(
                      quantity: _quantity,
                      maxQty: event
                          .ticketTypes[_selectedTicketIndex].remainingQuantity,
                      onDecrement: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      onIncrement:
                          _quantity < event.ticketTypes[_selectedTicketIndex]
                                      .remainingQuantity &&
                                  _quantity < 10
                              ? () => setState(() => _quantity++)
                              : null,
                    ),
                    // Space for bottom bar
                    const SizedBox(height: 110),
                  ],
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdiakeColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_rounded, color: Color(0xFF005236)),
                        SizedBox(width: 8),
                        Text('Entrée libre — aucun billet requis.',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF005236))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _doBook(int eventId, TicketTypeDto ticket) async {
    if (ApiSession.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour acheter un billet.')),
      );
      return;
    }
    setState(() => _booking = true);
    try {
      final booking = await EventApi.bookEvent(
        eventId: eventId,
        ticketTypeId: ticket.id,
        quantity: _quantity,
      );
      if (!mounted) return;
      setState(() => _booking = false);
      _showSuccessSheet(booking);
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSheet(EventBookingDto booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSuccessSheet(booking: booking),
    );
  }
}

// ── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final EventDto event;
  const _InfoCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AdiakeColors.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            iconColor: AdiakeColors.primary,
            label: 'Date & Heure',
            value: DateFormat('EEEE d MMMM y • HH:mm', 'fr')
                .format(event.startsAt),
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.location_on_rounded,
            iconColor: AdiakeColors.secondary,
            label: 'Lieu',
            value: event.locationName,
          ),
          if (event.organizerName != null) ...[
            const Divider(height: 20),
            _InfoRow(
              icon: Icons.person_rounded,
              iconColor: AdiakeColors.tertiary,
              label: 'Organisateur',
              value:
                  '${event.organizerName}${event.organizerPhone != null ? '\n${event.organizerPhone}' : ''}',
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: AdiakeColors.outline,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF131B2E))),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Quantity Picker ──────────────────────────────────────────────────────────

class _QuantityPicker extends StatelessWidget {
  final int quantity;
  final int maxQty;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  const _QuantityPicker(
      {required this.quantity,
      required this.maxQty,
      this.onDecrement,
      this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AdiakeColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Quantité',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: onDecrement),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$quantity',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              _QtyButton(icon: Icons.add, onTap: onIncrement),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AdiakeColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: onTap != null ? Colors.white : Colors.grey, size: 18),
      ),
    );
  }
}

// ── Bottom Booking Bar ───────────────────────────────────────────────────────

class _BottomBookingBar extends StatelessWidget {
  final TicketTypeDto ticket;
  final int quantity;
  final int totalFcfa;
  final bool loading;
  final VoidCallback onBook;
  const _BottomBookingBar(
      {required this.ticket,
      required this.quantity,
      required this.totalFcfa,
      required this.loading,
      required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total pour $quantity billet(s)',
                    style: TextStyle(
                        fontSize: 12, color: AdiakeColors.outline)),
                const SizedBox(height: 2),
                Text(
                  totalFcfa == 0
                      ? 'Gratuit'
                      : '${NumberFormat('#,###', 'fr').format(totalFcfa)} FCFA',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AdiakeColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdiakeColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Réserver 🎟️',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Booking Success Sheet ────────────────────────────────────────────────────

class _BookingSuccessSheet extends StatelessWidget {
  final EventBookingDto booking;
  const _BookingSuccessSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AdiakeColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF006C49), size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Réservation Confirmée !',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Color(0xFF131B2E))),
          const SizedBox(height: 8),
          Text('Réf : ${booking.bookingReference}',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AdiakeColors.primary,
                  letterSpacing: 1)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdiakeColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _SheetRow('Événement', booking.eventTitle ?? ''),
                const SizedBox(height: 8),
                _SheetRow('Type billet', booking.ticketTypeName ?? ''),
                const SizedBox(height: 8),
                _SheetRow('Quantité', '${booking.quantity}'),
                const SizedBox(height: 8),
                _SheetRow('Montant payé',
                    '${NumberFormat('#,###', 'fr').format(booking.totalAmountFcfa)} FCFA'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
                );
              },
              icon: const Icon(Icons.confirmation_number_rounded),
              label: const Text('Voir mon billet QR',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdiakeColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  const _SheetRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: AdiakeColors.outline)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF131B2E))),
        ),
      ],
    );
  }
}
