import 'package:flutter/material.dart';

class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLogoTapRefresh;
  final String currentPage;
  final ValueChanged<String>? onNavigate;

  const HeaderBar({
    super.key,
    required this.onLogoTapRefresh,
    this.currentPage = 'Home',
    this.onNavigate,
  });

  static const List<String> _pages = [
    'Home',
    'Calculate',
    'Compare',
    'Insights',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 86,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black12,
      titleSpacing: 20,
      title: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onLogoTapRefresh,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.home_work_rounded,
                          color: Color(0xFF2563EB),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'PropertyIQ',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 8,
                  children: _pages.map((page) {
                    final isActive = page == currentPage;
                    return _NavItem(
                      label: page,
                      active: isActive,
                      onTap: () {
                        if (page == 'Home') {
                          onLogoTapRefresh();
                          return;
                        }
                        if (onNavigate != null) {
                          onNavigate!(page);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const Expanded(
              flex: 2,
              child: SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(86);
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2563EB).withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? const Color(0xFF2563EB).withValues(alpha: 0.28)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF334155),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}