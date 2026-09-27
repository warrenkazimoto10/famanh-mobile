import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';
import '../../../widgets/skeleton_loader.dart';

const _kShadow = [
  BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x05000000), blurRadius: 20, offset: Offset(0, 6)),
];

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this)..addListener(_onTab);

  bool _loading = true;
  String? _error;
  List<AdminUserDto> _users = const [];
  int _total = 0;
  int _page = 1;
  int _lastPage = 1;
  bool _loadingMore = false;
  String _search = '';

  static const _roles = ['client', 'driver', 'admin'];
  static const _tabLabels = ['Clients', 'Livreurs', 'Admins'];

  String get _role => _roles[_tab.index];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _tab.removeListener(_onTab);
    _tab.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tab.indexIsChanging) return;
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) setState(() { _loading = true; _error = null; _users = []; _page = 1; });
    try {
      final result = await AdminApi.adminUsers(role: _role, page: _page);
      if (!mounted) return;
      setState(() {
        _users = reset ? result.items : [..._users, ...result.items];
        _total = result.total;
        _lastPage = result.lastPage;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() { _loadingMore = true; _page++; });
    await _load();
  }

  List<AdminUserDto> get _filtered {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) => u.name.toLowerCase().contains(q) || u.phone.contains(q)).toList();
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(onDone: () => _load(reset: true)),
    );
  }

  void _openEdit(AdminUserDto user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(user: user, onDone: () => _load(reset: true)),
    );
  }

  void _openDetail(AdminUserDto user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(
        user: user,
        onEdit: () { Navigator.of(context).pop(); _openEdit(user); },
        onDelete: () { Navigator.of(context).pop(); _confirmDelete(user); },
      ),
    );
  }

  Future<void> _confirmDelete(AdminUserDto user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer cet utilisateur ?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text('Cette action est irréversible. "${user.name}" sera définitivement supprimé.'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w700))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AdiakeColors.error),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await AdminApi.adminDeleteUser(user.id);
      if (mounted) {
        _load(reset: true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Utilisateur supprimé.'),
          backgroundColor: Color(0xFF2E7D32),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AdiakeColors.primaryContainer,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(
        children: [
          _TopBar(
            total: _total,
            search: _search,
            onSearch: (v) => setState(() => _search = v),
            onAdd: _openCreate,
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AdiakeColors.primaryContainer,
              unselectedLabelColor: AdiakeColors.outline,
              indicatorColor: AdiakeColors.primaryContainer,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : _error != null
                    ? _buildError()
                    : isWide ? _buildWide() : _buildNarrow(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nouvel utilisateur', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AdiakeColors.primaryContainer,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const SkeletonLoader(width: double.infinity, height: 72, borderRadius: 14),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AdiakeColors.outline),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AdiakeColors.error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
        ],
      ),
    );
  }

  Widget _buildWide() {
    final filtered = _filtered;
    if (filtered.isEmpty) return _emptyState();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _kShadow),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(
                color: const Color(0xFFF8F8F8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Row(
                  children: [
                    SizedBox(width: 52),
                    Expanded(flex: 3, child: Text('Nom', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                    Expanded(flex: 2, child: Text('Téléphone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                    Expanded(flex: 2, child: Text('Rôle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                    Expanded(flex: 2, child: Text('Inscrit le', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                    SizedBox(width: 64, child: Text('Action', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF2F2F2)),
                  itemBuilder: (_, i) {
                    if (i == filtered.length) {
                      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
                    }
                    return _WideUserRow(user: filtered[i], onTap: () => _openDetail(filtered[i]), onEdit: () => _openEdit(filtered[i]));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNarrow() {
    final filtered = _filtered;
    if (filtered.isEmpty) return _emptyState();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: filtered.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == filtered.length) {
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
          }
          return _UserCard(user: filtered[i], onTap: () => _openDetail(filtered[i]), onEdit: () => _openEdit(filtered[i]));
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.people_outline, size: 56, color: AdiakeColors.outline),
        const SizedBox(height: 12),
        Text('Aucun ${_roleLabel(_role).toLowerCase()}', style: const TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.total, required this.search, required this.onSearch, required this.onAdd});
  final int total;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Text('Utilisateurs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AdiakeColors.primary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(999)),
            child: Text('$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdiakeColors.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher…',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wide table row ────────────────────────────────────────────────────────────

class _WideUserRow extends StatelessWidget {
  const _WideUserRow({required this.user, required this.onTap, required this.onEdit});
  final AdminUserDto user;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(user.createdAt);
    final color = _roleColor(user.role);

    return InkWell(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ),
          ),
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdiakeColors.primary), overflow: TextOverflow.ellipsis),
              if (user.email != null)
                Text(user.email!, style: const TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
            ],
          )),
          Expanded(flex: 2, child: Text(user.phone, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
          Expanded(flex: 2, child: _RoleBadge(role: user.role)),
          Expanded(flex: 2, child: Text(date, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
          SizedBox(
            width: 64,
            child: IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              color: AdiakeColors.outline,
              tooltip: 'Modifier le rôle',
              onPressed: onEdit,
            ),
          ),
        ],
      ),
    ));
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap, required this.onEdit});
  final AdminUserDto user;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(user.createdAt);
    final color = _roleColor(user.role);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _kShadow),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AdiakeColors.primary)),
                const SizedBox(height: 2),
                Text(user.phone, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _RoleBadge(role: user.role),
                    const SizedBox(width: 8),
                    Text(date, style: const TextStyle(fontSize: 11, color: AdiakeColors.outline)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AdiakeColors.outline,
            onPressed: onEdit,
          ),
        ],
      ),
    ));
  }
}

// ── User detail bottom sheet ──────────────────────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  const _UserDetailSheet({required this.user, required this.onEdit, required this.onDelete});
  final AdminUserDto user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(user.role);
    final joinDate = DateFormat('dd/MM/yyyy').format(user.createdAt);

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(0, 12, 0, MediaQuery.paddingOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 20),
          // Avatar header
          CircleAvatar(
            radius: 36,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 28)),
          ),
          const SizedBox(height: 12),
          Text(user.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AdiakeColors.primary)),
          const SizedBox(height: 4),
          _RoleBadge(role: user.role),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF2F2F2)),
          const SizedBox(height: 8),
          // Details
          _DetailRow(icon: Icons.phone_rounded, label: 'Téléphone', value: user.phone),
          if (user.email != null && user.email!.isNotEmpty)
            _DetailRow(icon: Icons.email_outlined, label: 'Email', value: user.email!),
          _DetailRow(icon: Icons.calendar_today_rounded, label: 'Inscrit le', value: joinDate),
          _DetailRow(icon: Icons.badge_outlined, label: 'ID', value: '#${user.id}'),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF2F2F2)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Modifier le rôle', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdiakeColors.error,
                      side: const BorderSide(color: AdiakeColors.error),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, size: 20),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFF4F5F7), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AdiakeColors.primaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
            const SizedBox(height: 1),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdiakeColors.primary)),
          ],
        )),
      ]),
    );
  }
}

// ── User form bottom sheet ────────────────────────────────────────────────────

class _UserFormSheet extends StatefulWidget {
  const _UserFormSheet({this.user, required this.onDone});
  final AdminUserDto? user;
  final VoidCallback onDone;

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _phone = TextEditingController(text: widget.user?.phone ?? '');
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'client';
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (widget.user == null) {
        await AdminApiExtra.adminCreateUser(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
          role: _role,
        );
      } else {
        await AdminApi.adminUpdateUserRole(widget.user!.id, _role);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.user == null ? 'Utilisateur créé avec succès.' : 'Rôle mis à jour.'),
          backgroundColor: const Color(0xFF2E7D32),
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44, height: 5,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AdiakeColors.primaryContainer.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                      color: AdiakeColors.primaryContainer, size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AdiakeColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!isEdit) ...[
                _InputField(controller: _name, label: 'Nom complet', hint: 'Jean Dupont', validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
                const SizedBox(height: 12),
                _InputField(controller: _phone, label: 'Téléphone', hint: '+225 07 00 00 00', keyboardType: TextInputType.phone, validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  validator: (v) => v!.length < 6 ? 'Au moins 6 caractères' : null,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Rôle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdiakeColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final r in [('client', 'Client'), ('driver', 'Livreur'), ('admin', 'Admin')])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _role = r.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _role == r.$1 ? _roleColor(r.$1).withValues(alpha: 0.10) : const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _role == r.$1 ? _roleColor(r.$1) : const Color(0xFFE0E0E0), width: _role == r.$1 ? 1.5 : 1),
                            ),
                            child: Center(
                              child: Text(r.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _role == r.$1 ? _roleColor(r.$1) : AdiakeColors.onSurfaceVariant)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: AdiakeColors.error, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEdit ? 'Mettre à jour le rôle' : 'Créer l\'utilisateur',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({required this.controller, required this.label, required this.hint, this.keyboardType, this.validator});
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _roleColor(String role) => switch (role) {
  'driver' => const Color(0xFF1565C0),
  'admin'  => AdiakeColors.primaryContainer,
  _        => const Color(0xFF2E7D32),
};

String _roleLabel(String role) => switch (role) {
  'driver' => 'Livreur',
  'admin'  => 'Admin',
  _        => 'Client',
};

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
      child: Text(_roleLabel(role), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
