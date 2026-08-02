import 'package:flutter/material.dart';

/// Screen managing preventive health:
/// - Pediatric vaccination calendar alerts by child age.
/// - Adult preventive health checkup recommendations by age bracket.
class PreventiveHealthScreen extends StatefulWidget {
  const PreventiveHealthScreen({super.key});

  @override
  State<PreventiveHealthScreen> createState() => _PreventiveHealthScreenState();
}

class _PreventiveHealthScreenState extends State<PreventiveHealthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _vaccineCalendar = [
    {
      'age': 'Recién Nacido',
      'vaccines': ['BCG (Tuberculosis)', 'Hepatitis B'],
      'status': 'Completada',
    },
    {
      'age': '2 Meses',
      'vaccines': ['Pentavalente (DTPb+Hib+HepB)', 'Polio Inactivada', 'Neumocócica Conjugada'],
      'status': 'Completada',
    },
    {
      'age': '4 Meses',
      'vaccines': ['Pentavalente (2ª dosis)', 'Polio (2ª dosis)', 'Neumocócica (2ª dosis)'],
      'status': 'Pendiente Próxima',
    },
    {
      'age': '6 Meses',
      'vaccines': ['Pentavalente (3ª dosis)', 'Polio (3ª dosis)'],
      'status': 'Programada',
    },
    {
      'age': '12 Meses',
      'vaccines': ['Tres VÍrica (SRP)', 'Meningocócica Recombinante', 'Neumocócica (refuerzo)'],
      'status': 'Programada',
    },
  ];

  final List<Map<String, dynamic>> _adultCheckups = [
    {
      'ageBracket': '30 - 39 Años',
      'title': 'Chequeo Preventivo Inicial',
      'description': 'Perfil lipídico, glicemia en ayuno, hemograma completo y evaluación médica preventiva general.',
      'urgency': 'Recomendado',
      'serviceId': 'laboratorio',
    },
    {
      'ageBracket': '40 - 49 Años',
      'title': 'Control Cardiovascular y Salud Metabólica',
      'description': 'Electrocardiograma de reposo, control de presión arterial, perfil hepático y renal.',
      'urgency': 'Prioritario',
      'serviceId': 'electrocardiograma',
    },
    {
      'ageBracket': '50+ Años',
      'title': 'Chequeo Oncológico y Digestivo Preventivo',
      'description': 'Antígeno prostático (hombres) / Mamografía y Papanicolau (mujeres), test de sangre oculta en deposiciones.',
      'urgency': 'Alta Prioridad',
      'serviceId': 'laboratorio',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Salud Preventiva y Alertas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0D9488),
          labelColor: const Color(0xFF0D9488),
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          tabs: const [
            Tab(text: 'Vacunación Pediátrica'),
            Tab(text: 'Alertas por Edad (Adultos)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPediatricTab(isDark),
          _buildAdultTab(isDark),
        ],
      ),
    );
  }

  Widget _buildPediatricTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.child_care_rounded, color: Color(0xFF0D9488), size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendario Nacional de Vacunación Minsal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Alertas activas para mantener al día el esquema de inmunización pediátrico.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._vaccineCalendar.map((item) {
          final isDone = item['status'] == 'Completada';
          final isNext = item['status'] == 'Pendiente Próxima';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isNext
                    ? const Color(0xFF0D9488)
                    : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                width: isNext ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['age'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.green.withValues(alpha: 0.15)
                            : (isNext
                                ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item['status'],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDone
                              ? Colors.green[700]
                              : (isNext ? const Color(0xFF0D9488) : Colors.grey[700]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...(item['vaccines'] as List<String>).map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: isDone ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          v,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdultTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: Colors.amber, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recomendaciones de Chequeos por Edad',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Alertas preventivas personalizadas según el rango etario registrado en tu perfil.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._adultCheckups.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['ageBracket'],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ),
                    Text(
                      item['urgency'],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  item['description'],
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Iniciando solicitud de chequeo sugerido...'),
                          backgroundColor: Color(0xFF0D9488),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: const Text('Agendar Chequeo Sugerido', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
