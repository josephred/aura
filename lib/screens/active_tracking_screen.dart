import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dependent.dart';
import '../models/service_request.dart';
import '../state/app_state.dart';

class ActiveTrackingScreen extends StatefulWidget {
  final AppState state;
  final ServiceRequest request;
  final Dependent? dependent;
  final VoidCallback onNavigateToChat;

  const ActiveTrackingScreen({
    super.key,
    required this.state,
    required this.request,
    this.dependent,
    required this.onNavigateToChat,
  });

  @override
  State<ActiveTrackingScreen> createState() => _ActiveTrackingScreenState();
}

class _ActiveTrackingScreenState extends State<ActiveTrackingScreen> {
  Timer? _timer;
  int _secondsLeft = 53;
  int _minutesLeft = 15;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsLeft > 1) {
            _secondsLeft--;
          } else {
            if (_minutesLeft > 0) {
              _minutesLeft--;
              _secondsLeft = 59;
            } else {
              _secondsLeft = 0;
              _timer?.cancel();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, String> _getAssignedProfessional(String serviceId) {
    switch (serviceId) {
      case 'medico':
        return {
          'name': 'Dr. Alejandro Russo',
          'specialty': 'Médico Generalista • Reg. 43102-B',
          'phone': '+56 9 8812 3410',
        };
      case 'enfermeria':
        return {
          'name': 'Enf. Paulina Rojas',
          'specialty': 'Enfermera Universitaria • Curaciones',
          'phone': '+56 9 7721 9831',
        };
      case 'ambulancia':
        return {
          'name': 'P. Aránguiz & Dr. Soto',
          'specialty': 'Paramédico & Médico de Traslado',
          'phone': '+56 9 6610 2110',
        };
      default:
        return {
          'name': 'Klgo. Sebastián Fuentealba',
          'specialty': 'Terapeuta Clínico Licenciado',
          'phone': '+56 9 5543 2120',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final prof = _getAssignedProfessional(request.serviceId);

    final steps = [
      {
        'title': 'Solicitado',
        'desc': 'Buscando prestador calificado disponible',
      },
      {
        'title': 'Confirmado',
        'desc': 'Personal clínico asignado y preparando insumos',
      },
      {
        'title': 'En Camino',
        'desc': 'Profesional viaja en dirección a su domicilio',
      },
      {
        'title': 'En Atención',
        'desc': 'Servicio clínico iniciándose en su hogar',
      },
      {'title': 'Completado', 'desc': 'Prestación realizada con éxito'},
    ];

    final isNotFinished =
        request.status != RequestStatus.completed &&
        request.status != RequestStatus.cancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tracking row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    height: 10,
                    width: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981), // emerald-500
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Seguimiento Clínico',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (isNotFinished)
                ElevatedButton(
                  onPressed: () {
                    widget.state.simulateNextStep();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE6F6F4),
                    foregroundColor: const Color(0xFF0D9488),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Avanzar Simulación',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Countdown target card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // brand-dark (slate-900)
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                // Top stripe gradient indicator
                Container(
                  height: 3,
                  width: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2DD4BF),
                        Color(0xFF10B981),
                        Color(0xFF0D9488),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                // Soft notice banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF334155).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF99F6E4),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESTADO DEL TRASLADO / ATENCIÓN',
                              style: TextStyle(
                                color: Color(0xFF2DD4BF),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Evaluación en progreso. Complete el registro si requiere reembolso aseguradora.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Timer circular display
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0D9488),
                      width: 3,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Color(0xFF0D9488),
                          size: 14,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '00:${_secondsLeft < 10 ? '0$_secondsLeft' : _secondsLeft}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'TIEMPO ESPERADO DE DEMORA',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_minutesLeft min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                // Payment summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF334155).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VALOR DE LA PRESTACIÓN',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${request.finalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} ARS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0D9488,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF0D9488,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF2DD4BF),
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pago Confirmado',
                              style: TextStyle(
                                color: Color(0xFF2DD4BF),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Route Tracking Map Mockup
          if (request.currentStep >= 1 &&
              request.status != RequestStatus.cancelled) ...[
            _buildMockTrackingMap(request.currentStep, request.serviceId),
            const SizedBox(height: 16),
          ],

          // Professional assigned details
          if (request.currentStep >= 1 &&
              request.status != RequestStatus.cancelled) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F6F4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'PROFESIONAL CLÍNICO ASIGNADO',
                              style: TextStyle(
                                color: Color(0xFF0D9488),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            prof['name']!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prof['specialty']!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6F6F4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: widget.onNavigateToChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE6F6F4),
                              foregroundColor: const Color(0xFF0D9488),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Chatear',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Marcando llamada simulada al número ${prof['phone']!}',
                                  ),
                                  backgroundColor: const Color(0xFF0D9488),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF475569),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_outlined, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Llamar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Steps timeline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROGRESO DEL SERVICIO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: steps.length,
                  itemBuilder: (context, idx) {
                    final step = steps[idx];
                    final isCompleted = request.currentStep >= idx;
                    final isCurrent = request.currentStep == idx;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vertical line + marker
                          Column(
                            children: [
                              Container(
                                height: 14,
                                width: 14,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? const Color(0xFF0D9488)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCompleted
                                        ? const Color(0xFF0D9488)
                                        : const Color(0xFFCBD5E1),
                                    width: 2,
                                  ),
                                ),
                                child: isCompleted
                                    ? const Center(
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 8,
                                        ),
                                      )
                                    : null,
                              ),
                              if (idx < steps.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: isCompleted
                                        ? const Color(0xFF0D9488)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 18.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        step['title']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent
                                              ? const Color(0xFF0F172A)
                                              : (isCompleted
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFF94A3B8)),
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6F6F4),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'ACTUAL',
                                            style: TextStyle(
                                              color: Color(0xFF0D9488),
                                              fontSize: 7,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    step['desc']!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metadata block
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DETALLES DE LA CITA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.person,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PACIENTE',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.dependent != null
                                ? '${widget.dependent!.name} (${widget.dependent!.relationship})'
                                : 'Usuario Principal',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          if (widget.dependent != null)
                            Text(
                              widget.dependent!.medicalConditions,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFFF43F5E),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DOMICILIO',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            request.addressText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cancel or Finish buttons
          if (isNotFinished)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancelar Solicitud'),
                      content: const Text(
                        '¿Está seguro de querer cancelar esta solicitud de atención clínica? Se podría aplicar un recargo por respuesta técnica si el profesional ya va en camino.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Volver'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.state.cancelRequest();
                          },
                          child: const Text(
                            'Cancelar Servicio',
                            style: TextStyle(color: Color(0xFFF43F5E)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF1F2),
                  foregroundColor: const Color(0xFFE11D48),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFFFE4E6)),
                  ),
                ),
                child: const Text(
                  'Cancelar Solicitud de Servicio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.state.completeSimulation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Volver a Inicio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMockTrackingMap(int step, String serviceId) {
    final isEnCamino = step == 2;
    String statusText = 'Preparando insumos clínicos';
    if (step == 2) {
      statusText = 'Vehículo de asistencia en trayecto';
    } else if (step == 3) {
      statusText = 'Especialista en su domicilio';
    } else if (step >= 4) {
      statusText = 'Atención médica finalizada';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SEGUIMIENTO EN TIEMPO REAL',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        serviceId == 'ambulancia'
                            ? Icons.local_shipping
                            : Icons.directions_run,
                        color: const Color(0xFF0369A1),
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'GPS ACTIVO',
                        style: TextStyle(
                          color: Color(0xFF0369A1),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map canvas
          Container(
            height: 140,
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: MockRoutePainter(
                      step: step,
                      secondsLeft: _secondsLeft,
                    ),
                  ),
                ),
                // Indicator pills for A (Specialist) and B (Home)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.grey, size: 10),
                        SizedBox(width: 3),
                        Text(
                          'A: Base Aura',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Color(0xFF0D9488),
                          size: 10,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'B: Tu Domicilio',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer
          if (step == 2)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF0D9488),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'El vehículo clínico se desplaza por autopista principal. Tránsito fluido.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: const Color(0xFF0D9488).withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MockRoutePainter extends CustomPainter {
  final int step;
  final int secondsLeft;

  MockRoutePainter({required this.step, required this.secondsLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1. Background Land (Slate-200 for high contrast with white streets)
    paint.color = const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 2. Draw coordinate grid lines
    paint.color = const Color(0xFFCBD5E1).withValues(alpha: 0.5);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    for (double i = 20; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 15; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // 3. Draw Parks (Green zones with outlines)
    paint.color = const Color(0xFFD1FAE5); // Emerald-100
    paint.style = PaintingStyle.fill;
    final park1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.08,
        size.width * 0.22,
        size.height * 0.45,
      ),
      const Radius.circular(10),
    );
    final park2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.72,
        size.height * 0.48,
        size.width * 0.23,
        size.height * 0.44,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(park1, paint);
    canvas.drawRRect(park2, paint);

    // Park outlines
    paint.color = const Color(0xFFA7F3D0); // Emerald-200
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawRRect(park1, paint);
    canvas.drawRRect(park2, paint);

    // 4. Draw River (Sky Blue water path)
    paint.color = const Color(0xFFBAE6FD); // Sky-200
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 16.0;
    final riverPath = Path();
    riverPath.moveTo(0, size.height * 0.85);
    riverPath.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.5,
      size.width,
      size.height * 0.35,
    );
    canvas.drawPath(riverPath, paint);

    // River inner flow line
    paint.color = const Color(0xFF7DD3FC); // Sky-300
    paint.strokeWidth = 2.0;
    canvas.drawPath(riverPath, paint);

    // 5. Draw Streets (Double-line style: casing + white inline)
    final streets = [
      // Horizontal streets
      [Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3)],
      [Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7)],
      // Vertical streets
      [Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height)],
      [Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height)],
    ];

    // Casing
    paint.color = const Color(0xFF94A3B8); // Slate-400
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 9.0;
    for (var street in streets) {
      canvas.drawLine(street[0], street[1], paint);
    }

    // Inline
    paint.color = Colors.white;
    paint.strokeWidth = 6.0;
    for (var street in streets) {
      canvas.drawLine(street[0], street[1], paint);
    }

    // 6. Draw Street and River Labels
    _drawText(
      canvas,
      "Río Mapocho",
      Offset(size.width * 0.42, size.height * 0.53),
      color: const Color(0xFF0369A1),
      size: 7.5,
      italic: true,
    );
    _drawText(
      canvas,
      "Av. Providencia",
      Offset(size.width * 0.05, size.height * 0.25),
      color: const Color(0xFF64748B),
      size: 7.0,
      bold: true,
    );
    _drawText(
      canvas,
      "Av. Andrés Bello",
      Offset(size.width * 0.05, size.height * 0.65),
      color: const Color(0xFF64748B),
      size: 7.0,
      bold: true,
    );
    _drawText(
      canvas,
      "Calle Lota",
      Offset(size.width * 0.22, size.height * 0.85),
      color: const Color(0xFF64748B),
      size: 6.5,
      bold: true,
      rotate90: true,
    );
    _drawText(
      canvas,
      "Av. Suecia",
      Offset(size.width * 0.58, size.height * 0.05),
      color: const Color(0xFF64748B),
      size: 6.5,
      bold: true,
      rotate90: true,
    );

    // 7. Draw Route Path (thick dark teal line with highlight effect)
    final pStart = Offset(size.width * 0.15, size.height * 0.25); // A
    final pEnd = Offset(size.width * 0.8, size.height * 0.75); // B
    final pControl = Offset(size.width * 0.4, size.height * 0.75);

    // Route path outline
    paint.color = const Color(0xFF115E59).withValues(alpha: 0.3);
    paint.strokeWidth = 6.0;
    paint.style = PaintingStyle.stroke;
    final routePath = Path();
    routePath.moveTo(pStart.dx, pStart.dy);
    routePath.quadraticBezierTo(pControl.dx, pControl.dy, pEnd.dx, pEnd.dy);
    canvas.drawPath(routePath, paint);

    // Route path core
    paint.color = const Color(0xFF0D9488);
    paint.strokeWidth = 3.5;
    canvas.drawPath(routePath, paint);

    // 8. Draw Pins A & B
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF64748B);
    canvas.drawCircle(pStart, 5, paint);
    paint.color = Colors.white;
    canvas.drawCircle(pStart, 2, paint);

    paint.color = const Color(0xFFF43F5E);
    canvas.drawCircle(pEnd, 6, paint);
    paint.color = Colors.white;
    canvas.drawCircle(pEnd, 2.5, paint);

    // 9. Draw the vehicle position (moving dot)
    double t = 0.0;
    if (step <= 1) {
      t = 0.0;
    } else if (step == 2) {
      double baseProg = (60 - secondsLeft) / 60.0;
      t = 0.15 + (baseProg * 0.65);
    } else {
      t = 1.0;
    }

    final x =
        (1 - t) * (1 - t) * pStart.dx +
        2 * (1 - t) * t * pControl.dx +
        t * t * pEnd.dx;
    final y =
        (1 - t) * (1 - t) * pStart.dy +
        2 * (1 - t) * t * pControl.dy +
        t * t * pEnd.dy;
    final vehiclePos = Offset(x, y);

    if (step == 2) {
      final pulsePaint = Paint()
        ..color = const Color(0xFF0D9488).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(vehiclePos, 10.0 + (secondsLeft % 3 * 3), pulsePaint);
    }

    paint.color = const Color(0xFF0D9488);
    canvas.drawCircle(vehiclePos, 8, paint);
    paint.color = Colors.white;
    canvas.drawCircle(vehiclePos, 4, paint);
    paint.color = const Color(0xFF115E59);
    canvas.drawCircle(vehiclePos, 2, paint);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    double size = 7.0,
    bool bold = false,
    bool italic = false,
    bool rotate90 = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: 0.3,
        fontFamily: 'Inter',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    if (rotate90) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(1.5708);
      textPainter.paint(canvas, const Offset(0, 0));
      canvas.restore();
    } else {
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension _ElevatedButtonExtension on ElevatedButton {
  Widget child(Widget child) {
    return child;
  }
}
