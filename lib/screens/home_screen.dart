import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../models/clinical_service.dart';
import '../models/service_request.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/service_specialties.dart';
import '../widgets/video_onboarding_dialog.dart';
import 'book_appointment_screen.dart';
import 'operations_dashboard.dart';
import 'staff_dashboard.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  final ValueChanged<ClinicalService> onSelectService;

  const HomeScreen({
    super.key,
    required this.state,
    required this.onSelectService,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'Activity':
        return Icons.healing;
      case 'UserRoundPlus':
        return Icons.local_hospital;
      case 'Footprints':
        return Icons.directions_walk;
      case 'Lungs':
        return Icons.air;
      case 'HeartHandshake':
        return Icons.favorite_border;
      case 'Truck':
        return Icons.local_shipping;
      case 'ScanFace':
        return Icons.camera_enhance;
      case 'FlaskConical':
        return Icons.science;
      case 'Heart':
        return Icons.favorite;
      default:
        return Icons.medical_services;
    }
  }

  Color _getIconColor(String iconName) {
    switch (iconName) {
      case 'Activity':
        return const Color(0xFF0F766E); // teal-600
      case 'UserRoundPlus':
        return const Color(0xFF10B981); // emerald-600
      case 'Footprints':
        return const Color(0xFF06B6D4); // cyan-600
      case 'Lungs':
        return const Color(0xFF0EA5E9); // sky-600
      case 'HeartHandshake':
        return const Color(0xFF0F766E); // teal-600
      case 'Truck':
        return const Color(0xFF2563EB); // blue-600
      case 'ScanFace':
        return const Color(0xFF4F46E5); // indigo-600
      case 'FlaskConical':
        return const Color(0xFF9333EA); // purple-600
      case 'Heart':
        return const Color(0xFFF43F5E); // rose-500
      default:
        return const Color(0xFF0F766E);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Staff roles get their own real, API-backed workspaces. They used to be
    // mock panels built right here with fixed patient names and buttons that
    // only showed a snackbar.
    if (state.currentRole == 'doctor_provider') {
      return StaffDashboard(state: state);
    } else if (state.currentRole == 'ambulance_driver') {
      return StaffDashboard(state: state, ambulanceOnly: true);
    } else if (state.currentRole == 'operator_admin') {
      return OperationsDashboard(state: state);
    }

    final activeRequest = state.currentRequest;
    final isActiveActive =
        activeRequest != null &&
        activeRequest.status != RequestStatus.completed &&
        activeRequest.status != RequestStatus.cancelled;

    final primaryDependent = state.dependents.isNotEmpty
        ? state.dependents.first
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Premium Header with gradients
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [
                        const Color(0xFF0F172A),
                        const Color(0xFF1E293B),
                        const Color(0xFF0F766E).withValues(alpha: 0.3),
                      ]
                    : [
                        const Color(0xFFE6F6F4),
                        const Color(0xFFCCFBF1),
                        const Color(0xFFE0F2FE),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Shield Check Icon Badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0F766E,
                                    ).withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                height: 8,
                                width: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'Aura ',
                                style: AppType.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Salud',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  height: 5,
                                  width: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                  'COBERTURA ACTIVA',
                                  style: AppType.label.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: context.palette.textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Map Pin Location pill
                        GestureDetector(
                          onTap: () => state.setTab('profile'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCCFBF1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF0F766E),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                  'Providencia',
                                  style: AppType.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Notification Bell
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCCFBF1),
                                ),
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (isActiveActive)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  height: 12,
                                  width: 12,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF43F5E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '1',
                                      style: AppType.bodySmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Welcome Text
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Color(0xFF0F766E),
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                        'Atención Domiciliaria Profesional',
                        style: AppType.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '¿Cómo podemos ayudar?',
                  style: AppType.display.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  primaryDependent != null
                      ? 'Solicitando para: ${primaryDependent.name} (${primaryDependent.relationship})'
                      : 'Bienvenido(a) a Aura. Servicios médicos en la puerta de su hogar.',
                  style: AppType.bodySmall.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Active tracking banner shortcut
                if (isActiveActive) ...[
                  GestureDetector(
                    onTap: () => state.setTab('appointments'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.2)
                            : const Color(0xFFECFDF5),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF059669).withValues(alpha: 0.4)
                              : const Color(0xFFA7F3D0),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 8,
                            width: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Atención activa en curso',
                                  style: AppType.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF064E3B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Seguimiento y ETA estimados para Providencia.',
                                  style: AppType.bodySmall.copyWith(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF064E3B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFFD1FAE5),
                              ),
                            ),
                            child: Text(
                              'Ver Mapa',
                              style: AppType.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2DD4BF)
                                    : const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: state.setSearchQuery,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF0F766E),
                        size: 20,
                      ),
                      hintText: 'Buscar enfermería, kine, médico...',
                      hintStyle: AppType.bodySmall.copyWith(
                        color: context.palette.textFaint,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    style: AppType.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Category Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill(
                        context,
                        'all',
                        'Todos (${state.services.length})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterPill(context, 'require_rx', 'Requiere Receta (6)'),
                      const SizedBox(width: 8),
                      _buildFilterPill(context, 'no_rx', 'Acceso Directo (3)'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Safety notice. Dismissible and remembered, so a returning
                // patient is not made to read it on every visit. It can be
                // brought back from Mi Cuenta › Accesibilidad.
                if (!state.safetyNoticeDismissed) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF78350F).withValues(alpha: 0.2)
                          : const Color(0xFFFFFBEB),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                            : const Color(0xFFFDE68A).withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Aura es una plataforma de servicios clínicos domiciliarios programados y semi-urgentes. En caso de riesgo vital llame inmediatamente a urgencias.',
                            style: AppType.bodySmall.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: state.dismissSafetyNotice,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFF92400E),
                          tooltip: 'No volver a mostrar este aviso',
                          // 48×48 aunque el icono mida 16: el objetivo táctil
                          // no es el dibujo. Con 32 y densidad compacta este
                          // botón quedaba por debajo del mínimo recomendado, y
                          // es el que cierra el aviso de riesgo vital —fallar
                          // el toque aquí significa tocar otra cosa.
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 5b. A.3 — acceso a la guía de primeros pasos. Va aquí, sobre
                // el catálogo, porque el momento en que alguien no sabe cómo
                // pedir es justo antes de elegir un servicio, no dentro de los
                // ajustes de su cuenta.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => VideoOnboardingDialog.show(context),
                    icon: const Icon(Icons.help_outline_rounded, size: 16),
                    label: const Text('¿Cómo funciona? Guía de primeros pasos'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppType.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Specialties Title
                Text(
                  'ESPECIALIDADES DISPONIBLES',
                  style: AppType.label.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                // 7. Services List
                state.filteredServices.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.palette.border),
                        ),
                        child: Center(
                          child: Text(
                            'No se han encontrado especialidades médicas.',
                            style: AppType.bodySmall.copyWith(
                              color: context.palette.textFaint,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.filteredServices.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final service = state.filteredServices[index];
                          return _buildServiceCard(context, service);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(BuildContext context, String id, String label) {
    final isSelected = state.selectedFilterCategory == id;
    return GestureDetector(
      onTap: () => state.setFilterCategory(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F766E)
                : Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: AppType.label.copyWith(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Opens the scheduled-appointment flow already narrowed down to the
  /// discipline behind [service] (médico, enfermería, kinesiología…).
  void _openScheduling(BuildContext context, ClinicalService service) {
    final specialty = specialtyForService(service.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(
          state: state,
          specialtyFilter: specialty?.searchTerms,
          headerTitle: specialty == null
              ? 'Agendar cita'
              : 'Agendar con ${specialty.label}',
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, ClinicalService service) {
    final theme = Theme.of(context);
    final canSchedule = specialtyForService(service.id) != null;
    return GestureDetector(
      onTap: () => onSelectService(service),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon frame
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF134E4A) // dark teal
                        : const Color(0xFFE6F6F4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getIconData(service.iconName),
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF2DD4BF)
                        : _getIconColor(service.iconName),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Title & details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              service.shortTitle,
                              style: AppType.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (service.requiresPrescription) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF78350F).withValues(alpha: 0.3)
                                    : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                      : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Text(
                                'REQUIERE ORDEN',
                                style: AppType.bodySmall.copyWith(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        service.subtitle,
                        style: AppType.bodySmall.copyWith(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Chevron and ETA
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.chevron_right,
                      color: context.palette.borderStrong,
                      size: 18,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${service.baseEta} min',
                      style: AppType.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Per-professional scheduling: the "citas con especialistas"
            // entry point now lives on each discipline instead of a single
            // banner on the home screen.
            if (canSchedule) ...[
              Divider(
                height: 18,
                color: theme.dividerColor.withValues(alpha: 0.15),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ahora a domicilio',
                      style: AppType.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textMuted,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openScheduling(context, service),
                    icon: const Icon(Icons.calendar_month, size: 14),
                    label: const Text('Agendar cita'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppType.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

}
