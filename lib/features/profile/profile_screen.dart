import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes.dart';
import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.embeddedInShell = false});

  /// Dans le tableau de bord livreur, masque l’en-tête plein écran (shell premium déjà présent).
  final bool embeddedInShell;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  static String _roleLabelFr(String? role) {
    switch (role ?? 'client') {
      case 'driver':
        return 'Livreur';
      case 'admin':
        return 'Administrateur';
      default:
        return 'Client';
    }
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() => _saving = true);
    try {
      final me = await ApiClient.uploadAvatar(file);
      ApiSession.currentUser.value = me;
      if (!mounted) return;
      AppToast.showSuccess(context, 'Photo mise à jour.');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final me = await ApiClient.updateMe(name: name);
      ApiSession.currentUser.value = me;
      if (!mounted) return;
      AppToast.showSuccess(context, 'Profil mis à jour.');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updatePreferredPosition() async {
    setState(() => _saving = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception("Les services de localisation sont désactivés.");

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) throw Exception("Permission de localisation refusée.");
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final me = await ApiClient.updateMe(
        preferredAddress: _addressCtrl.text.trim(),
        preferredLat: pos.latitude,
        preferredLng: pos.longitude,
      );
      ApiSession.currentUser.value = me;
      if (!mounted) return;
      AppToast.showSuccess(context, 'Position favorite enregistrée !');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Changer le mot de passe', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (v) => (v == null || v.length < 6) ? 'Min. 6 caractères' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                validator: (v) => (v != newCtrl.text) ? 'Les mots de passe ne correspondent pas' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.of(ctx).pop(true);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await ApiClient.changePassword(
        currentPassword: currentCtrl.text,
        newPassword: newCtrl.text,
      );
      if (!mounted) return;
      AppToast.showSuccess(context, 'Mot de passe mis à jour.');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: AdiakeColors.error, size: 22),
          SizedBox(width: 10),
          Text('Déconnexion', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AdiakeColors.error, foregroundColor: Colors.white),
            child: const Text('Se déconnecter', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    await ApiClient.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
  }

  InputDecoration _fieldDecoration(String hint, {IconData? icon}) {
    final fill = AdiakeColors.surfaceVariant.withValues(alpha: 0.55);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fill,
      prefixIcon: icon == null ? null : Icon(icon, color: AdiakeColors.primaryContainer.withValues(alpha: 0.75)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AdiakeColors.primaryContainer.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AdiakeColors.primaryContainer.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdiakeColors.primaryContainer, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserMeDto?>(
      valueListenable: ApiSession.currentUser,
      builder: (context, me, _) {
        final effectiveName = me?.name ?? '';
        if (_nameCtrl.text.isEmpty && effectiveName.isNotEmpty) {
          _nameCtrl.text = effectiveName;
        }

        final effectiveAddress = me?.preferredAddress ?? '';
        if (_addressCtrl.text.isEmpty && effectiveAddress.isNotEmpty) {
          _addressCtrl.text = effectiveAddress;
        }

        final borderSoft = AdiakeColors.primaryContainer.withValues(alpha: 0.10);
        final roleFr = _roleLabelFr(me?.role);

        final scrollBody = CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            if (!widget.embeddedInShell) ...[
              SliverToBoxAdapter(
                child: _PremiumTopBanner(
                  name: effectiveName.isEmpty ? 'Membre' : effectiveName,
                  phone: me?.phone ?? '—',
                  roleLabel: roleFr,
                  avatarUrl: me?.avatarUrl,
                  saving: _saving,
                  onPhoto: _pickAndUpload,
                ),
              ),
            ],
            if (widget.embeddedInShell)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profil',
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AdiakeColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Identité, sécurité du compte et préférences.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AdiakeColors.onSurfaceVariant,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, widget.embeddedInShell ? 18 : 20, 24, widget.embeddedInShell ? 120 : 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed(
                  [
                    if (widget.embeddedInShell || me?.role == 'driver') ...[
                      _DriverIdentityHeroCard(
                        me: me,
                        saving: _saving,
                        onPhoto: _pickAndUpload,
                      ),
                      const SizedBox(height: 16),
                      const _DriverFleetEquipmentCard(),
                      const SizedBox(height: 16),
                    ] else ...[
                      _HeroIdentityCard(
                        borderSoft: borderSoft,
                        name: effectiveName.isEmpty ? '—' : effectiveName,
                        phone: me?.phone ?? '—',
                        roleLabel: roleFr,
                        avatarUrl: me?.avatarUrl,
                        saving: _saving,
                        onPhoto: _pickAndUpload,
                      ),
                      const SizedBox(height: 16),
                    ],
                    GlassCard(
                      borderRadius: 20,
                      borderColor: borderSoft,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionTitle(title: 'Coordonnées', subtitle: 'Visible côté livreur / support'),
                          const SizedBox(height: 16),
                          Text(
                            'Nom complet',
                            style: GoogleFonts.workSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                              color: AdiakeColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AdiakeColors.onSurface),
                            decoration: _fieldDecoration('Votre nom affiché', icon: Icons.badge_outlined),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Téléphone',
                            style: GoogleFonts.workSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                              color: AdiakeColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InputDecorator(
                            decoration: _fieldDecoration('Numéro vérifié', icon: Icons.phone_iphone_rounded),
                            child: Text(
                              me?.phone ?? '—',
                              style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AdiakeColors.outline),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _saving ? null : _saveName,
                              style: FilledButton.styleFrom(
                                elevation: 0,
                                backgroundColor: AdiakeColors.primaryContainer,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                    )
                                  : Text('Enregistrer les modifications', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      borderRadius: 20,
                      borderColor: borderSoft,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionTitle(
                            title: 'Ma Position Favorite',
                            subtitle: 'Chargée automatiquement lors de vos commandes',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Adresse favorite (ex: Maison, Bureau)',
                            style: GoogleFonts.workSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                              color: AdiakeColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _addressCtrl,
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AdiakeColors.onSurface),
                            decoration: _fieldDecoration('Maison, Bureau...', icon: Icons.home_outlined),
                          ),
                          const SizedBox(height: 14),
                          if (me?.preferredLat != null && me?.preferredLng != null) ...[
                            Builder(
                              builder: (_) {
                                final lat = me!.preferredLat!;
                                final lng = me.preferredLng!;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Text(
                                    '📍 Position enregistrée : ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AdiakeColors.secondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _updatePreferredPosition,
                              icon: const Icon(Icons.my_location_rounded, size: 18),
                              label: Text(
                                me?.preferredLat == null ? 'Définir ma position actuelle' : 'Mettre à jour ma position',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AdiakeColors.secondaryContainer,
                                foregroundColor: AdiakeColors.secondary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                side: BorderSide(color: AdiakeColors.secondary.withValues(alpha: 0.2)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      borderRadius: 20,
                      borderColor: borderSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AdiakeColors.primaryFixed.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.verified_user_outlined, color: AdiakeColors.primaryContainer),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compte sécurisé',
                                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: AdiakeColors.primary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Gardez votre numérique à jour pour les notifications de mission.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AdiakeColors.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      borderRadius: 20,
                      borderColor: borderSoft,
                      padding: const EdgeInsets.all(8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AdiakeColors.primaryFixed.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.lock_outline_rounded, color: AdiakeColors.primaryContainer),
                        ),
                        title: Text(
                          'Changer le mot de passe',
                          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: AdiakeColors.primary),
                        ),
                        subtitle: Text(
                          'Mettez à jour votre mot de passe régulièrement.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdiakeColors.onSurfaceVariant),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AdiakeColors.outlineVariant),
                        onTap: _saving ? null : _changePassword,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.embeddedInShell || me?.role == 'driver') ...[
                      _DriverHelpAndSecuritySection(onLogout: _logout),
                    ] else ...[
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _logout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdiakeColors.onErrorContainer,
                            side: const BorderSide(color: AdiakeColors.error, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: AdiakeColors.errorContainer.withValues(alpha: 0.35),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text('Se déconnecter', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Famanh Super-App',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: FamanhColors.outline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );

        if (widget.embeddedInShell) {
          return ColoredBox(color: AdiakeColors.surface, child: scrollBody);
        }
        return Scaffold(
          backgroundColor: AdiakeColors.surface,
          body: scrollBody,
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AdiakeColors.primaryContainer,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AdiakeColors.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ],
    );
  }
}

class _PremiumTopBanner extends StatelessWidget {
  const _PremiumTopBanner({
    required this.name,
    required this.phone,
    required this.roleLabel,
    required this.avatarUrl,
    required this.saving,
    required this.onPhoto,
  });

  final String name;
  final String phone;
  final String roleLabel;
  final String? avatarUrl;
  final bool saving;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AdiakeColors.primaryContainer,
            AdiakeColors.primary,
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AdiakeColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(22, top + 12, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Espace personnel',
            style: GoogleFonts.workSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.manrope(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phone,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: Text(
                        roleLabel.toUpperCase(),
                        style: GoogleFonts.workSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AvatarRing(
                url: avatarUrl,
                saving: saving,
                onEdit: onPhoto,
                size: 92,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroIdentityCard extends StatelessWidget {
  const _HeroIdentityCard({
    required this.borderSoft,
    required this.name,
    required this.phone,
    required this.roleLabel,
    required this.avatarUrl,
    required this.saving,
    required this.onPhoto,
  });

  final Color borderSoft;
  final String name;
  final String phone;
  final String roleLabel;
  final String? avatarUrl;
  final bool saving;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 22,
      borderColor: borderSoft,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          _AvatarRing(url: avatarUrl, saving: saving, onEdit: onPhoto, size: 96),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AdiakeColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            phone,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AdiakeColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AdiakeColors.secondaryContainer.withValues(alpha: 0.65),
                  AdiakeColors.secondaryContainer.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AdiakeColors.secondary.withValues(alpha: 0.35)),
            ),
            child: Text(
              roleLabel,
              style: GoogleFonts.workSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AdiakeColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({
    required this.url,
    required this.saving,
    required this.onEdit,
    required this.size,
  });

  final String? url;
  final bool saving;
  final VoidCallback onEdit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ring = 3.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size + ring * 2,
          height: size + ring * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AdiakeColors.secondaryContainer, AdiakeColors.primaryFixed],
            ),
            boxShadow: [
              BoxShadow(
                color: AdiakeColors.primary.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(ring),
            child: Material(
              color: AdiakeColors.surfaceContainerLowest,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: url == null || url!.isEmpty
                  ? Icon(Icons.person_rounded, size: size * 0.45, color: AdiakeColors.primaryContainer)
                  : Image.network(
                      url!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person_rounded,
                        size: size * 0.45,
                        color: AdiakeColors.primaryContainer,
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Material(
            color: AdiakeColors.primaryContainer,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: AdiakeColors.primary.withValues(alpha: 0.35),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: saving ? null : onEdit,
              child: SizedBox(
                width: 36,
                height: 36,
                child: saving
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverIdentityHeroCard extends StatelessWidget {
  const _DriverIdentityHeroCard({
    required this.me,
    required this.saving,
    required this.onPhoto,
  });

  final UserMeDto? me;
  final bool saving;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final driverName = (me?.name != null && me!.name!.isNotEmpty) ? me!.name! : 'Konan Yao Fabrice';
    final driverId = me?.id != null ? '#FLT-${me!.id}' : '#FLT-4892';
    final avatarUrl = me?.avatarUrl;
    final region = (me?.preferredAddress != null && me!.preferredAddress!.isNotEmpty)
        ? me!.preferredAddress!
        : 'Région Adiaké & Assinie';

    return Container(
      decoration: BoxDecoration(
        color: FamanhColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Container with Verified Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: saving ? null : onPhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: FamanhColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 44, color: FamanhColors.primary)
                          : Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 44, color: FamanhColors.primary),
                            ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: FamanhColors.secondary,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Identity Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: FamanhColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ID: $driverId',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: FamanhColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: FamanhColors.tertiaryFixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.military_tech_rounded, size: 12, color: FamanhColors.tertiary),
                              const SizedBox(width: 3),
                              Text(
                                'Élite Famanh',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: FamanhColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      driverName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: FamanhColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Rating & Reviews
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 18, color: FamanhColors.tertiary),
                        const SizedBox(width: 4),
                        Text(
                          '4.9',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: FamanhColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(142 avis vérifiés)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: FamanhColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Zone
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: FamanhColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            region,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: FamanhColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Career Metrics Ticker
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: FamanhColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '6 mois',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FamanhColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ANCIENNETÉ',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: FamanhColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 24, width: 1, color: FamanhColors.outlineVariant.withValues(alpha: 0.5)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '384',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FamanhColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LIVRAISONS',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: FamanhColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 24, width: 1, color: FamanhColors.outlineVariant.withValues(alpha: 0.5)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '99.2%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FamanhColors.tertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'FIABILITÉ',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: FamanhColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverFleetEquipmentCard extends StatelessWidget {
  const _DriverFleetEquipmentCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FLOTTE & ÉQUIPEMENT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: FamanhColors.primary,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: FamanhColors.secondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Actif en service',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FamanhColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: FamanhColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FamanhColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: FamanhColors.primaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, color: FamanhColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moto Boxer 125cc',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: FamanhColors.onSurface,
                          ),
                        ),
                        Text(
                          'MATRICULE : 4892-JJ-01',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: FamanhColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FamanhColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CI-SUD',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: FamanhColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverHelpAndSecuritySection extends StatelessWidget {
  const _DriverHelpAndSecuritySection({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: FamanhColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Centre d\'aide & Sécurité — Hotline disponible 24/7.')),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FamanhColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: FamanhColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centre d\'aide & Sécurité',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: FamanhColors.onSurface,
                          ),
                        ),
                        Text(
                          'Protocoles de transport & secours',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: FamanhColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: FamanhColors.onSurfaceVariant, size: 22),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: onLogout,
            style: FilledButton.styleFrom(
              backgroundColor: FamanhColors.errorContainer,
              foregroundColor: FamanhColors.onErrorContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: Text(
              'Se déconnecter de la session',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'FAMANH LIVREUR CI • BUILD V4.12.8-PROD',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: FamanhColors.outline,
            ),
          ),
        ),
      ],
    );
  }
}

