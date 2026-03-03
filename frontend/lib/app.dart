import 'package:flutter/material.dart';
import 'theme.dart';

import 'pages/homepage.dart';
import 'pages/calculator_page.dart';
import 'pages/compare.dart';
import 'pages/profile.dart';

import 'widgets/app_shell.dart';

// Global notifier for the app theme
final ValueNotifier<AppTheme> themeNotifier = ValueNotifier(AppTheme.classicLight);

class PropertyIQApp extends StatelessWidget {
  const PropertyIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: getAppTheme(currentTheme), // Now dynamic!
          home: const RootNavigator(),
        );
      },
    );
  }
}

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  int selectedIndex = 0;

  final pages = const [
    HomePage(),
    CalculatorPage(),
    ComparePage(),
    ProfilePage(),
  ];

  void onTabSelected(int index) {
    setState(() => selectedIndex = index);
  }

  // Refresh current page: simplest approach is to rebuild the current page
  // by changing a key. This forces the widget tree to remount.
  Key refreshKey = UniqueKey();
  void refreshCurrentPage() {
    setState(() {
      refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: selectedIndex,
      onTabSelected: onTabSelected,
      onLogoTapRefresh: refreshCurrentPage,
      child: KeyedSubtree(
        key: refreshKey,
        child: pages[selectedIndex],
      ),
    );
  }
}
