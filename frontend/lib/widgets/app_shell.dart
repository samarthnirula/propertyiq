import 'package:flutter/material.dart';
import '../theme.dart';
import '../app.dart'; // To access the global themeNotifier

class AppShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onLogoTapRefresh;
  final Widget body;

  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onLogoTapRefresh,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: onLogoTapRefresh,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.real_estate_agent_rounded, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                "PropertyIQ",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // The Theme Selector Dropdown
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<AppTheme>(
              tooltip: "Change Theme",
              icon: Icon(Icons.palette_outlined, color: theme.primaryColor),
              onSelected: (AppTheme newTheme) {
                // This updates the global notifier, triggering a full app rebuild
                themeNotifier.value = newTheme; 
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<AppTheme>>[
                _buildThemeItem(AppTheme.classicLight, "Classic Light", Icons.light_mode),
                _buildThemeItem(AppTheme.softLight, "Soft Light", Icons.wb_sunny_outlined),
                _buildThemeItem(AppTheme.darkBlue, "Dark Blue", Icons.nights_stay),
                _buildThemeItem(AppTheme.midnightDark, "Midnight Dark", Icons.dark_mode),
              ],
            ),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTabSelected,
        backgroundColor: theme.cardTheme.color,
        indicatorColor: theme.primaryColor.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows_outlined),
            selectedIcon: Icon(Icons.compare_arrows),
            label: 'Compare',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
      ),
    );
  }

  PopupMenuItem<AppTheme> _buildThemeItem(AppTheme value, String label, IconData icon) {
    return PopupMenuItem<AppTheme>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}