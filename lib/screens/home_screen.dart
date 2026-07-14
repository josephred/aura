import 'dart:math';
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
    if (state.currentRole == 'doctor_provider') {
      return _buildDoctorDashboard(context);
    } else if (state.currentRole == 'operator_admin') {
      return _buildAdminDashboard(context);
    } else if (state.currentRole == 'ambulance_driver') {
      return _buildDriverDashboard(context);
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

  Widget _buildDoctorDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF2DD4BF),
                  child: Text(
                    state.userName.isNotEmpty ? state.userName.substring(0, 1).toUpperCase() : 'C',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.userName.isNotEmpty ? 'Dr/a. ${state.userName}' : 'Dr. Camila Rivera',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Médico General / Prestador Clínico',
                        style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status toggle
          StatefulBuilder(
            builder: (context, setLocalState) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xFF10B981), size: 12),
                        SizedBox(width: 8),
                        Text(
                          'Estado de Guardia Activa',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Switch(
                      value: true,
                      activeThumbColor: const Color(0xFF0D9488),
                      onChanged: (val) {},
                    ),
                  ],
                ),
              );
            }
          ),
          const SizedBox(height: 24),

          // Pending solicitudes section
          const Text(
            'Solicitudes de Atención en Tu Área',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          // Mock requests
          _buildRequestCard(
            context: context,
            patientName: 'Margarita Sotomayor (76 años)',
            service: 'Toma de Muestras y Laboratorio',
            price: '\$19,500',
            address: 'Calle Los Alerces 1420, Providencia',
            onAccept: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Solicitud aceptada. Se ha notificado al paciente y se inició la ruta.'),
                  backgroundColor: Color(0xFF0D9488),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildRequestCard(
            context: context,
            patientName: 'Mateo González (8 años)',
            service: 'Kinesiología Respiratoria',
            price: '\$24,000',
            address: 'Avenida Vitacura 5410, Vitacura',
            onAccept: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Solicitud aceptada. Ruta iniciada.'),
                  backgroundColor: Color(0xFF0D9488),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard({
    required BuildContext context,
    required String patientName,
    required String service,
    required String price,
    required String address,
    required VoidCallback onAccept,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                service,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D9488)),
              ),
              Text(
                price,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(patientName, style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(address, style: const TextStyle(color: Color(0xFF475569), fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: const Text('Rechazar', style: TextStyle(color: Color(0xFF64748B))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF475569)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFF1F5F9),
                  child: Icon(Icons.tune, color: Color(0xFF0F172A), size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panel de Administración Aura',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Operador de Turno / Coordinador',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _ActiveRadarWidget(),
          const SizedBox(height: 20),

          // Operational metrics grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildMetricCard('Médicos Online', '8 / 12', Icons.people, const Color(0xFF0D9488)),
              _buildMetricCard('Servicios Activos', '4 de Hoy', Icons.assignment_turned_in, const Color(0xFF3B82F6)),
              _buildMetricCard('ETA Promedio', '28 mins', Icons.timer, const Color(0xFFF59E0B)),
              _buildMetricCard('Recetas por Validar', '1 Alerta', Icons.assignment_late, const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 24),

          // System Parameters Configuration Section
          const Text(
            'Configuración y Parámetros del Sistema',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Simulation Speed
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Velocidad de Simulación (GPS)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                        ),
                        Text(
                          '${state.simulationSpeed.toStringAsFixed(1)}x',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488)),
                        ),
                      ],
                    ),
                    Slider(
                      value: state.simulationSpeed,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      activeColor: const Color(0xFF0D9488),
                      inactiveColor: const Color(0xFFE2E8F0),
                      onChanged: (val) {
                        setState(() {
                          state.setSimulationSpeed(val);
                        });
                      },
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),

                    // Doctor Search Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Retraso en Búsqueda de Médico',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                        ),
                        Text(
                          '${state.doctorSearchTimeSeconds}s',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488)),
                        ),
                      ],
                    ),
                    Slider(
                      value: state.doctorSearchTimeSeconds.toDouble(),
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      activeColor: const Color(0xFF0D9488),
                      inactiveColor: const Color(0xFFE2E8F0),
                      onChanged: (val) {
                        setState(() {
                          state.setDoctorSearchTimeSeconds(val.round());
                        });
                      },
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),

                    // Commission Rate
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Comisión de Servicio (Aura)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                        ),
                        Text(
                          '${(state.commissionRate * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488)),
                        ),
                      ],
                    ),
                    Slider(
                      value: state.commissionRate,
                      min: 0.05,
                      max: 0.35,
                      divisions: 6,
                      activeColor: const Color(0xFF0D9488),
                      inactiveColor: const Color(0xFFE2E8F0),
                      onChanged: (val) {
                        setState(() {
                          state.setCommissionRate(double.parse(val.toStringAsFixed(2)));
                        });
                      },
                    ),
                  ],
                );
              }
            ),
          ),
          const SizedBox(height: 24),

          // Database & Network Operations
          const Text(
            'Acciones de Base de Datos y Red',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artificial Offline Switch
                StatefulBuilder(
                  builder: (context, setState) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Color(0xFF475569), size: 18),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Simular Caída de Red',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                                ),
                                Text(
                                  'Bloquea peticiones HTTP de la API',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: state.simulateOffline,
                          activeThumbColor: const Color(0xFFEF4444),
                          activeTrackColor: const Color(0xFFFEE2E2),
                          onChanged: (val) {
                            setState(() {
                              state.setSimulateOffline(val);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  val
                                      ? 'Modo sin conexión simulado: Activado'
                                      : 'Conexión restaurada',
                                ),
                                backgroundColor: val ? Colors.red : Colors.green,
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),

                // Action Buttons Row
                Row(
                  children: [
                    // Force Sync Outbox
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await state.forceFlushOutbox();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cola de peticiones offline vaciada (Flush).'),
                                backgroundColor: Color(0xFF0D9488),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync_rounded, size: 14),
                        label: const Text('Forzar Sincro'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Clear Cache
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await state.clearLocalCache();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Caché e inicio de sesión borrados. Base de datos segura limpia.'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                        label: const Text('Limpiar Caché'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          foregroundColor: const Color(0xFFEF4444),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Provider Management Section
          const Text(
            'Gestión de Prestadores de Turno',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.systemProviders.length,
              separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 16),
              itemBuilder: (context, index) {
                final provider = state.systemProviders[index];
                final String status = provider['status'] as String;

                Color statusColor = const Color(0xFF10B981); // Green for Disponible
                if (status == 'Ocupado') statusColor = const Color(0xFFF59E0B);
                if (status == 'Desconectado') statusColor = const Color(0xFFEF4444);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      // Status Circle indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Provider details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              provider['specialty'] as String,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      // Dropdown / Segment selector for status
                      DropdownButton<String>(
                        value: status,
                        underline: const SizedBox(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        icon: Icon(Icons.arrow_drop_down_rounded, color: statusColor, size: 18),
                        onChanged: (newVal) {
                          if (newVal != null) {
                            state.setProviderStatus(provider['id'] as String, newVal);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${provider['name'] as String} cambiado a "$newVal".'),
                                backgroundColor: const Color(0xFF0D9488),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'Disponible',
                            child: Text('Disponible'),
                          ),
                          DropdownMenuItem(
                            value: 'Ocupado',
                            child: Text('Ocupado'),
                          ),
                          DropdownMenuItem(
                            value: 'Desconectado',
                            child: Text('Desconectado'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Prescription Validation Queue
          const Text(
            'Cola de Validación de Recetas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Receta Médica - Enfermería',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Pendiente',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Paciente: Mateo González', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                const SizedBox(height: 4),
                const Text('Archivo adjunto: receta_amoxicilina.jpg', style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 12, decoration: TextDecoration.underline)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Receta rechazada (no legible). Se notificó al paciente.'), backgroundColor: Color(0xFFEF4444)),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                        ),
                        child: const Text('Rechazar', style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Receta aprobada con éxito. Solicitud habilitada.'), backgroundColor: Color(0xFF0D9488)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Aprobar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildDriverDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.local_shipping, color: Color(0xFF0D9488), size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conductor de Ambulancia Aura',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Móvil de Asistencia Avanzada B-12',
                        style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Active route
          const Text(
            'Tu Ruta de Traslado Activo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Traslado Programado',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A)),
                    ),
                    Text(
                      'En Ruta',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Origen (Retiro)', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          Text('Calle Los Alerces 1420, Providencia', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.flag, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Destino (Arribo)', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          Text('Clínica Alemana de Vitacura, Vitacura', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ubicación compartida por GPS. Se notificó al centro médico del arribo.'), backgroundColor: Color(0xFF0D9488)),
                          );
                        },
                        icon: const Icon(Icons.gps_fixed, size: 16),
                        label: const Text('Marcar Arribo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRadarWidget extends StatefulWidget {
  const _ActiveRadarWidget();

  @override
  State<_ActiveRadarWidget> createState() => _ActiveRadarWidgetState();
}

class _ActiveRadarWidgetState extends State<_ActiveRadarWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_RadarEntity> _entities = [
    _RadarEntity(label: 'AMB-12', type: 'ambulance', baseOffset: const Offset(-60, 40), angleOffset: 0.0, speed: 0.8),
    _RadarEntity(label: 'DR-Russo', type: 'doctor', baseOffset: const Offset(70, -30), angleOffset: 1.5, speed: 0.5),
    _RadarEntity(label: 'ENF-Cristian', type: 'doctor', baseOffset: const Offset(-20, -70), angleOffset: 3.1, speed: 0.6),
    _RadarEntity(label: 'PAC-Mateo', type: 'patient', baseOffset: const Offset(30, 60), angleOffset: 0.0, speed: 0.0), // Stationary
    _RadarEntity(label: 'AMB-05', type: 'ambulance', baseOffset: const Offset(80, 50), angleOffset: 4.2, speed: 1.2),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1329), // Deep dark space tech color
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(
              sweepAngle: _controller.value * 2 * pi,
              entities: _entities,
              animationValue: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _RadarEntity {
  final String label;
  final String type; // 'ambulance' | 'doctor' | 'patient'
  final Offset baseOffset;
  final double angleOffset;
  final double speed;

  _RadarEntity({
    required this.label,
    required this.type,
    required this.baseOffset,
    required this.angleOffset,
    required this.speed,
  });

  Offset getAnimatedOffset(double t) {
    if (speed == 0) return baseOffset; // Stationary
    // Circular orbit motion around base offset
    final radius = 15.0;
    final angle = angleOffset + (t * 2 * pi * speed);
    return baseOffset + Offset(cos(angle) * radius, sin(angle) * radius);
  }
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final List<_RadarEntity> entities;
  final double animationValue;

  _RadarPainter({
    required this.sweepAngle,
    required this.entities,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 * 0.9;

    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final axisPaint = Paint()
      ..color = const Color(0xFF0D9488).withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 1. Draw grid circles
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * (i / 4), gridPaint);
    }

    // 2. Draw orthogonal axes
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), axisPaint);

    // 3. Draw rotating sweep line (conical gradient scanner shadow)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - 0.5,
        endAngle: sweepAngle,
        colors: [
          const Color(0xFF0D9488).withValues(alpha: 0.0),
          const Color(0xFF0D9488).withValues(alpha: 0.3),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    // Draw the pie slice representing the radar beam sweep
    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Dynamic sweep line
    final linePaint = Paint()
      ..color = const Color(0xFF2DD4BF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final sweepLineEnd = center + Offset(cos(sweepAngle) * maxRadius, sin(sweepAngle) * maxRadius);
    canvas.drawLine(center, sweepLineEnd, linePaint);

    // 4. Draw entities
    for (final entity in entities) {
      final pos = center + entity.getAnimatedOffset(animationValue);

      // Skip drawing if outside radar ring boundary
      if ((pos - center).distance > maxRadius) continue;

      // Calculate angle of entity relative to center
      final entityAngle = atan2(pos.dy - center.dy, pos.dx - center.dx);
      // Normalized angles between 0 and 2pi
      var diff = (sweepAngle - entityAngle) % (2 * pi);
      
      // Draw entity only if it was recently scanned (fading trail effect)
      double intensity = 1.0 - (diff / (2 * pi));
      if (intensity < 0.1) intensity = 0.1; // Baseline visibility

      final Color dotColor = switch (entity.type) {
        'ambulance' => const Color(0xFF3B82F6), // blue
        'doctor' => const Color(0xFF10B981), // emerald green
        'patient' => const Color(0xFFEF4444), // red
        _ => Colors.white,
      };

      // Outer glowing ring
      final glowPaint = Paint()
        ..color = dotColor.withValues(alpha: intensity * 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 6.0 + (sin(animationValue * 10) * 2), glowPaint);

      // Inner dot
      final dotPaint = Paint()
        ..color = dotColor.withValues(alpha: intensity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 3.5, dotPaint);

      // Label text
      final textPainter = TextPainter(
        text: TextSpan(
          text: entity.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: intensity * 0.8),
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(pos.dx + 6, pos.dy - 4));
    }

    // 5. Draw decorative tech elements on the map
    final borderPaint = Paint()
      ..color = const Color(0xFF0D9488).withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    // Top-left angle reticle
    canvas.drawPath(
      Path()
        ..moveTo(10, 20)
        ..lineTo(10, 10)
        ..lineTo(20, 10),
      borderPaint,
    );
    // Bottom-right angle reticle
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 10, size.height - 20)
        ..lineTo(size.width - 10, size.height - 10)
        ..lineTo(size.width - 20, size.height - 10),
      borderPaint,
    );

    // Text Overlay
    final statusPainter = TextPainter(
      text: const TextSpan(
        text: 'RADAR DESPACHO: ACTIVO\nAMB: 2 | DOC: 2 | PAC: 1\nSANTIAGO - ZONA SUR',
        style: TextStyle(
          color: Color(0xFF2DD4BF),
          fontSize: 7,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    statusPainter.paint(canvas, const Offset(15, 15));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
