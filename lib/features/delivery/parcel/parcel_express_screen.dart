import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes.dart';
import '../../../data/api_client.dart';
import '../../../data/api_session.dart';
import '../gas_delivery_location_screen.dart';

enum ParcelType { documents, small, fragile, heavy }

class ParcelDraft {
  const ParcelDraft({
    this.type = ParcelType.documents,
    this.pickupLabel,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLabel,
    this.dropoffLat,
    this.dropoffLng,
    this.estimatedWeightKg,
    this.recipientName,
    this.recipientPhone,
    this.notes,
  });

  final ParcelType type;
  final String? pickupLabel;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropoffLabel;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? estimatedWeightKg;
  final String? recipientName;
  final String? recipientPhone;
  final String? notes;

  ParcelDraft copyWith({
    ParcelType? type,
    String? pickupLabel,
    double? pickupLat,
    double? pickupLng,
    String? dropoffLabel,
    double? dropoffLat,
    double? dropoffLng,
    double? estimatedWeightKg,
    String? recipientName,
    String? recipientPhone,
    String? notes,
    bool clearPickup = false,
    bool clearDropoff = false,
  }) {
    return ParcelDraft(
      type: type ?? this.type,
      pickupLabel: clearPickup ? null : (pickupLabel ?? this.pickupLabel),
      pickupLat: clearPickup ? null : (pickupLat ?? this.pickupLat),
      pickupLng: clearPickup ? null : (pickupLng ?? this.pickupLng),
      dropoffLabel: clearDropoff ? null : (dropoffLabel ?? this.dropoffLabel),
      dropoffLat: clearDropoff ? null : (dropoffLat ?? this.dropoffLat),
      dropoffLng: clearDropoff ? null : (dropoffLng ?? this.dropoffLng),
      estimatedWeightKg: estimatedWeightKg ?? this.estimatedWeightKg,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      notes: notes ?? this.notes,
    );
  }
}

class ParcelExpressScreen extends StatefulWidget {
  const ParcelExpressScreen({super.key});

  @override
  State<ParcelExpressScreen> createState() => _ParcelExpressScreenState();
}

class _ParcelExpressScreenState extends State<ParcelExpressScreen> {
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  ParcelDraft _draft = const ParcelDraft();
  bool _loadingFee = false;
  int? _fee;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _loadPreferredLocation();
  }

  void _loadPreferredLocation() {
    final me = ApiSession.currentUser.value;
    if (me != null && me.preferredLat != null && me.preferredLng != null) {
      setState(() {
        _draft = _draft.copyWith(
          pickupLabel: me.preferredAddress ?? 'Ma position enregistrée',
          pickupLat: me.preferredLat,
          pickupLng: me.preferredLng,
        );
        _pickupCtrl.text = me.preferredAddress ?? 'Ma position enregistrée';
      });
    }
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _choosePickupOnMap() async {
    final res = await Navigator.of(context).pushNamed(AppRoutes.gasLocation);
    if (!mounted || res == null) return;
    if (res is! DeliveryLocationResult) return;
    setState(() {
      _draft = _draft.copyWith(
        pickupLabel: res.addressLabel,
        pickupLat: res.location.latitude,
        pickupLng: res.location.longitude,
      );
      _pickupCtrl.text = res.addressLabel;
    });
    _updateFeeAndDistance();
  }

  Future<void> _chooseDropoffOnMap() async {
    final res = await Navigator.of(context).pushNamed(AppRoutes.gasLocation);
    if (!mounted || res == null) return;
    if (res is! DeliveryLocationResult) return;
    setState(() {
      _draft = _draft.copyWith(
        dropoffLabel: res.addressLabel,
        dropoffLat: res.location.latitude,
        dropoffLng: res.location.longitude,
      );
      _dropoffCtrl.text = res.addressLabel;
    });
    _updateFeeAndDistance();
  }

  Future<void> _updateFeeAndDistance() async {
    if (_draft.dropoffLat == null || _draft.dropoffLng == null) return;

    if (_draft.pickupLat != null && _draft.pickupLng != null) {
      const distanceCalc = Distance();
      final distMeters = distanceCalc.as(
        LengthUnit.Meter,
        LatLng(_draft.pickupLat!, _draft.pickupLng!),
        LatLng(_draft.dropoffLat!, _draft.dropoffLng!),
      );
      _distanceKm = (distMeters / 1000.0);
    }

    setState(() => _loadingFee = true);
    try {
      final f = await ApiClient.estimateParcelDeliveryFeeFcfa(
        pickupLat: _draft.pickupLat,
        pickupLng: _draft.pickupLng,
        dropoffLat: _draft.dropoffLat!,
        dropoffLng: _draft.dropoffLng!,
      );
      if (!mounted) return;
      setState(() => _fee = f);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFee = false);
    }
  }

  String _fmt(int amount) {
    final s = amount.toString();
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write(' ');
      sb.write(s[i]);
    }
    return sb.toString();
  }

  void _proceedToConfirmation() {
    final pickupLabel = _pickupCtrl.text.trim().isEmpty ? _draft.pickupLabel : _pickupCtrl.text.trim();
    final dropoffLabel = _dropoffCtrl.text.trim().isEmpty ? _draft.dropoffLabel : _dropoffCtrl.text.trim();

    if (dropoffLabel == null || dropoffLabel.isEmpty || _draft.dropoffLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner l\'adresse de destination sur la carte.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updatedDraft = _draft.copyWith(
      pickupLabel: pickupLabel,
      dropoffLabel: dropoffLabel,
      recipientName: _recipientNameCtrl.text.trim(),
      recipientPhone: _recipientPhoneCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );

    Navigator.of(context).pushNamed(AppRoutes.parcelExpedition, arguments: updatedDraft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Header Gradient Famanh Premium
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            elevation: 0,
            scrolledUnderElevation: 2,
            backgroundColor: const Color(0xFF006194),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF006194), Color(0xFF0A2540)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 14),
                alignment: Alignment.bottomLeft,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Expédition de Colis',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Livraison Express & Sécurisée',
                          style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. CARTE ITINÉRAIRE (Départ & Arrivée)
                _buildRouteCard(),

                const SizedBox(height: 20),

                // 2. TYPE DE COLIS
                _buildSectionHeader('Type de colis', 'SÉLECTION'),
                const SizedBox(height: 12),
                _buildParcelTypeGrid(),

                const SizedBox(height: 20),

                // 3. INFORMATIONS DESTINATAIRE
                _buildSectionHeader('Destinataire & Consignes', 'CONTACT'),
                const SizedBox(height: 12),
                _buildRecipientCard(),

                const SizedBox(height: 20),

                // 4. RÉSUMÉ TARIF & DÉLAI
                _buildFeeSummaryCard(),
              ]),
            ),
          ),
        ],
      ),

      // BARRE FLOTTANTE DE VALIDATION EN BAS
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _proceedToConfirmation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Continuer vers la confirmation',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String badge) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0A2540)),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Text(
            badge,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF059669), letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded, color: Color(0xFF006194), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Itinéraire de livraison',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A2540)),
              ),
              const Spacer(),
              if (_distanceKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '~ ${_distanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // LIGNE DE TRAJET VISUELLE
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const SizedBox(height: 14),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  ),
                  Container(
                    width: 2,
                    height: 44,
                    color: Colors.grey[300],
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Color(0xFF0052FF), shape: BoxShape.circle),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    // CHAMP DÉPART
                    TextField(
                      controller: _pickupCtrl,
                      decoration: InputDecoration(
                        labelText: 'Point de ramassage (Départ)',
                        hintText: 'Adresse de départ…',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.map_rounded, color: Color(0xFF006194), size: 20),
                          onPressed: _choosePickupOnMap,
                          tooltip: 'Choisir sur la carte',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // CHAMP ARRIVÉE
                    TextField(
                      controller: _dropoffCtrl,
                      decoration: InputDecoration(
                        labelText: 'Destination (Arrivée)',
                        hintText: 'Adresse d\'arrivée…',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.pin_drop_rounded, color: Color(0xFF0052FF), size: 20),
                          onPressed: _chooseDropoffOnMap,
                          tooltip: 'Choisir sur la carte',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParcelTypeGrid() {
    final types = [
      (
        type: ParcelType.documents,
        title: 'Documents',
        sub: 'Pli, contrat, passeport',
        icon: Icons.description_rounded,
        color: const Color(0xFF3B82F6),
      ),
      (
        type: ParcelType.small,
        title: 'Petit Colis',
        sub: 'Paquet < 5 kg, sac',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF10B981),
      ),
      (
        type: ParcelType.fragile,
        title: 'Fragile / Électro',
        sub: 'Téléphone, matériel',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFFF59E0B),
      ),
      (
        type: ParcelType.heavy,
        title: 'Grand / Lourd',
        sub: 'Bagage, carton',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: types.length,
      itemBuilder: (ctx, idx) {
        final item = types[idx];
        final selected = _draft.type == item.type;

        return GestureDetector(
          onTap: () => setState(() => _draft = _draft.copyWith(type: item.type)),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? item.color.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? item.color : Colors.grey.shade200,
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: selected ? item.color : const Color(0xFF0A2540),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.sub,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _recipientNameCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              labelText: 'Nom du destinataire (Optionnel)',
              hintText: 'ex: Jean Kouassi',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _recipientPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              labelText: 'Téléphone du destinataire (Optionnel)',
              hintText: 'ex: 07 08 09 10 11',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.notes_rounded, size: 20),
              labelText: 'Consignes de livraison (Optionnel)',
              hintText: 'ex: Déposer au gardien, appeler avant d\'arriver…',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2540), Color(0xFF006194)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006194).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TARIF ESTIMÉ DE LIVRAISON',
                  style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  _loadingFee
                      ? 'Calcul en cours...'
                      : (_fee == null ? 'Sélectionner l\'arrivée' : '${_fmt(_fee!)} FCFA'),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Livraison Express (< 60 min)',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}
