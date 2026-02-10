import 'package:flutter/material.dart';

class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLogoTapRefresh;

  const HeaderBar({super.key, required this.onLogoTapRefresh});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: GestureDetector(
        onTap: onLogoTapRefresh,
        child: const Text(
          "PropertyIQ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
