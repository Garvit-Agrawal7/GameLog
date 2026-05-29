import 'package:flutter/material.dart';

import 'screens/add_game_modal.dart';
import 'screens/discover_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'theme/app_colors.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    LibraryScreen(),
    DiscoverScreen(),
  ];

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onNavTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.accentPurple : AppColors.textMuted,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.accentPurple : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddGameModal(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(),
        child: Ink(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: AppColors.accentGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.bg1,
        elevation: 0,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              _navItem(index: 0, icon: Icons.home_rounded, label: 'Home'),
              _navItem(index: 1, icon: Icons.sports_esports_rounded, label: 'My Games'),
              _navItem(index: 2, icon: Icons.explore_outlined, label: 'Explore'),
            ],
          ),
        ),
      ),
    );
  }
}
