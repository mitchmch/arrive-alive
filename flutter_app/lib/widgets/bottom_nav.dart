import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final String role;
  final bool isGuest;
  final Function(int) onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.role,
    required this.isGuest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[];

    if (!isGuest) {
      items.add(
        const _NavItem(icon: Icons.drive_eta, label: 'Drive', index: 0),
      );
    }
    items.add(
      _NavItem(
        icon: Icons.leaderboard,
        label: 'Speed Board',
        index: isGuest ? 0 : 1,
      ),
    );
    if (!isGuest) {
      items.add(const _NavItem(icon: Icons.report, label: 'Report', index: 2));
      items.add(
        const _NavItem(icon: Icons.history, label: 'History', index: 3),
      );
    }
    if (role == 'admin') {
      items.add(
        _NavItem(
          icon: Icons.admin_panel_settings,
          label: 'Admin',
          index: isGuest ? 1 : 4,
        ),
      );
    }

    return NavigationBar(
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      selectedIndex: _getSelectedIndex(),
      onDestinationSelected: (i) => onTap(items[i].index),
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }

  int _getSelectedIndex() {
    final items = <_NavItem>[];
    if (!isGuest) {
      items.add(
        const _NavItem(icon: Icons.drive_eta, label: 'Drive', index: 0),
      );
    }
    items.add(
      _NavItem(
        icon: Icons.leaderboard,
        label: 'Speed Board',
        index: isGuest ? 0 : 1,
      ),
    );
    if (!isGuest) {
      items.add(const _NavItem(icon: Icons.report, label: 'Report', index: 2));
      items.add(
        const _NavItem(icon: Icons.history, label: 'History', index: 3),
      );
    }
    if (role == 'admin') {
      items.add(
        _NavItem(
          icon: Icons.admin_panel_settings,
          label: 'Admin',
          index: isGuest ? 1 : 4,
        ),
      );
    }
    for (int i = 0; i < items.length; i++) {
      if (items[i].index == currentIndex) return i;
    }
    return 0;
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
