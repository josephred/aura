import 'package:flutter/material.dart';

import '../models/dependent.dart';
import '../state/app_state.dart';

/// D.2 — salud preventiva:
/// - Calendario de vacunación pediátrica según la edad real del niño.
/// - Alertas de chequeo para adultos según su rango etario.
///
/// Una advertencia que gobierna toda esta pantalla: **Aura no tiene el registro
/// de vacunas de nadie**. Puede decir qué corresponde a una edad, nunca qué se
/// administró. Marcar una dosis como "completada" sin haberla registrado sería
/// darle a un padre una tranquilidad que no le consta a nadie.
class PreventiveHealthScreen extends StatefulWidget {
  final AppState state;

  const PreventiveHealthScreen({super.key, required this.state});

  @override
  State<PreventiveHealthScreen> createState() => _PreventiveHealthScreenState();
}

/// Una cita del calendario nacional, anclada a la edad en meses.
class _VaccineMilestone {
  final int months;
  final String label;
  final List<String> vaccines;

  const _VaccineMilestone(this.months, this.label, this.vaccines);
}

/// Un chequeo recomendado a partir de cierta edad.
class _AdultCheckup {
  final int fromAge;
  final int? toAge;
  final String title;
  final String description;
  final String serviceId;

  const _AdultCheckup({
    required this.fromAge,
    this.toAge,
    required this.title,
    required this.description,
    required this.serviceId,
  });

  String get bracket => toAge == null ? '$fromAge+ años' : '$fromAge - $toAge años';

  bool covers(int age) {
    if (age < fromAge) return false;

    // Copia local: Dart no promueve un campo público `int?` a `int` tras el
    // chequeo de null, así que `age <= toAge` no compila escrito en línea.
    final upper = toAge;

    return upper == null || age <= upper;
  }
}

class _PreventiveHealthScreenState extends State<PreventiveHealthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedDependentId;

  static const _accent = Color(0xFF0F766E);

  /// Calendario Nacional de Inmunización (Minsal), hitos hasta los 18 meses.
  static const List<_VaccineMilestone> _calendar = [
    _VaccineMilestone(0, 'Recién nacido', ['BCG (tuberculosis)', 'Hepatitis B']),
    _VaccineMilestone(2, '2 meses', [
      'Hexavalente (DTPa + Hib + HepB + Polio)',
      'Neumocócica conjugada',
    ]),
    _VaccineMilestone(4, '4 meses', [
      'Hexavalente (2ª dosis)',
      'Neumocócica conjugada (2ª dosis)',
    ]),
    _VaccineMilestone(6, '6 meses', ['Hexavalente (3ª dosis)']),
    _VaccineMilestone(12, '12 meses', [
      'Tres vírica (sarampión, rubéola, paperas)',
      'Neumocócica conjugada (refuerzo)',
      'Meningocócica conjugada',
    ]),
    _VaccineMilestone(18, '18 meses', [
      'Hexavalente (refuerzo)',
      'Hepatitis A',
    ]),
  ];

  static const List<_AdultCheckup> _checkups = [
    _AdultCheckup(
      fromAge: 30,
      toAge: 39,
      title: 'Chequeo preventivo inicial',
      description:
          'Perfil lipídico, glicemia en ayunas, hemograma completo y una '
          'evaluación médica general de base.',
      serviceId: 'laboratorio',
    ),
    _AdultCheckup(
      fromAge: 40,
      toAge: 49,
      title: 'Control cardiovascular y metabólico',
      description:
          'Electrocardiograma de reposo, control de presión arterial y '
          'perfiles hepático y renal.',
      serviceId: 'electrocardiograma',
    ),
    _AdultCheckup(
      fromAge: 50,
      title: 'Chequeo oncológico y digestivo',
      description:
          'Según indicación médica: antígeno prostático, mamografía y '
          'Papanicolau, y test de sangre oculta en deposiciones.',
      serviceId: 'laboratorio',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final children = _children;
    if (children.isNotEmpty) {
      _selectedDependentId = children.first.id;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Dependientes en edad pediátrica registrados en la cuenta.
  List<Dependent> get _children =>
      widget.state.dependents.where((d) => d.age < 18).toList();

  Dependent? get _selectedChild {
    final children = _children;
    if (children.isEmpty) return null;

    return children.firstWhere(
      (d) => d.id == _selectedDependentId,
      orElse: () => children.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Salud preventiva',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          tabs: const [
            Tab(text: 'Vacunación infantil'),
            Tab(text: 'Chequeos por edad'),
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

  // ------------------------------------------------------------- pediatría

  Widget _buildPediatricTab(bool isDark) {
    final child = _selectedChild;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(
          icon: Icons.child_care_rounded,
          title: 'Calendario Nacional de Inmunización',
          subtitle: child == null
              ? 'Agrega a tus hijos como dependientes para ver qué les corresponde.'
              : 'Según la edad de ${child.name}: ${_ageLabel(child.age)}.',
        ),
        const SizedBox(height: 12),
        if (_children.length > 1) ...[
          _buildChildSelector(isDark),
          const SizedBox(height: 12),
        ],
        _buildRecordDisclaimer(isDark),
        const SizedBox(height: 16),
        if (child == null)
          _buildEmptyState(
            isDark,
            'No hay niños registrados',
            'Registra a tus hijos en Mi Cuenta › Grupo familiar y aquí verás '
                'qué vacunas les corresponden según su edad.',
          )
        else
          ..._calendar.map((m) => _buildMilestoneCard(m, child, isDark)),
      ],
    );
  }

  Widget _buildChildSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedChild?.id,
          items: _children
              .map((d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      '${d.name} · ${_ageLabel(d.age)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedDependentId = value),
        ),
      ),
    );
  }

  /// Lo más importante de la pantalla: qué sabe Aura y qué no.
  Widget _buildRecordDisclaimer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.2)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aura no tiene el registro de vacunas de tu hijo: esto es el '
              'calendario oficial según su edad, no un comprobante de lo que '
              'ya recibió. Confirma las dosis puestas con su carné o su centro '
              'de salud.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(
    _VaccineMilestone milestone,
    Dependent child,
    bool isDark,
  ) {
    // `Dependent` guarda la edad en años, así que la resolución de este
    // calendario es anual: para un lactante todos los hitos del primer año
    // caen juntos. Registrar la fecha de nacimiento afinaría esto.
    final ageMonths = child.age * 12;

    // "Corresponde ahora" es el último hito cuya edad ya se cumplió.
    final isDue = milestone.months == _currentMilestone(ageMonths).months;
    final isPast = milestone.months <= ageMonths && !isDue;
    final isUpcoming = milestone.months > ageMonths;

    final (label, color) = isDue
        ? ('Corresponde ahora', _accent)
        : isPast
            ? ('Ya correspondió', Colors.grey)
            : ('Más adelante', Colors.blueGrey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDue ? _accent : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          width: isDue ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                milestone.label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...milestone.vaccines.map(
            (v) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isUpcoming
                        ? Icons.schedule_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      v,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Último hito ya cumplido por edad: el que hay que tener al día hoy.
  _VaccineMilestone _currentMilestone(int ageMonths) {
    return _calendar.lastWhere(
      (m) => m.months <= ageMonths,
      orElse: () => _calendar.first,
    );
  }

  // ---------------------------------------------------------------- adultos

  Widget _buildAdultTab(bool isDark) {
    final age = widget.state.userAge;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(
          icon: Icons.favorite_rounded,
          title: 'Chequeos preventivos por edad',
          subtitle: age == null
              ? 'Indícanos tu edad para señalarte cuál te corresponde.'
              : 'Tienes $age años: destacamos el control que te corresponde.',
        ),
        const SizedBox(height: 12),
        _buildAgeSelector(isDark, age),
        const SizedBox(height: 16),
        ..._checkups.map((c) => _buildCheckupCard(c, age, isDark)),
        const SizedBox(height: 12),
        Text(
          'Estas son recomendaciones generales por rango etario. Tu médico '
          'puede indicarte otros exámenes según tus antecedentes.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAgeSelector(bool isDark, int? age) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.cake_outlined, size: 18, color: _accent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Mi edad', style: TextStyle(fontSize: 13)),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: age,
              hint: const Text('Elegir', style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin indicar', style: TextStyle(fontSize: 13)),
                ),
                ...List.generate(
                  85,
                  (i) => DropdownMenuItem<int?>(
                    value: i + 18,
                    child: Text('${i + 18}', style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
              onChanged: (value) async {
                await widget.state.setUserAge(value);
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckupCard(_AdultCheckup checkup, int? age, bool isDark) {
    final applies = age != null && checkup.covers(age);
    final overdue = age != null && checkup.toAge != null && age > checkup.toAge!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: applies ? _accent : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          width: applies ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                checkup.bracket,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ),
              if (applies)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Te corresponde',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _accent,
                    ),
                  ),
                )
              else if (overdue)
                Text(
                  'Rango ya cumplido',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            checkup.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            checkup.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          if (applies) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _requestService(checkup.serviceId),
                icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                label: const Text('Solicitar este control'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Lleva al formulario del servicio recomendado. Si el catálogo no lo tiene
  /// cargado, no se navega a ninguna parte en vez de abrir una pantalla vacía.
  void _requestService(String serviceId) {
    final match = widget.state.services.where((s) => s.id == serviceId);
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese servicio no está disponible en este momento.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    widget.state.selectService(match.first);
    Navigator.pop(context);
  }

  // ----------------------------------------------------------------- común

  Widget _buildHeaderCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _accent, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.vaccines_outlined,
              size: 36, color: _accent.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _ageLabel(int years) {
    if (years <= 0) return 'menos de 1 año';
    return years == 1 ? '1 año' : '$years años';
  }
}
