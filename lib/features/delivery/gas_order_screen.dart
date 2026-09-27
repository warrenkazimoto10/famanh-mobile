import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../app/routes.dart';
import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_toast.dart';
import 'gas_delivery_location_screen.dart';

class GasFormatOption {
  final String key;
  final String title;
  final String subtitle;
  final int defaultPrice;
  final String? badge;
  final IconData icon;

  const GasFormatOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.defaultPrice,
    this.badge,
    required this.icon,
  });
}

class GasOrderScreen extends StatefulWidget {
  const GasOrderScreen({super.key});

  @override
  State<GasOrderScreen> createState() => _GasOrderScreenState();
}

class _GasOrderScreenState extends State<GasOrderScreen> {
  List<GasProductDto> _products = const [];

  // Default brands matching user request and mockup
  final List<String> _defaultBrands = [
    'TotalEnergies',
    'Oryx Energies',
    'Petroci',
    'Shell Vivo',
  ];

  // Formats matching user request and mockup
  final List<GasFormatOption> _formats = const [
    GasFormatOption(
      key: 'B6',
      title: 'B6',
      subtitle: '6kg Domestique',
      defaultPrice: 2500,
      icon: Icons.propane_tank_outlined,
    ),
    GasFormatOption(
      key: 'B12',
      title: 'B12 (Domestique 12.5kg)',
      subtitle: 'Recommandé pour la maison',
      defaultPrice: 5200,
      icon: Icons.propane_tank,
    ),
    GasFormatOption(
      key: 'B28',
      title: 'B28 (Professionnel 28kg)',
      subtitle: 'Usage professionnel & restaurants',
      defaultPrice: 13000,
      badge: 'Pro',
      icon: Icons.propane,
    ),
  ];

  // Selection states
  late String _selectedBrand;
  late String _selectedFormatKey;
  int _qty = 1;
  bool _hasExchangeBottle = true;
  int _deliveryFee = 500;
  String? _deliveryLabel;
  DeliveryLocationResult? _delivery;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedBrand = _defaultBrands.first;
    _selectedFormatKey = 'B12'; // Default active format B12
    _loadProducts();
    _loadPreferredLocation();
  }

  void _loadPreferredLocation() {
    final me = ApiSession.currentUser.value;
    if (me != null && me.preferredLat != null && me.preferredLng != null) {
      setState(() {
        _delivery = DeliveryLocationResult(
          location: LatLng(me.preferredLat!, me.preferredLng!),
          addressLabel: me.preferredAddress ?? 'Quartier Résidentiel, Adiaké',
        );
        _deliveryLabel = me.preferredAddress ?? 'Quartier Résidentiel, Adiaké';
      });
    } else {
      _deliveryLabel = 'Quartier Résidentiel, Adiaké';
    }
  }

  Future<void> _loadProducts() async {
    try {
      final items = await ApiClient.getGasProducts();
      final fee = await ApiClient.getGasDeliveryFeeFcfa(
        lat: _delivery?.location.latitude,
        lng: _delivery?.location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _products = items;
        if (fee > 0) _deliveryFee = fee;
      });
    } catch (_) {}
  }

  List<String> get _brands {
    if (_products.isEmpty) return _defaultBrands;
    final apiBrands = _products.map((e) => e.brand.trim()).where((b) => b.isNotEmpty).toSet().toList();
    for (final b in _defaultBrands) {
      if (!apiBrands.contains(b)) apiBrands.add(b);
    }
    return apiBrands;
  }

  GasProductDto? _findMatchingProduct() {
    if (_products.isEmpty) return null;

    try {
      return _products.firstWhere(
        (p) =>
            p.brand.toLowerCase().trim() == _selectedBrand.toLowerCase().trim() &&
            p.size.toLowerCase().contains(_selectedFormatKey.toLowerCase()),
      );
    } catch (_) {
      try {
        return _products.firstWhere(
          (p) => p.size.toLowerCase().contains(_selectedFormatKey.toLowerCase()),
        );
      } catch (_) {
        return _products.first;
      }
    }
  }

  int get _unitPrice {
    final match = _findMatchingProduct();
    if (match != null && match.priceFcfa > 0) {
      return match.priceFcfa;
    }
    final formatOpt = _formats.firstWhere(
      (f) => f.key == _selectedFormatKey,
      orElse: () => _formats[1],
    );
    return formatOpt.defaultPrice;
  }

  int get _bottleDeposit {
    if (_hasExchangeBottle) return 0;
    final match = _findMatchingProduct();
    if (match != null && match.bottleDepositFcfa > 0) {
      return match.bottleDepositFcfa;
    }
    return 1500; // Standard deposit when no empty bottle is exchanged
  }

  int get _totalAmount => (_unitPrice * _qty) + (_bottleDeposit * _qty) + _deliveryFee;

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

  Future<void> _chooseLocation() async {
    final res = await Navigator.of(context).pushNamed(AppRoutes.gasLocation);
    if (!mounted) return;
    if (res is DeliveryLocationResult) {
      setState(() {
        _delivery = res;
        _deliveryLabel = res.addressLabel;
      });
      _refreshDeliveryFee();
    }
  }

  Future<void> _refreshDeliveryFee() async {
    if (_delivery == null) return;
    try {
      final fee = await ApiClient.getGasDeliveryFeeFcfa(
        lat: _delivery!.location.latitude,
        lng: _delivery!.location.longitude,
      );
      if (!mounted) return;
      if (fee > 0) {
        setState(() => _deliveryFee = fee);
      }
    } catch (_) {}
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;

    if (_delivery == null) {
      await _chooseLocation();
      if (!mounted || _delivery == null) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final match = _findMatchingProduct();
      final productId = match?.id ?? 1;

      await ApiClient.createGasOrder(
        gasProductId: productId,
        qty: _qty,
        hasExchangeBottle: _hasExchangeBottle,
        deliveryLat: _delivery?.location.latitude ?? 5.2863,
        deliveryLng: _delivery?.location.longitude ?? -3.3040,
        deliveryAddress: _deliveryLabel ?? 'Quartier Résidentiel, Adiaké',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showSuccessModal();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.showError(context, "Erreur lors de la commande: $e");
    }
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF6CF8BB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF00714D),
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Commande Transmise !',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AdiakeColors.onSurface,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre livreur Famanh prépare votre bouteille. Arrivée estimée dans 35 minutes au ${_deliveryLabel ?? "Quartier Résidentiel"}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AdiakeColors.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006194),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Suivre mon coursier',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF131B2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF006194).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFF006194), size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'Commande Bouteille Gaz',
              style: TextStyle(
                color: Color(0xFF131B2E),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF006194),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HERO SHOWCASE CARD ──────────────────────────────────
                _buildHeroCard(),

                const SizedBox(height: 24),

                // ── 1. MARQUE DU DISTRIBUTEUR ───────────────────────────
                _buildBrandSelector(),

                const SizedBox(height: 24),

                // ── 2. CHOISIR LE FORMAT ────────────────────────────────
                _buildFormatSelector(),

                const SizedBox(height: 24),

                // ── QUANTITE & OPTIONS ──────────────────────────────────
                _buildQuantityAndOptionsCard(),

                const SizedBox(height: 20),

                // ── POINT DE LIVRAISON ──────────────────────────────────
                _buildDeliveryPointCard(),
              ],
            ),
          ),

          // ── FLOATING STICKY ACTION BAR ──────────────────────────────
          _buildStickyActionBar(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // WIDGET BUILDERS
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF2F3FF), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF006194).withValues(alpha: 0.06),
                ),
              ),
              Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuCS9gHuZYDLkf9pj58tqmkKkZZGhOBkVydXwj9KmVPU3XPU4i-ynFiClVJTarS4v2PkF98TYtfRQROgmaJMkkZRJFszshOtdChMtHxp76IHVySkcNToYcmvXedBPfHCWnJem9k42vCEKL73GHsJNHyClkN3_uwPE0_0vWI5fMkEMkYnlJbn7IN8vlMp8DpYA8ixiAPGmwRTctWjztrU_ozKzeKBlgftTRUcqUVPuapOtHaMVAP7c1bZ',
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.propane_tank_rounded,
                  size: 140,
                  color: Color(0xFF006194),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Bouteille de Gaz à domicile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF131B2E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Livraison rapide en 35 minutes sur Adiaké',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF707881),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSelector() {
    final brandsList = _brands;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '1. MARQUE DU DISTRIBUTEUR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: Color(0xFF707881),
              ),
            ),
            Text(
              _selectedBrand,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF006194),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: brandsList.map((brand) {
              final isSelected = _selectedBrand == brand;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedBrand = brand;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF006194) : const Color(0xFFEAEDFF),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF006194).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6CF8BB),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(
                        brand,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF3F4850),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. CHOISIR LE FORMAT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Color(0xFF707881),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: _formats.map((fmt) {
            final isSelected = _selectedFormatKey == fmt.key;
            final price = (_products.isNotEmpty) ? _unitPriceForFormat(fmt) : fmt.defaultPrice;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFormatKey = fmt.key;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF006194) : const Color(0xFFEAEDFF),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF006194).withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          const BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    // Icon box
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF006194).withValues(alpha: 0.1)
                            : const Color(0xFFEAEDFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        fmt.icon,
                        color: const Color(0xFF006194),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                fmt.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? const Color(0xFF006194)
                                      : const Color(0xFF131B2E),
                                ),
                              ),
                              if (fmt.badge != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFDDB8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    fmt.badge!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF653E00),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fmt.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF707881),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Price & Radio Indicator
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: _fmt(price),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? const Color(0xFF006194)
                                      : const Color(0xFF131B2E),
                                ),
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: 'FCFA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? const Color(0xFF006194)
                                      : const Color(0xFF707881),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFF006194) : const Color(0xFFEAEDFF),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  int _unitPriceForFormat(GasFormatOption fmt) {
    if (_products.isEmpty) return fmt.defaultPrice;
    try {
      final match = _products.firstWhere(
        (p) =>
            p.brand.toLowerCase().trim() == _selectedBrand.toLowerCase().trim() &&
            p.size.toLowerCase().contains(fmt.key.toLowerCase()),
      );
      return match.priceFcfa > 0 ? match.priceFcfa : fmt.defaultPrice;
    } catch (_) {
      try {
        final match = _products.firstWhere(
          (p) => p.size.toLowerCase().contains(fmt.key.toLowerCase()),
        );
        return match.priceFcfa > 0 ? match.priceFcfa : fmt.defaultPrice;
      } catch (_) {
        return fmt.defaultPrice;
      }
    }
  }

  Widget _buildQuantityAndOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Quantity & Delivery Fee Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity Counter
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QUANTITÉ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF707881),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_qty > 1) setState(() => _qty--);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAEDFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.remove, size: 18, color: Color(0xFF131B2E)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$_qty',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF131B2E),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_qty < 10) setState(() => _qty++);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF006194),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Delivery Fee
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'FRAIS DE COURSE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF707881),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fmt(_deliveryFee)} FCFA',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bottle Exchange Toggle
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFCCE5FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync_alt, color: Color(0xFF004B73), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Échange de bouteille standard',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "J'ai une bouteille vide équivalente à remettre",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF707881),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasExchangeBottle,
                activeTrackColor: const Color(0xFF006194),
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  setState(() => _hasExchangeBottle = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPointCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF006194).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Color(0xFF006194), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POINT DE LIVRAISON',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF707881),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _deliveryLabel ?? 'Quartier Résidentiel, Adiaké',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF131B2E),
                  ),
                ),
                const Text(
                  'Près de la Pharmacie Centrale',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF707881),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _chooseLocation,
            icon: const Text(
              'Modifier',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF006194),
              ),
            ),
            label: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF006194)),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL ESTIMÉ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF707881),
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _fmt(_totalAmount),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF006194),
                            ),
                          ),
                          const TextSpan(text: ' '),
                          const TextSpan(
                            text: 'FCFA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF006194),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006194),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_bag_outlined, size: 20),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Commander',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
