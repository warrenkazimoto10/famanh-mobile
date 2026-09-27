import 'package:flutter/material.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_toast.dart';
import 'parcel_express_screen.dart';

enum ParcelSpeed { ultraFast, standard }

class ParcelExpeditionScreen extends StatefulWidget {
  const ParcelExpeditionScreen({
    super.key,
    required this.draft,
  });

  final ParcelDraft draft;

  @override
  State<ParcelExpeditionScreen> createState() => _ParcelExpeditionScreenState();
}

class _ParcelExpeditionScreenState extends State<ParcelExpeditionScreen> {
  ParcelSpeed _speed = ParcelSpeed.ultraFast; // UX uniquement: le prix est celui du back-office
  bool _submitting = false;
  int? _fee;

  int get _deliveryFee => _fee ?? 0;

  int get _total => _deliveryFee;

  String _packageLabel() {
    String base;
    switch (widget.draft.type) {
      case ParcelType.documents:
        base = 'Documents';
        break;
      case ParcelType.small:
        base = 'Petit Colis';
        break;
      case ParcelType.fragile:
        base = 'Fragile / Électro';
        break;
      case ParcelType.heavy:
        base = 'Grand / Lourd';
        break;
    }
    final rec = [];
    if (widget.draft.recipientName != null && widget.draft.recipientName!.isNotEmpty) {
      rec.add(widget.draft.recipientName);
    }
    if (widget.draft.recipientPhone != null && widget.draft.recipientPhone!.isNotEmpty) {
      rec.add(widget.draft.recipientPhone);
    }
    if (rec.isNotEmpty) {
      base += ' (Destinataire: ${rec.join(" - ")})';
    }
    if (widget.draft.notes != null && widget.draft.notes!.isNotEmpty) {
      base += ' [${widget.draft.notes}]';
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    _refreshFee();
  }

  Future<void> _refreshFee() async {
    final dropLat = widget.draft.dropoffLat;
    final dropLng = widget.draft.dropoffLng;
    if (dropLat == null || dropLng == null) return;
    try {
      final fee = await ApiClient.estimateParcelDeliveryFeeFcfa(
        pickupLat: widget.draft.pickupLat,
        pickupLng: widget.draft.pickupLng,
        dropoffLat: dropLat,
        dropoffLng: dropLng,
      );
      if (!mounted) return;
      setState(() => _fee = fee);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context,
        "Impossible d'estimer les frais d'expédition. Vérifie ta connexion.",
      );
    }
  }

  Future<void> _confirm() async {
    if (_submitting) return;

    final dropLat = widget.draft.dropoffLat;
    final dropLng = widget.draft.dropoffLng;
    if (dropLat == null || dropLng == null) {
      await showDialog<void>(
        context: context,
        builder: (_) => const _ResultDialog(
          success: false,
          title: 'Destination manquante',
          message: "Choisis l'adresse d'arrivée sur la carte.",
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _refreshFee();
      final res = await ApiClient.createParcelOrder(
        pickupAddress: widget.draft.pickupLabel,
        pickupLat: widget.draft.pickupLat,
        pickupLng: widget.draft.pickupLng,
        dropoffAddress: widget.draft.dropoffLabel,
        dropoffLat: dropLat,
        dropoffLng: dropLng,
        packageLabel: _packageLabel(),
        weightKg: widget.draft.estimatedWeightKg,
        declaredValueFcfa: 0,
        deliveryFeeFcfa: _total,
      );

      final id = (res['data'] is Map) ? (res['data']['id']?.toString() ?? '') : '';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ResultDialog(
          success: true,
          title: 'Commande envoyée',
          message: id.isEmpty ? 'Votre commande de colis a été créée.' : 'Votre commande de colis a été créée (#$id).',
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _ResultDialog(
          success: false,
          title: 'Échec',
          message: e.toString(),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: AdiakeColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: AdiakeColors.primaryContainer,
                ),
                title: Text(
                  'Expédition'.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AdiakeColors.primaryContainer,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 220 + bottom),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed(
                    [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Détails du trajet',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AdiakeColors.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB9EEAB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'EN DIRECT',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AdiakeColors.onSurface,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        borderRadius: 22,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                _Dot(color: Colors.white, border: AdiakeColors.primaryContainer),
                                const SizedBox(height: 8),
                                Container(
                                  width: 2,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AdiakeColors.outlineVariant,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Icon(Icons.location_on, color: AdiakeColors.primaryContainer),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _RouteLine(
                                    label: 'Départ',
                                    value: widget.draft.pickupLabel ?? 'Non défini',
                                  ),
                                  const SizedBox(height: 14),
                                  _RouteLine(
                                    label: 'Arrivée',
                                    value: widget.draft.dropoffLabel ?? 'Non défini',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Vitesse de livraison',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AdiakeColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _SpeedCard(
                        recommended: true,
                        active: _speed == ParcelSpeed.ultraFast,
                        icon: Icons.bolt,
                        title: 'Ultra-Rapide',
                        subtitle: 'Moins de 60 min • Priorité Or',
                        price: _deliveryFee,
                        onTap: () => setState(() => _speed = ParcelSpeed.ultraFast),
                      ),
                      const SizedBox(height: 12),
                      _SpeedCard(
                        recommended: false,
                        active: _speed == ParcelSpeed.standard,
                        icon: Icons.schedule,
                        title: 'Standard',
                        subtitle: "Aujourd'hui • Avant 18h00",
                        price: _deliveryFee,
                        onTap: () => setState(() => _speed = ParcelSpeed.standard),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomConfirmBar(
              total: _total,
              deliveryFee: _deliveryFee,
              loading: _submitting,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.border});
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: border, width: 2),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AdiakeColors.outline,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AdiakeColors.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({
    required this.recommended,
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
  });

  final bool recommended;
  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? AdiakeColors.primaryContainer : AdiakeColors.outlineVariant.withValues(alpha: 0.30),
            width: active ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AdiakeColors.primary.withValues(alpha: 0.05),
              blurRadius: 34,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recommended) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AdiakeColors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Recommandé'.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: active ? AdiakeColors.primaryContainer : const Color(0xFFEDEEEF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: active ? Colors.white : AdiakeColors.outline, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AdiakeColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AdiakeColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_fmt(price)} FCFA',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: active ? AdiakeColors.primaryContainer : AdiakeColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (active) ...[
                      const SizedBox(height: 6),
                      const Icon(Icons.check_circle, color: AdiakeColors.primaryContainer, size: 20),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomConfirmBar extends StatelessWidget {
  const _BottomConfirmBar({
    required this.total,
    required this.deliveryFee,
    required this.onConfirm,
    required this.loading,
  });

  final int total;
  final int deliveryFee;
  final VoidCallback onConfirm;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 18 + bottom),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        border: Border(
          top: BorderSide(color: AdiakeColors.primaryContainer.withValues(alpha: 0.10)),
        ),
        boxShadow: [
          BoxShadow(
            color: AdiakeColors.primary.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Livraison'.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AdiakeColors.outline,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                '${_fmt(deliveryFee)} FCFA',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AdiakeColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total à régler'.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AdiakeColors.outline,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmt(total),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AdiakeColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'FCFA',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AdiakeColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB9EEAB).withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Taxe incluse'.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AdiakeColors.onSurface,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: loading ? null : onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: AdiakeColors.primaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text("Confirmer l'envoi"),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _fmt(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idxFromEnd = s.length - i;
    buf.write(s[i]);
    if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(' ');
  }
  return buf.toString().trim();
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.success,
    required this.title,
    required this.message,
  });

  final bool success;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final icon = success ? Icons.check_circle : Icons.error_outline;
    final color = success ? const Color(0xFF16A34A) : AdiakeColors.error;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AdiakeColors.primary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AdiakeColors.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AdiakeColors.primaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'OK',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

