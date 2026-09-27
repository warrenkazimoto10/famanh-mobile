import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final Animation<double> _progress;

  bool _navigated = false;

  Future<void> _goNext() async {
    if (!mounted || _navigated) return;

    // Hot restart reset l'état en mémoire, mais le token est persisté.
    // On réhydrate la session et on redirige vers le bon dashboard.
    if (ApiSession.token != null && ApiSession.token!.isNotEmpty) {
      if (ApiSession.currentUser.value == null) {
        try {
          await ApiSession.refreshMe();
        } catch (_) {
          // ignore: offline/serveur down → on laisse l'app continuer
        }
      }
      if (!mounted || _navigated) return;

      final me = ApiSession.currentUser.value;
      if (me != null && me.role == 'driver') {
        _navigated = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.driverDashboard);
        return;
      }
      if (me != null) {
        _navigated = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        return;
      }
      // Token présent mais /me impossible → on évite l'onboarding et on montre login.
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _scaleIn = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack)),
    );
    _progress = CurvedAnimation(parent: _controller, curve: const Interval(0.25, 1.0, curve: Curves.easeOut));

    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      _goNext();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Halos discrets aux couleurs de la marque.
          Positioned(
            top: -130,
            left: -110,
            child: _Halo(color: AdiakeColors.primaryContainer.withValues(alpha: 0.12), size: 300),
          ),
          Positioned(
            bottom: -150,
            right: -120,
            child: _Halo(color: AdiakeColors.secondaryContainer.withValues(alpha: 0.45), size: 320),
          ),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Opacity(
                    opacity: _fadeIn.value,
                    child: Transform.scale(
                      scale: _scaleIn.value,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const BrandLogo(size: 148),
                          const SizedBox(height: 32),
                          Text(
                            'Famanh',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: FamanhColors.primaryContainer,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: FamanhColors.primaryContainer.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: FamanhColors.primaryContainer.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              'Un clic, vos services, chez vous.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: FamanhColors.primaryContainer,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 4,
                            color: AdiakeColors.surfaceVariant,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _progress.value.clamp(0.08, 1.0),
                                child: Container(color: AdiakeColors.primaryContainer),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'INITIALISATION',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AdiakeColors.outline,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 120)],
      ),
    );
  }
}
