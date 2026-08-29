import 'package:flutter/material.dart';

import '../models/dependent.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// D.2 — salud preventiva:
/// - Qué vacunas le tocan a cada hijo según su edad real.
/// - Qué chequeo le toca a la persona adulta según la suya.
///
/// Una advertencia que gobierna toda esta pantalla: **Aura no tiene el registro
/// de vacunas de nadie**. Puede decir qué corresponde a una edad, nunca qué se
/// administró. Marcar una dosis como «puesta» sin haberla registrado sería
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

  String get bracket =>
      toAge == null ? 'Desde los $fromAge años' : 'De $fromAge a $toAge años';

  bool covers(int age) {
    if (age < fromAge) return false;

    // Copia local: Dart no promueve un campo público `int?` a `int` tras el
    // chequeo de null, así que `age <= toAge` no compila escrito en línea.
    final upper = toAge;

    return upper == null || age <= upper;
  }
}

/// En qué punto del calendario cae un hito respecto de la edad de quien mira.
enum _Timing { due, past, upcoming }

class _PreventiveHealthScreenState extends State<PreventiveHealthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedDependentId;

  /// Calendario Nacional de Inmunización (Minsal Chile).
  static const List<_VaccineMilestone> _calendar = [
    _VaccineMilestone(0, 'Recién nacido', ['BCG (tuberculosis)', 'Hepatitis B']),
    _VaccineMilestone(2, '2 meses', [
      'Hexavalente (1ª dosis: DTPa + Hib + HepB + Polio)',
      'Neumocócica conjugada (1ª dosis)',
    ]),
    _VaccineMilestone(4, '4 meses', [
      'Hexavalente (2ª dosis)',
      'Neumocócica conjugada (2ª dosis)',
    ]),
    _VaccineMilestone(6, '6 meses', ['Hexavalente (3ª dosis)']),
    _VaccineMilestone(12, '12 meses', [
      'Tres vírica (1ª dosis: sarampión, rubéola, paperas)',
      'Neumocócica conjugada (refuerzo)',
      'Meningocócica conjugada',
    ]),
    _VaccineMilestone(18, '18 meses', [
      'Hexavalente (1er refuerzo)',
      'Hepatitis A',
      'Fiebre Amarilla (Isla de Pascua)',
    ]),
    _VaccineMilestone(36, '3 años', [
      'Tres vírica (2ª dosis)',
    ]),
    _VaccineMilestone(60, '5 años (1º básico)', [
      'DTP acelular (dTpa)',
    ]),
    _VaccineMilestone(108, '9 años (4º básico)', [
      'VPH (1ª dosis: Virus Papiloma Humano)',
    ]),
    _VaccineMilestone(156, '13 años (8º básico)', [
      'dTpa (refuerzo tétanos, difteria, tos convulsiva)',
    ]),
  ];

  static const List<_AdultCheckup> _checkups = [
    _AdultCheckup(
      fromAge: 30,
      toAge: 39,
      title: 'Tu primer chequeo general',
      description:
          'Un análisis de sangre completo —colesterol, azúcar y hemograma— y '
          'una consulta médica para revisarlo contigo.',
      serviceId: 'laboratorio',
    ),
    _AdultCheckup(
      fromAge: 40,
      toAge: 49,
      title: 'Control del corazón y del azúcar',
      description:
          'Electrocardiograma en reposo, control de la presión, revisión de '
          'cómo trabajan tus riñones y, si tienes diabetes, fondo de ojo.',
      serviceId: 'electrocardiograma',
    ),
    _AdultCheckup(
      fromAge: 50,
      title: 'Control completo desde los 50',
      description:
          'Una revisión general, riesgo de caídas, densidad de los huesos y un '
          'repaso de todos los medicamentos que tomas.',
      serviceId: 'medico',
    ),
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

  /// Dependientes en edad pediátrica registrados en la cuenta.
  List<Dependent> get _children =>
      widget.state.dependents.where((d) => d.age <= 18).toList();

  Dependent? get _selectedChild {
    final list = _children;
    if (list.isEmpty) return null;
    if (_selectedDependentId == null) return list.first;
    return list.firstWhere(
      (d) => d.id == _selectedDependentId,
      orElse: () => list.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: const Text('Salud preventiva'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: p.accent,
          labelColor: p.accent,
          unselectedLabelColor: p.textMuted,
          labelStyle: AppType.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppType.bodyMedium,
          tabs: const [
            Tab(text: 'Vacunas'),
            Tab(text: 'Chequeos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _childrenTab(context),
          _adultTab(context),
        ],
      ),
    );
  }

  static const _listPadding = EdgeInsets.fromLTRB(
    AuraSpace.screenX,
    AuraSpace.md,
    AuraSpace.screenX,
    AuraSpace.xxl,
  );

  // --------------------------------------------------------------- infantil

  Widget _childrenTab(BuildContext context) {
    final children = _children;
    final child = _selectedChild;

    return ListView(
      padding: _listPadding,
      children: [
        AuraReadable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lo más importante de la pantalla: qué sabe Aura y qué no.
              const AuraBanner(
                tone: AuraTone.warning,
                title: 'Aura no sabe qué vacunas ya le pusieron',
                message:
                    'Esto es el calendario del Ministerio de Salud según su '
                    'edad, no un comprobante de lo que ya recibió. Comprueba '
                    'las dosis puestas en su carné o en su centro de salud.',
              ),
              const SizedBox(height: AuraSpace.xl),

              if (child == null)
                _noChildrenState()
              else ...[
                if (children.length > 1) ...[
                  const AuraSectionHeader(title: '¿De quién quieres verlo?'),
                  for (final d in children) ...[
                    AuraChoiceTile(
                      title: d.name,
                      subtitle: _dependentAgeLabel(d),
                      icon: Icons.child_care_rounded,
                      selected: d.id == child.id,
                      onTap: () =>
                          setState(() => _selectedDependentId = d.id),
                    ),
                    const SizedBox(height: AuraTap.gap),
                  ],
                  const SizedBox(height: AuraSpace.lg),
                ],

                AuraSectionHeader(title: 'Calendario de ${child.name}'),

                if (_currentMilestone(child.calculatedAgeMonths) == null) ...[
                  AuraBanner(
                    tone: AuraTone.info,
                    icon: Icons.done_all_rounded,
                    message:
                        '${child.name} ya pasó todas las edades de este '
                        'calendario. Las vacunas que vienen después se ponen '
                        'en el consultorio o en el vacunatorio.',
                  ),
                  const SizedBox(height: AuraSpace.md),
                ],

                for (final milestone in _calendar) ...[
                  _milestoneCard(context, milestone, child),
                  const SizedBox(height: AuraSpace.sm),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Dos vacíos distintos con causas distintas: no haber añadido a nadie, o
  /// tener familiares guardados pero ninguno en edad de este calendario. El
  /// mensaje anterior («No hay niños registrados») era falso en el segundo caso
  /// y dejaba a la persona buscando un formulario que ya había rellenado.
  Widget _noChildrenState() {
    final hasFamily = widget.state.dependents.isNotEmpty;

    return AuraEmptyState(
      icon: Icons.family_restroom_rounded,
      title: hasFamily
          ? 'Ninguno de tus familiares es menor de edad'
          : 'Todavía no has añadido a tu familia',
      message: hasFamily
          ? 'Este calendario es para menores de 18 años. Si falta alguien, '
              'añádelo en Mi cuenta › Familiares.'
          : 'Añade a tus hijos en Mi cuenta › Familiares y aquí verás qué '
              'vacunas les tocan según su edad.',
    );
  }

  Widget _milestoneCard(
    BuildContext context,
    _VaccineMilestone milestone,
    Dependent child,
  ) {
    final p = context.palette;

    // Edad precisa en meses, desde birth_date o age_months.
    final ageMonths = child.calculatedAgeMonths;
    final current = _currentMilestone(ageMonths);

    final isDue = current != null && milestone.months == current.months;
    final isPast = current == null
        ? milestone.months <= ageMonths
        : milestone.months < current.months;

    final timing = isDue
        ? _Timing.due
        : isPast
            ? _Timing.past
            : _Timing.upcoming;

    final (String label, AuraTone tone, IconData icon) = switch (timing) {
      _Timing.due => ('Le toca ahora', AuraTone.warning, Icons.event_available_rounded),
      _Timing.past => ('Ya le tocó', AuraTone.neutral, Icons.history_rounded),
      _Timing.upcoming => ('Más adelante', AuraTone.info, Icons.schedule_rounded),
    };

    final c = auraToneColors(context, tone);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  milestone.label,
                  style: AppType.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              AuraBadge(label: label, tone: tone, icon: icon),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          for (final vaccine in milestone.vaccines)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cada vacuna llevaba antes un `radio_button_unchecked`: el
                  // dibujo de una casilla por marcar. Aura no tiene el registro
                  // de dosis de nadie, así que ese icono ofrecía justo lo que
                  // el aviso de arriba acaba de advertir que no puede hacer.
                  Icon(icon, size: AuraIcon.sm, color: c.fg),
                  const SizedBox(width: AuraSpace.xs),
                  Expanded(
                    child: Text(
                      vaccine,
                      style: AppType.bodySmall.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Hito activo que corresponde actualmente según la edad precisa.
  /// Si el dependiente superó la edad del último hito por más de 12 meses, se
  /// considera que completó el calendario de hitos infantiles y retorna null.
  _VaccineMilestone? _currentMilestone(int ageMonths) {
    if (ageMonths > _calendar.last.months + 12) {
      return null;
    }
    if (ageMonths < _calendar.first.months) {
      return _calendar.first;
    }
    return _calendar.lastWhere(
      (m) => m.months <= ageMonths,
      orElse: () => _calendar.first,
    );
  }

  // ---------------------------------------------------------------- adultos

  Widget _adultTab(BuildContext context) {
    final p = context.palette;
    final age = widget.state.userAge;

    return ListView(
      padding: _listPadding,
      children: [
        AuraReadable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (age == null) ...[
                const AuraBanner(
                  tone: AuraTone.info,
                  icon: Icons.cake_outlined,
                  message:
                      'Dinos tu edad y te marcamos cuál de estos controles te '
                      'toca ahora.',
                ),
                const SizedBox(height: AuraSpace.md),
              ],
              _ageSelector(context, age),

              const SizedBox(height: AuraSpace.xl),
              const AuraSectionHeader(title: 'Controles según tu edad'),
              for (final checkup in _checkups) ...[
                _checkupCard(context, checkup, age),
                const SizedBox(height: AuraSpace.sm),
              ],

              const SizedBox(height: AuraSpace.md),
              Text(
                'Son recomendaciones generales por edad. Tu médico puede '
                'pedirte otros exámenes según lo que ya sepa de ti.',
                style: AppType.bodySmall.copyWith(color: p.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ageSelector(BuildContext context, int? age) {
    final p = context.palette;

    return AuraCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.md,
        vertical: AuraSpace.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.cake_outlined, size: AuraIcon.md, color: p.accent),
          const SizedBox(width: AuraSpace.sm),
          Expanded(
            child: Text(
              'Tu edad',
              style: AppType.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: age,
              borderRadius: AuraRadius.allSm,
              dropdownColor: p.card,
              // Son 85 edades: sin techo, el menú se abre del alto de la
              // pantalla y tapa la pregunta que lo motivó.
              menuMaxHeight: 320,
              iconEnabledColor: p.textSecondary,
              style: AppType.bodyMedium.copyWith(color: p.textPrimary),
              // Sin `hint`: la lista ya trae «Sin indicar» como opción real,
              // y con esa opción presente el `hint` nunca llegaba a pintarse.
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin indicar'),
                ),
                for (var i = 18; i <= 102; i++)
                  DropdownMenuItem<int?>(value: i, child: Text('$i años')),
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

  Widget _checkupCard(
    BuildContext context,
    _AdultCheckup checkup,
    int? age,
  ) {
    final p = context.palette;
    final applies = age != null && checkup.covers(age);
    final overdue = age != null && checkup.toAge != null && age > checkup.toAge!;
    final upcoming = age != null && age < checkup.fromAge;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  checkup.bracket,
                  style: AppType.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              if (applies)
                const AuraBadge(
                  label: 'Te toca ahora',
                  tone: AuraTone.warning,
                  icon: Icons.event_available_rounded,
                )
              else if (overdue)
                const AuraBadge(
                  label: 'Ya lo pasaste',
                  tone: AuraTone.neutral,
                  icon: Icons.history_rounded,
                )
              else if (upcoming)
                const AuraBadge(
                  label: 'Más adelante',
                  tone: AuraTone.info,
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            checkup.title,
            style: AppType.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AuraSpace.xxs),
          Text(
            checkup.description,
            style: AppType.bodySmall.copyWith(color: p.textSecondary),
          ),
          if (applies) ...[
            const SizedBox(height: AuraSpace.md),
            AuraButton.secondary(
              label: 'Pedir este control',
              icon: Icons.arrow_forward_rounded,
              trailingIcon: true,
              size: AuraButtonSize.small,
              onPressed: () => _requestService(checkup.serviceId),
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
        SnackBar(
          content: const Text(
            'Ese servicio no está disponible ahora mismo. Inténtalo de nuevo '
            'en un rato.',
          ),
          backgroundColor: context.palette.error,
        ),
      );
      return;
    }

    widget.state.selectService(match.first);
    Navigator.pop(context);
  }

  // ----------------------------------------------------------------- común

  String _dependentAgeLabel(Dependent child) {
    final months = child.calculatedAgeMonths;
    if (months < 1) return 'Recién nacido';
    if (months < 12) return '$months meses';
    final years = months ~/ 12;
    final remMonths = months % 12;
    if (years == 1) {
      return remMonths > 0 ? '1 año $remMonths m' : '1 año';
    }
    return remMonths > 0 ? '$years años $remMonths m' : '$years años';
  }
}
