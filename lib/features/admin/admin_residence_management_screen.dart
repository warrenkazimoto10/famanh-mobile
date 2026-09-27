import 'package:flutter/material.dart';
import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/money_text.dart';
import 'package:intl/intl.dart';

class AdminResidenceManagementScreen extends StatefulWidget {
  const AdminResidenceManagementScreen({super.key});

  @override
  State<AdminResidenceManagementScreen> createState() => _AdminResidenceManagementScreenState();
}

class _AdminResidenceManagementScreenState extends State<AdminResidenceManagementScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _pendingPayments = [];
  List<dynamic> _allBookings = [];
  DateTime _selectedDate = DateTime.now();
  Map<String, bool> _blockedSlots = {}; // Format: "residenceId-checkIn-checkOut" -> isBlocked

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Load pending payments
      final pendingResult = await ApiClient.getPendingResidencePayments();
      // Load all bookings (you might want to add this API endpoint)
      // For now, we'll use the same endpoint or create a mock
      
      if (!mounted) return;
      setState(() {
        _pendingPayments = pendingResult['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _confirmPayment(String bookingId) async {
    try {
      await ApiClient.updateResidenceBookingStatus(
        bookingId: int.parse(bookingId),
        status: 'confirmed',
      );
      await _loadData(); // Refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement confirmé et réservation mise à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _rejectPayment(String bookingId) async {
    try {
      await ApiClient.updateResidenceBookingStatus(
        bookingId: int.parse(bookingId),
        status: 'cancelled',
      );
      await _loadData(); // Refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement rejeté et réservation annulée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildPendingPaymentsSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_error!, style: const TextStyle(color: AdiakeColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_pendingPayments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Aucun paiement en attente'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PAIEMENTS EN ATTENTE',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AdiakeColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingPayments.length,
            itemBuilder: (context, index) {
              final payment = _pendingPayments[index];
              return _PaymentItem(
                payment: payment,
                onConfirm: _confirmPayment,
                onReject: _rejectPayment,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdiakeColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'GESTION DES RÉSERVATIONS',
          style: TextStyle(
            color: AdiakeColors.primaryContainer,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _buildPendingPaymentsSection(),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final dynamic payment;
  final Future<void> Function(String) onConfirm;
  final Future<void> Function(String) onReject;

  const _PaymentItem({
    required this.payment,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    // Assuming payment structure based on what we'd expect from API
    final residenceName = payment['residence_name'] ?? 'Résidence inconnue';
    final clientName = payment['client_name'] ?? 'Client inconnu';
    final clientPhone = payment['client_phone'] ?? 'Non spécifié';
    final checkIn = payment['check_in'] ?? 'Date inconnue';
    final checkOut = payment['check_out'] ?? 'Date inconnue';
    final totalPrice = payment['total_price'] ?? 0;
    final depositAmount = (totalPrice * 0.1).ceil();
    final bookingId = payment['id']?.toString() ?? '';
    final status = payment['status'] ?? 'pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      residenceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AdiakeColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Client: $clientName',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AdiakeColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Téléphone: $clientPhone',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AdiakeColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Séjour: $checkIn au $checkOut',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AdiakeColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Text(
                    'Dépôt requis',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdiakeColors.onSurfaceVariant,
                    ),
                  ),
                  MoneyText(depositAmount),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
             children: [
               IconButton(
                 icon: const Icon(Icons.phone),
                 color: AdiakeColors.primaryContainer,
                 onPressed: clientPhone != 'Non spécifié' && clientPhone.isNotEmpty
                     ? () {
                         // In a real app, this would launch the phone dialer
                         // For now, we'll show a snack bar
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Appel vers $clientPhone initié')),
                         );
                       }
                     : null,
               ),
               const SizedBox(width: 8),
               ElevatedButton(
                 onPressed: status == 'pending' ? () => onConfirm(bookingId) : null,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AdiakeColors.primaryContainer,
                 ),
                 child: const Text('CONFIRMER PAIEMENT'),
               ),
               ElevatedButton(
                 onPressed: status == 'pending' ? () => onReject(bookingId) : null,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AdiakeColors.error,
                 ),
                 child: const Text('REJETER'),
               ),
             ],
           ),
        ],
      ),
      ),
    );
  }
}