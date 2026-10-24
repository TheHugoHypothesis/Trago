import 'package:flutter/material.dart';
import '../theme/trago_theme.dart';
import 'draft_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String? _originFilter;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _searchByOrigin(String origin) {
    setState(() {
      _originFilter = origin;
      _currentIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onNavigateTab: _navigateToTab,
        onSearchOrigin: _searchByOrigin,
      ),
      OrdersScreen(onNavigateTab: _navigateToTab),
      DraftScreen(onNavigateTab: _navigateToTab),
      SearchScreen(
        onNavigateTab: _navigateToTab,
        initialOriginFilter: _originFilter,
      ),
      ProfileScreen(onNavigateTab: _navigateToTab),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: _TragoBottomBar(
        currentIndex: _currentIndex,
        onTap: _navigateToTab,
      ),
    );
  }
}

class _TragoBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _TragoBottomBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TragoColors.paper,
        border: const Border(
          top: BorderSide(color: TragoColors.borderGray, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: TragoColors.navy.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              Expanded(
                child: _NavBarItem(
                  icon: Icons.home_rounded,
                  label: 'Início',
                  selected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _NavBarItem(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Pedidos',
                  selected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),

              // Botão Central Coral "+" idêntico ao Design.png
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: TragoColors.coral,
                      shape: BoxShape.circle,
                      boxShadow: TragoColors.coralGlow,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _NavBarItem(
                  icon: Icons.airplanemode_active_rounded,
                  label: 'Viagens',
                  selected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ),
              Expanded(
                child: _NavBarItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Perfil',
                  selected: currentIndex == 4,
                  onTap: () => onTap(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? TragoColors.coral : TragoColors.slate;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
