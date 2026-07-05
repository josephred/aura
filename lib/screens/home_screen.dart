import 'package:flutter/material.dart';
import '../models/clinical_service.dart';
import '../models/service_request.dart';
import '../state/app_state.dart';
import '../data/mock_data.dart';
import 'appointments_screen.dart';

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
        return const Color(0xFF0D9488); // teal-600
      case 'UserRoundPlus':
        return const Color(0xFF10B981); // emerald-600
      case 'Footprints':
        return const Color(0xFF06B6D4); // cyan-600
      case 'Lungs':
        return const Color(0xFF0EA5E9); // sky-600
      case 'HeartHandshake':
        return const Color(0xFF0D9488); // teal-600
      case 'Truck':
        return const Color(0xFF2563EB); // blue-600
      case 'ScanFace':
        return const Color(0xFF4F46E5); // indigo-600
      case 'FlaskConical':
        return const Color(0xFF9333EA); // purple-600
      case 'Heart':
        return const Color(0xFFF43F5E); // rose-500
      default:
        return const Color(0xFF0D9488);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFE6F6F4), // brand-mint
                  Color(0xFFCCFBF1), // brand-cyan
                  Color(0xFFE0F2FE), // sky-100
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
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
                                color: const Color(0xFF0D9488),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0D9488,
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
                              text: const TextSpan(
                                text: 'Aura ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Salud',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF0D9488),
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
                                const Text(
                                  'COBERTURA ACTIVA',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
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
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFCCFBF1),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Color(0xFF0D9488),
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Providencia',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
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
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFCCFBF1),
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 18,
                                color: Color(0xFF0F172A),
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
                                  child: const Center(
                                    child: Text(
                                      '1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
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
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Color(0xFF0D9488),
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Atención Domiciliaria Profesional',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '¿Cómo podemos ayudar?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  primaryDependent != null
                      ? 'Solicitando para: ${primaryDependent.name} (${primaryDependent.relationship})'
                      : 'Bienvenido(a) a Aura. Servicios médicos en la puerta de su hogar.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
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
                        color: const Color(0xFFECFDF5), // emerald-50
                        border: Border.all(
                          color: const Color(0xFFA7F3D0),
                        ), // emerald-200
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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Atención activa en curso',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF064E3B),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Seguimiento y ETA estimados para Providencia.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF047857),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD1FAE5),
                              ),
                            ),
                            child: const Text(
                              'Ver Mapa',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2b. Scheduled appointments entry point
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppointmentsScreen(state: state),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Citas con especialistas',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Agenda una consulta con nuestro equipo',
                                style: TextStyle(
                                  color: Color(0xFFCCFBF1),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
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
                        color: Color(0xFF0D9488),
                        size: 20,
                      ),
                      hintText: 'Buscar enfermería, kine, médico...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
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
                        'all',
                        'Todos (${clinicalServices.length})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterPill('require_rx', 'Requiere Receta (6)'),
                      const SizedBox(width: 8),
                      _buildFilterPill('no_rx', 'Acceso Directo (3)'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Emergency Warning Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB), // amber-50
                    border: Border.all(
                      color: const Color(0xFFFDE68A).withValues(alpha: 0.4),
                    ), // amber-100
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aura es una plataforma de servicios clínicos domiciliarios programados y semi-urgentes. En caso de riesgo vital llame inmediatamente a urgencias.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 6. Specialties Title
                const Text(
                  'ESPECIALIDADES DISPONIBLES',
                  style: TextStyle(
                    fontSize: 10,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: const Center(
                          child: Text(
                            'No se han encontrado especialidades médicas.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
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
                          return _buildServiceCard(service);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final isSelected = state.selectedFilterCategory == id;
    return GestureDetector(
      onTap: () => state.setFilterCategory(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9488) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D9488)
                : const Color(0xFFF1F5F9),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(ClinicalService service) {
    return GestureDetector(
      onTap: () => onSelectService(service),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon frame
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F6F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getIconData(service.iconName),
                color: _getIconColor(service.iconName),
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
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
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Text(
                            'REQUIERE ORDEN',
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 7,
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
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
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFCBD5E1),
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  '${service.baseEta} min',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
