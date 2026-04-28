import 'package:flutter/material.dart';

class FooterNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabSelected;

  const FooterNav({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}