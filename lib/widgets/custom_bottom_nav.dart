import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChange;
  final int pendingMessagesCount;
  final int activeAppointmentsCount;

  const CustomBottomNav({
    super.key,
    required this.activeTab,
    required this.onTabChange,
    required this.pendingMessagesCount,
    required this.activeAppointmentsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              id: 'home',
              label: 'Inicio',
              icon: Icons.health_and_safety_outlined,
              activeIcon: Icons.health_and_safety,
            ),
            _buildNavItem(
              id: 'appointments',
              label: 'Citas',
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month,
              badgeCount: activeAppointmentsCount,
              badgeColor: Colors.teal,
            ),
            _buildNavItem(
              id: 'messages',
              label: 'Mensajes',
              icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded,
              badgeCount: pendingMessagesCount,
              badgeColor: const Color(0xFFF43F5E),
            ),
            _buildNavItem(
              id: 'profile',
              label: 'Mi Cuenta',
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String id,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
    Color badgeColor = Colors.teal,
  }) {
    final isActive = activeTab == id;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabChange(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.teal.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isActive ? activeIcon : icon,
                      color: isActive
                          ? Colors.teal.shade700
                          : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.teal.shade800
                      : const Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
