import 'package:flutter/material.dart';

import '../theme/adiake_colors.dart';

class ClientBottomNavBar extends StatelessWidget {
  const ClientBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isAdmin,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: FamanhColors.darkNavy.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: FamanhColors.primaryContainer.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(
          color: FamanhColors.surfaceContainerHighest.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              unselectedIcon: Icons.home_outlined,
              label: 'Accueil',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.local_shipping_rounded,
              unselectedIcon: Icons.local_shipping_outlined,
              label: 'Commandes',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.grid_view_rounded,
              unselectedIcon: Icons.grid_view_outlined,
              label: 'Service',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              unselectedIcon: Icons.person_outline,
              label: 'Compte',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
          if (isAdmin)
            Expanded(
              child: _NavItem(
                icon: Icons.admin_panel_settings_rounded,
                unselectedIcon: Icons.admin_panel_settings_outlined,
                label: 'Admin',
                selected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.unselectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData unselectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? FamanhColors.primaryContainer : const Color(0xFF64748B);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      splashColor: FamanhColors.primaryContainer.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? FamanhColors.primaryContainer.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: FamanhColors.primaryContainer.withValues(alpha: 0.20), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? icon : unselectedIcon,
                color: fg,
                size: 23,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: fg,
                letterSpacing: 0.8,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


