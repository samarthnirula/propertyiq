// app.dart
import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/homepage.dart';
import 'pages/calculator_page.dart';
import 'pages/compare.dart';
import 'pages/insights_page.dart';
import 'pages/profile.dart';
import 'widgets/app_shell.dart';

final ValueNotifier<AppTheme> themeNotifier = ValueNotifier(
  AppTheme.classicLight,
);

class PropertyIQApp extends StatelessWidget {
  const PropertyIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: getAppTheme(currentTheme),
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
  Key refreshKey = UniqueKey();

  final List<Widget> pages = const [
    HomePage(),
    CalculatorPage(),
    ComparePage(),
    InsightsPage(),
    ProfilePage(),
  ];

  void onTabSelected(int index) {
    setState(() {
      selectedIndex = index;
      refreshKey = UniqueKey();
    });
  }

  void refreshCurrentPage() {
    setState(() {
      selectedIndex = 0;
      refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: selectedIndex,
      onTabSelected: onTabSelected,
      onLogoTapRefresh: refreshCurrentPage,
      body: KeyedSubtree(
        key: refreshKey,
        child: pages[selectedIndex],
      ),
    );
  }
}