import 'package:flutter/material.dart';
import 'header.dart';
import 'footer.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final void Function(int) onTabSelected;
  final VoidCallback onLogoTapRefresh;

  const AppShell({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onLogoTapRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderBar(onLogoTapRefresh: onLogoTapRefresh),
      body: child,
      bottomNavigationBar: FooterNav(
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
      ),
    );
  }
}
