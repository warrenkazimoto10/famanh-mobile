import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';
import '../../../widgets/skeleton_loader.dart';

class AdminResetsScreen extends StatefulWidget {
  const AdminResetsScreen({super.key});

  @override
  State<AdminResetsScreen> createState() => _AdminResetsScreenState();
}

class _AdminResetsScreenState extends State<AdminResetsScreen> {
  bool _loading = true;
  String? _error;
  List<AdminResetDto> _resets = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminApi.adminPasswordResets();
      if (mounted) setState(() { _resets = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _resolve(AdminResetDto reset) async {
    final ctrl = TextEditingController();
    bool obscure = true;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Nouveau mot de passe\n${reset.userName ?? reset.phone ?? ''}'),
          content: TextField(
            controller: ctrl,
            obscureText: obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setLocal(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final p = ctrl.text.trim();
                if (p.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Minimum 6 caractères.')));
                  return;
                }
                Navigator.of(ctx).pop(p);
              },
              child: const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );

    if (password == null) return;
    try {
      await AdminApi.adminResolveReset(reset.id, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mot de passe réinitialisé pour ${reset.userName ?? reset.phone}')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _dismiss(AdminResetDto reset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rejeter la demande ?'),
        content: Text('La demande de ${reset.userName ?? reset.phone} sera rejetée sans action.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdiakeColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await AdminApi.adminDismissReset(reset.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande rejetée.')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdiakeColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Demandes de mot de passe',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AdiakeColors.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AdiakeColors.primaryContainer),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AdiakeColors.primaryContainer,
        child: _loading
            ? _buildSkeleton()
            : _error != null
                ? _buildError()
                : _buildList(),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const SkeletonLoader(width: double.infinity, height: 90, borderRadius: 14),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AdiakeColors.outline),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AdiakeColors.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_resets.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF2E7D32)),
                SizedBox(height: 16),
                Text(
                  'Aucune demande en attente',
                  style: TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _resets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ResetTile(
        reset: _resets[i],
        onResolve: () => _resolve(_resets[i]),
        onDismiss: () => _dismiss(_resets[i]),
      ),
    );
  }
}

class _ResetTile extends StatelessWidget {
  const _ResetTile({required this.reset, required this.onResolve, required this.onDismiss});
  final AdminResetDto reset;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy · HH:mm').format(reset.createdAt);
    final name = reset.userName ?? '—';
    final phone = reset.userPhone ?? reset.phone ?? '—';
    final initials = name.isNotEmpty && name != '—' ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: const Color(0xFFFFEBEE)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AdiakeColors.primaryContainer.withValues(alpha: 0.10),
            child: Text(initials, style: const TextStyle(color: AdiakeColors.primaryContainer, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: AdiakeColors.primary)),
                const SizedBox(height: 2),
                Text(phone, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdiakeColors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdiakeColors.outline, fontSize: 11)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDismiss,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdiakeColors.error,
                          side: const BorderSide(color: AdiakeColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Rejeter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onResolve,
                        style: FilledButton.styleFrom(
                          backgroundColor: AdiakeColors.primaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Réinitialiser', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
