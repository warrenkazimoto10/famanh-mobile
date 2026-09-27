import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGasColor    = Color(0xFFE65100);
const _kParcelColor = Color(0xFF5C6BC0);
const _kFoodColor   = AdiakeColors.primaryContainer;
const _kDark        = Color(0xFF1C1B1F);
const _kBg          = Color(0xFFF5F4F6);

// ── Snack helpers ─────────────────────────────────────────────────────────────

void _snackSuccess(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
      const SizedBox(width: 10),
      Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]),
    backgroundColor: const Color(0xFF2E7D32),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 3),
  ));
}

void _snackError(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
    backgroundColor: AdiakeColors.primaryContainer,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 4),
  ));
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  bool _loading = true;
  String? _error;
  AdminPricingDto? _pricing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await AdminApiExtra.adminGetPricing();
      setState(() { _pricing = p; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: AdiakeColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Tarification livraison',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recharger',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AdiakeColors.primaryContainer))
          : _error != null
              ? _ErrorBody(error: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  children: [
                    _GasPricingCard(config: _pricing!.gas, onSaved: _load),
                    const SizedBox(height: 16),
                    _ParcelPricingCard(config: _pricing!.parcel, onSaved: _load),
                    const SizedBox(height: 16),
                    _FoodPricingCard(config: _pricing!.food, onSaved: _load),
                  ],
                ),
    );
  }
}

// ─── Error body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: AdiakeColors.errorContainer, shape: BoxShape.circle),
          child: const Icon(Icons.cloud_off_rounded, size: 36, color: AdiakeColors.error),
        ),
        const SizedBox(height: 20),
        Text(error, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: AdiakeColors.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    ),
  );
}

// ─── Gas ──────────────────────────────────────────────────────────────────────

class _GasPricingCard extends StatefulWidget {
  const _GasPricingCard({required this.config, required this.onSaved});
  final Map<String, dynamic> config;
  final VoidCallback onSaved;

  @override
  State<_GasPricingCard> createState() => _GasPricingCardState();
}

class _GasPricingCardState extends State<_GasPricingCard> {
  late String _mode;
  final _flatCtrl  = TextEditingController();
  final _perKmCtrl = TextEditingController();
  final _minCtrl   = TextEditingController();
  final _maxCtrl   = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode           = widget.config['mode']?.toString() ?? 'flat';
    _flatCtrl.text  = (widget.config['flat_fee_fcfa'] ?? 500).toString();
    _perKmCtrl.text = (widget.config['per_km_fcfa']   ?? 150).toString();
    _minCtrl.text   = (widget.config['min_fee_fcfa']  ?? 0).toString();
    _maxCtrl.text   = (widget.config['max_fee_fcfa']  ?? '').toString();
  }

  @override
  void dispose() {
    _flatCtrl.dispose(); _perKmCtrl.dispose();
    _minCtrl.dispose();  _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'mode':          _mode,
        'flat_fee_fcfa': int.tryParse(_flatCtrl.text) ?? 500,
        'per_km_fcfa':   int.tryParse(_perKmCtrl.text) ?? 150,
        'min_fee_fcfa':  int.tryParse(_minCtrl.text) ?? 0,
      };
      final maxVal = int.tryParse(_maxCtrl.text);
      if (maxVal != null) data['max_fee_fcfa'] = maxVal;
      await AdminApiExtra.adminUpdateGasPricing(data);
      widget.onSaved();
      if (mounted) _snackSuccess(context, 'Tarification gaz sauvegardée');
    } catch (e) {
      if (mounted) _snackError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PricingCard(
    icon: Icons.local_fire_department_rounded,
    color: _kGasColor,
    title: 'Livraison gaz',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModeToggle(value: _mode, color: _kGasColor, onChanged: (v) => setState(() => _mode = v)),
        const SizedBox(height: 16),
        if (_mode == 'flat') ...[
          _PriceField(controller: _flatCtrl, label: 'Frais fixe', suffix: 'FCFA', color: _kGasColor),
        ] else ...[
          _PriceField(controller: _perKmCtrl, label: 'Prix par km', suffix: 'FCFA/km', color: _kGasColor),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _PriceField(controller: _minCtrl, label: 'Minimum', suffix: 'FCFA', color: _kGasColor)),
            const SizedBox(width: 12),
            Expanded(child: _PriceField(controller: _maxCtrl, label: 'Maximum', suffix: 'FCFA', color: _kGasColor, hint: '∞ (vide = sans limite)')),
          ]),
        ],
        const SizedBox(height: 20),
        _SaveButton(loading: _saving, color: _kGasColor, onPressed: _save),
      ],
    ),
  );
}

// ─── Parcel ───────────────────────────────────────────────────────────────────

class _ParcelPricingCard extends StatefulWidget {
  const _ParcelPricingCard({required this.config, required this.onSaved});
  final Map<String, dynamic> config;
  final VoidCallback onSaved;

  @override
  State<_ParcelPricingCard> createState() => _ParcelPricingCardState();
}

class _ParcelPricingCardState extends State<_ParcelPricingCard> {
  late bool _enabled;
  late String _mode;
  final _flatCtrl  = TextEditingController();
  final _perKmCtrl = TextEditingController();
  final _minCtrl   = TextEditingController();
  final _maxCtrl   = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled        = widget.config['enabled'] == true;
    _mode           = widget.config['mode']?.toString() ?? 'flat';
    _flatCtrl.text  = (widget.config['flat_fee_fcfa'] ?? 500).toString();
    _perKmCtrl.text = (widget.config['per_km_fcfa']   ?? 150).toString();
    _minCtrl.text   = (widget.config['min_fee_fcfa']  ?? 0).toString();
    _maxCtrl.text   = (widget.config['max_fee_fcfa']  ?? '').toString();
  }

  @override
  void dispose() {
    _flatCtrl.dispose(); _perKmCtrl.dispose();
    _minCtrl.dispose();  _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'enabled':       _enabled,
        'mode':          _mode,
        'flat_fee_fcfa': int.tryParse(_flatCtrl.text) ?? 500,
        'per_km_fcfa':   int.tryParse(_perKmCtrl.text) ?? 150,
        'min_fee_fcfa':  int.tryParse(_minCtrl.text) ?? 0,
      };
      final maxVal = int.tryParse(_maxCtrl.text);
      if (maxVal != null) data['max_fee_fcfa'] = maxVal;
      await AdminApiExtra.adminUpdateParcelPricing(data);
      widget.onSaved();
      if (mounted) _snackSuccess(context, 'Tarification colis sauvegardée');
    } catch (e) {
      if (mounted) _snackError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PricingCard(
    icon: Icons.inventory_2_rounded,
    color: _kParcelColor,
    title: 'Livraison colis',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ServiceToggle(
          enabled: _enabled,
          color: _kParcelColor,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        AnimatedOpacity(
          opacity: _enabled ? 1.0 : 0.38,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_enabled,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _ModeToggle(value: _mode, color: _kParcelColor, onChanged: (v) => setState(() => _mode = v)),
                const SizedBox(height: 16),
                if (_mode == 'flat') ...[
                  _PriceField(controller: _flatCtrl, label: 'Frais fixe', suffix: 'FCFA', color: _kParcelColor),
                ] else ...[
                  _PriceField(controller: _perKmCtrl, label: 'Prix par km', suffix: 'FCFA/km', color: _kParcelColor),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _PriceField(controller: _minCtrl, label: 'Minimum', suffix: 'FCFA', color: _kParcelColor)),
                    const SizedBox(width: 12),
                    Expanded(child: _PriceField(controller: _maxCtrl, label: 'Maximum', suffix: 'FCFA', color: _kParcelColor, hint: '∞ (vide = sans limite)')),
                  ]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SaveButton(loading: _saving, color: _kParcelColor, onPressed: _save),
      ],
    ),
  );
}

// ─── Food ─────────────────────────────────────────────────────────────────────

class _FoodPricingCard extends StatefulWidget {
  const _FoodPricingCard({required this.config, required this.onSaved});
  final Map<String, dynamic> config;
  final VoidCallback onSaved;

  @override
  State<_FoodPricingCard> createState() => _FoodPricingCardState();
}

class _FoodPricingCardState extends State<_FoodPricingCard> {
  final _feeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _feeCtrl.text = (widget.config['delivery_fee_fcfa'] ?? 0).toString();
  }

  @override
  void dispose() { _feeCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AdminApiExtra.adminUpdateFoodPricing(int.tryParse(_feeCtrl.text) ?? 0);
      widget.onSaved();
      if (mounted) _snackSuccess(context, 'Tarification repas sauvegardée');
    } catch (e) {
      if (mounted) _snackError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PricingCard(
    icon: Icons.restaurant_rounded,
    color: _kFoodColor,
    title: 'Livraison repas',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PriceField(
          controller: _feeCtrl,
          label: 'Frais de livraison',
          suffix: 'FCFA',
          color: _kFoodColor,
          hint: '0 = gratuit',
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: Colors.black38),
          const SizedBox(width: 6),
          const Text('Mettre 0 pour proposer la livraison gratuite',
            style: TextStyle(fontSize: 11, color: Colors.black45)),
        ]),
        const SizedBox(height: 20),
        _SaveButton(loading: _saving, color: _kFoodColor, onPressed: _save),
      ],
    ),
  );
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header band
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.12))),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: color,
            )),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(18), child: child),
      ],
    ),
  );
}

class _ServiceToggle extends StatelessWidget {
  const _ServiceToggle({required this.enabled, required this.color, required this.onChanged});
  final bool enabled;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: enabled ? color.withValues(alpha: 0.07) : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: enabled ? color.withValues(alpha: 0.20) : Colors.transparent),
    ),
    child: Row(children: [
      Icon(
        enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: enabled ? color : Colors.black38,
        size: 18,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(
        enabled ? 'Service activé' : 'Service désactivé',
        style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14,
          color: enabled ? color : Colors.black45,
        ),
      )),
      Switch.adaptive(value: enabled, onChanged: onChanged, activeColor: color),
    ]),
  );
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.value, required this.color, required this.onChanged});
  final String value;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Mode de calcul',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _ModeChip(
          label: 'Fixe', icon: Icons.attach_money_rounded,
          active: value == 'flat', color: color,
          onTap: () => onChanged('flat'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _ModeChip(
          label: 'Par km', icon: Icons.route_rounded,
          active: value == 'per_km', color: color,
          onTap: () => onChanged('per_km'),
        )),
      ]),
    ],
  );
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label, required this.icon,
    required this.active, required this.color, required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: active ? color : const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(11),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))]
            : [],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: active ? Colors.white : Colors.black45),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: active ? Colors.white : Colors.black54,
        )),
      ]),
    ),
  );
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.color,
    this.hint,
  });
  final TextEditingController controller;
  final String label;
  final String suffix;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kDark),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
      suffixText: suffix,
      suffixStyle: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w700),
      filled: true,
      fillColor: color.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color.withValues(alpha: 0.22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.loading, required this.color, required this.onPressed});
  final bool loading;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.4),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_rounded, size: 18),
              SizedBox(width: 8),
              Text('Sauvegarder', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3)),
            ]),
    ),
  );
}
