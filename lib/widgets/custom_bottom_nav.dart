import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// Barra de navegación inferior.
///
/// Cuatro destinos, que es el número correcto: uno por cada cosa que se puede
/// querer hacer al abrir la app. Los cambios respecto de la anterior:
///
/// - **«Citas» pasa a «Atenciones».** La pestaña no muestra solo citas
///   agendadas: muestra el seguimiento en vivo, el pago pendiente y el
///   historial. «Citas» describía un tercio de su contenido.
/// - **«Mi Cuenta» pasa a «Perfil».** Más corto, y no se corta al agrandar la
///   letra.
/// - **El estado activo ya no depende del color.** Antes un elemento activo era
///   el mismo dibujo en verde; ahora cambia el icono (contorno → relleno), el
///   peso del texto y aparece una pastilla de fondo. Quien no separa el verde
///   del gris ve igualmente en qué pestaña está.
/// - **El objetivo táctil es toda la columna, 56 px de alto.** Antes el
///   `GestureDetector` envolvía una `Column` que medía lo que midiera su
///   contenido.
/// - **Los contadores se anuncian.** «Mensajes, 3 sin leer», no un círculo rojo
///   que para un lector de pantalla no existe.
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
    final p = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: AuraShadow.lifted(context.isDark),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.xs,
            vertical: AuraSpace.xxs,
          ),
          child: Row(
            children: [
              _NavItem(
                id: 'home',
                label: 'Inicio',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                activeTab: activeTab,
                onTabChange: onTabChange,
              ),
              _NavItem(
                id: 'appointments',
                label: 'Atenciones',
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month_rounded,
                activeTab: activeTab,
                onTabChange: onTabChange,
                badgeCount: activeAppointmentsCount,
                badgeNoun: 'en curso',
                badgeTone: AuraTone.success,
              ),
              _NavItem(
                id: 'messages',
                label: 'Mensajes',
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                activeTab: activeTab,
                onTabChange: onTabChange,
                badgeCount: pendingMessagesCount,
                badgeNoun: 'sin leer',
                badgeTone: AuraTone.error,
              ),
              _NavItem(
                id: 'profile',
                label: 'Perfil',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                activeTab: activeTab,
                onTabChange: onTabChange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String activeTab;
  final ValueChanged<String> onTabChange;
  final int badgeCount;
  final String badgeNoun;
  final AuraTone badgeTone;

  const _NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.activeTab,
    required this.onTabChange,
    this.badgeCount = 0,
    this.badgeNoun = '',
    this.badgeTone = AuraTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isActive = activeTab == id;
    final tone = auraToneColors(context, badgeTone);

    final semanticLabel = badgeCount > 0
        ? '$label, $badgeCount $badgeNoun'
        : label;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTabChange(id),
              borderRadius: AuraRadius.allSm,
              focusColor: p.accent.withValues(alpha: 0.18),
              child: Container(
                // 56 px de alto garantizados: es lo que se toca, no el dibujo.
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(vertical: AuraSpace.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: AuraMotion.base,
                          curve: AuraMotion.curve,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.md,
                            vertical: AuraSpace.xxs + 1,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? p.accentSurface
                                : Colors.transparent,
                            borderRadius: AuraRadius.allPill,
                          ),
                          child: Icon(
                            isActive ? activeIcon : icon,
                            color: isActive ? p.accentText : p.textMuted,
                            size: AuraIcon.lg - 4,
                          ),
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            top: -4,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(minWidth: 20),
                              decoration: BoxDecoration(
                                color: tone.fg,
                                borderRadius: AuraRadius.allPill,
                                border: Border.all(color: p.card, width: 2),
                              ),
                              child: Text(
                                badgeCount > 9 ? '9+' : '$badgeCount',
                                textAlign: TextAlign.center,
                                style: AppType.label.copyWith(
                                  // Los `on*` del esquema ya resuelven claro y
                                  // oscuro; el literal que había aquí solo
                                  // funcionaba en oscuro.
                                  color: context.scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.xxs),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppType.label.copyWith(
                        color: isActive ? p.accentText : p.textMuted,
                        fontWeight: isActive
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
