import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../services/background_tracking_service.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_toast.dart';
import 'driver_jobs_screen.dart';
import 'driver_notification_history_screen.dart';
import 'driver_revenues_screen.dart';
import '../profile/profile_screen.dart';

/// Shell livreur aligné sur la maquette premium (header fixe, bottom nav, FAB).
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final GlobalKey<DriverJobsScreenState> _jobsKey = GlobalKey<DriverJobsScreenState>();

  int _tab = 0;

  static const String _placeholderAvatar =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB1VYekAqeROzJ_OQg4uIoO1cvi5TSLk2WXpWSa1GjWDG3DGPigQ0IHO7r7d9saV0-oTakxK6oTLcpBgauw1ZWWyTjZ94pde8SwJHDOkd0GAQ1lc7kIjIUlHo2WpIOZPTBnXJ69uqKRlfLp1toLuxui9aWhBTKUE3Pcq6HqRZECUi0MieZ1SE1n-8CFIz-skRIvrXqY6TYSwkzu8QnnqmfUXC-k3Vc2cXZ7QuOHewKHy1Zlcl3WsNtdRQkWoiGIUneYdrfWQQpyLSw';

  double _headerBottom(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 132;
  }

  double _navHeight(BuildContext context) {
    return 76 + MediaQuery.paddingOf(context).bottom;
  }

  void _onNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DriverNotificationHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerH = _headerBottom(context);
    final navH = _navHeight(context);

    return Scaffold(
      backgroundColor: AdiakeColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: headerH, bottom: navH),
              child: IndexedStack(
                index: _tab,
                children: [
                  DriverJobsScreen(
                    key: _jobsKey,
                  ),
                  const DriverRevenuesScreen(),
                  const ProfileScreen(embeddedInShell: true),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PremiumDriverHeader(
              onNotifications: _onNotifications,
              placeholderAvatarUrl: _placeholderAvatar,
            ),
          ),
          Positioned(
            right: 24,
            bottom: navH + 20,
            child: Material(
              elevation: 10,
              shadowColor: AdiakeColors.primary.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              color: AdiakeColors.primaryContainer,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Messagerie — bientôt disponible.')),
                  );
                },
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PremiumBottomNav(
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              bottomInset: MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumDriverHeader extends StatefulWidget {
  const _PremiumDriverHeader({
    required this.onNotifications,
    required this.placeholderAvatarUrl,
  });

  final VoidCallback onNotifications;
  final String placeholderAvatarUrl;

  @override
  State<_PremiumDriverHeader> createState() => _PremiumDriverHeaderState();
}

class _PremiumDriverHeaderState extends State<_PremiumDriverHeader> {
  bool _uploading = false;
  bool _isOnline = true;

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bonjour,';
    if (hour >= 12 && hour < 18) return 'Bon après-midi,';
    return 'Bonsoir,';
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final me = await ApiClient.uploadAvatar(file);
      ApiSession.currentUser.value = me;
      if (mounted) AppToast.showSuccess(context, 'Photo de profil mise à jour.');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toggleOnline() async {
    setState(() => _isOnline = !_isOnline);
    try {
      if (_isOnline) {
        await BackgroundTrackingService.start();
        await ApiClient.updateDriverStatus(true);
        if (mounted) AppToast.showSuccess(context, 'Service actif • Réception prioritaire');
      } else {
        await BackgroundTrackingService.stop();
        await ApiClient.updateDriverStatus(false);
        if (mounted) AppToast.showSuccess(context, 'Service mis en pause');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF006194), Color(0xFF007BB9), Color(0xFFDAE2FD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F006194),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 16),
      child: ValueListenableBuilder<UserMeDto?>(
        valueListenable: ApiSession.currentUser,
        builder: (context, me, _) {
          final fullName = (me?.name?.trim().isNotEmpty ?? false) ? me!.name!.trim() : 'Livreur Famanh';

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _uploading ? null : _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.25),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _uploading
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                )
                              : (me?.avatarUrl != null && me!.avatarUrl!.isNotEmpty)
                                  ? Image.network(me.avatarUrl!, fit: BoxFit.cover)
                                  : Image.network(widget.placeholderAvatarUrl, fit: BoxFit.cover),
                        ),
                        if (!_uploading)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 9, color: Color(0xFF006194)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreetingText(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onNotifications,
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_isOnline ? const Color(0xFF006C49) : Colors.orange).withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOnline ? const Color(0xFF006C49) : Colors.orange,
                        boxShadow: [
                          BoxShadow(
                            color: (_isOnline ? const Color(0xFF006C49) : Colors.orange).withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim), child: child)),
                        child: Column(
                          key: ValueKey<bool>(_isOnline),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'En ligne • Prêt à livrer' : 'Hors-ligne • En pause',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                            Text(
                              _isOnline ? 'Réception prioritaire active' : 'Reprenez pour recevoir des missions',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _isOnline ? const Color(0xFF006C49) : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleOnline,
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isOnline ? Colors.grey.shade200 : const Color(0xFF006194),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              if (!_isOnline)
                                BoxShadow(
                                  color: const Color(0xFF006194).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: Row(
                              key: ValueKey<bool>(_isOnline),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isOnline ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                                  size: 16,
                                  color: _isOnline ? Colors.black87 : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isOnline ? 'Pause' : 'Reprendre',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _isOnline ? Colors.black87 : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PremiumBottomNav extends StatelessWidget {
  const _PremiumBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.bottomInset,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AdiakeColors.primaryContainer.withValues(alpha: 0.10))),
        boxShadow: [
          BoxShadow(
            color: AdiakeColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomInset),
        child: Row(
          children: [
            Expanded(child: _NavItem(i: 0, icon: Icons.local_shipping_rounded, label: 'Missions', selected: currentIndex == 0, onTap: () => onTap(0))),
            Expanded(child: _NavItem(i: 1, icon: Icons.payments_outlined, label: 'Revenus', selected: currentIndex == 1, onTap: () => onTap(1))),
            Expanded(child: _NavItem(i: 2, icon: Icons.person_outline_rounded, label: 'Profil', selected: currentIndex == 2, onTap: () => onTap(2))),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.i,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int i;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AdiakeColors.primaryContainer : const Color(0xFF94A3B8);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _gold : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
