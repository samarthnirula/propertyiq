import 'package:flutter/material.dart';
import 'header.dart';

class AppShell extends StatelessWidget {
  final Widget body;
  final int selectedIndex;
  final void Function(int) onTabSelected;
  final VoidCallback onLogoTapRefresh;

  const AppShell({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onLogoTapRefresh,
  });

  static const List<String> _pages = [
    'Home',
    'Calculate',
    'Compare',
    'Insights',
    'Profile',
  ];

  String _pageNameFromIndex(int index) {
    if (index < 0 || index >= _pages.length) return 'Home';
    return _pages[index];
  }

  int _indexFromPageName(String page) {
    switch (page) {
      case 'Home':
        return 0;
      case 'Calculate':
        return 1;
      case 'Compare':
        return 2;
      case 'Insights':
        return 3;
      case 'Profile':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderBar(
        onLogoTapRefresh: () {
          onTabSelected(0);
          onLogoTapRefresh();
        },
        currentPage: _pageNameFromIndex(selectedIndex),
        onNavigate: (page) {
          final index = _indexFromPageName(page);
          onTabSelected(index);
        },
      ),
      body: body,
    );
  }
}