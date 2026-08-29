import 'package:flutter/material.dart';

import '../models/lab_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// E.1 — selector de día y bloque para la toma de muestras.
///
/// Solo ofrece lo que el laboratorista publicó: si no hay bloques, lo dice en
/// lugar de mostrar un calendario abierto que sugiere una disponibilidad que
/// no existe.
class LabSlotPicker extends StatefulWidget {
  final AppState state;

  /// Dirección actual del formulario, usada para acotar por sector.
  final String? zone;

  /// Cupo elegido, o null mientras no haya selección.
  final ValueChanged<LabSlot?> onSlotSelected;

  const LabSlotPicker({
    super.key,
    required this.state,
    required this.onSlotSelected,
    this.zone,
  });

  @override
  State<LabSlotPicker> createState() => _LabSlotPickerState();
}

class _LabSlotPickerState extends State<LabSlotPicker> {
  AppPalette get p => context.palette;

  List<DateTime> _availableDates = [];
  List<LabSlot> _slots = [];
  DateTime? _selectedDate;
  LabSlot? _selectedSlot;
  bool _loadingDates = true;
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  @override
  void didUpdateWidget(covariant LabSlotPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La zona se resuelve de forma asíncrona a partir de la dirección, así que
    // suele llegar después del primer render. Sin esto, el selector se quedaría
    // mostrando la disponibilidad de toda la ciudad.
    if (oldWidget.zone != widget.zone) {
      _loadAvailability();
    }
  }

  Future<void> _loadAvailability() async {
    setState(() => _loadingDates = true);
    final dates = await widget.state.fetchLabAvailability(zone: widget.zone);
    if (!mounted) return;

    setState(() {
      _availableDates = dates;
      _loadingDates = false;
      _slots = const [];
      _selectedSlot = null;
    });

    if (dates.isEmpty) {
      // Al cambiar de sector puede desaparecer toda la agenda. El cupo que la
      // persona había elegido en el sector anterior seguía viajando con el
      // formulario, que se enviaba con una hora de otra comuna.
      widget.onSlotSelected(null);
      return;
    }

    _selectDate(dates.first);
  }

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _loadingSlots = true;
      _slots = const [];
      _selectedSlot = null;
    });
    widget.onSlotSelected(null);

    final slots = await widget.state.fetchLabSlots(date, zone: widget.zone);
    if (!mounted) return;

    // Dos toques seguidos en dos días distintos dejan dos peticiones en vuelo.
    // Sin esta comprobación, la que contesta última pinta sus bloques debajo
    // del día que ya no está elegido.
    final current = _selectedDate;
    if (current == null || !_sameDay(current, date)) return;

    setState(() {
      _slots = slots;
      _loadingSlots = false;
    });
  }

  void _selectSlot(LabSlot slot) {
    setState(() => _selectedSlot = slot);
    widget.onSlotSelected(slot);
  }

  // Nombres en español escritos a mano: la app no inicializa los datos de
  // locale de `intl`, así que DateFormat con 'es' reventaría en tiempo de
  // ejecución la primera vez que alguien abra este selector.
  static const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date) {
    final today = DateTime.now();
    final day = '${date.day} ${_months[date.month - 1]}';
    if (_sameDay(date, today)) return 'Hoy $day';
    if (_sameDay(date, today.add(const Duration(days: 1)))) return 'Mañana $day';

    return '${_weekdays[date.weekday - 1]} $day';
  }

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AuraSpace.md),
          if (_loadingDates)
            _loadingDays()
          else if (_availableDates.isEmpty)
            _noAgenda()
          else ...[
            // `AuraOptionGroup` en vez de la tira horizontal: aquellas
            // tarjetas eran un `GestureDetector` sobre una `Column`, así que un
            // lector de pantalla leía «Jue», «14» y «ago» como tres textos
            // sueltos, nunca como una opción que se puede elegir. De paso
            // desaparece el alto calculado a mano —`64 * escala del texto`—:
            // al envolver en varias filas, el grupo crece solo.
            AuraOptionGroup<DateTime>(
              label: 'Elige el día',
              options: [
                for (final date in _availableDates)
                  (value: date, label: _dayLabel(date), icon: null),
              ],
              selected: _selectedDate,
              onSelect: _selectDate,
            ),
            const SizedBox(height: AuraSpace.md),
            _slotSection(),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.event_available_outlined,
          color: p.accent,
          size: AuraIcon.md,
        ),
        const SizedBox(width: AuraSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Agenda tu toma de muestras',
                  style: AppType.titleSmall.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.xxxs),
              Text(
                'Elige el día y el bloque que te acomoden.',
                style: AppType.bodySmall.copyWith(color: p.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _slotSection() {
    if (_loadingSlots) {
      return Semantics(
        liveRegion: true,
        label: 'Cargando los bloques del día',
        child: ExcludeSemantics(
          child: AuraSkeleton.list(count: 3, height: AuraTap.large),
        ),
      );
    }

    final date = _selectedDate;
    if (_slots.isEmpty) {
      return AuraBanner(
        tone: AuraTone.info,
        icon: Icons.event_busy_rounded,
        message: 'No quedan bloques libres ese día, o no pudimos consultarlos. '
            'Prueba con otra fecha o vuelve a intentarlo.',
        actionLabel: date == null ? null : 'Reintentar',
        onAction: date == null ? null : () => _selectDate(date),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige el bloque',
          style: AppType.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: p.textSecondary,
          ),
        ),
        const SizedBox(height: AuraSpace.xs),
        // El chip anterior marcaba el bloque elegido solo con el color de
        // fondo. `AuraChoiceTile` añade el borde grueso y la marca de
        // verificación, que es lo que hace visible la elección para quien no
        // separa el verde del gris.
        for (final slot in _slots)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraTap.gap),
            child: AuraChoiceTile(
              title: slot.label,
              subtitle: slot.professionalName,
              icon: Icons.schedule_rounded,
              selected: _selectedSlot?.scheduleId == slot.scheduleId &&
                  _selectedSlot?.startsAt == slot.startsAt,
              trailingText: slot.remaining <= 3
                  ? (slot.remaining == 1
                      ? 'Queda 1 cupo'
                      : 'Quedan ${slot.remaining} cupos')
                  : null,
              onTap: () => _selectSlot(slot),
            ),
          ),
      ],
    );
  }

  Widget _loadingDays() {
    return Semantics(
      liveRegion: true,
      label: 'Buscando la disponibilidad del laboratorio',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: AuraTap.gap,
          runSpacing: AuraTap.gap,
          children: const [
            AuraSkeleton(
              height: AuraTap.min,
              width: 112,
              radius: AuraRadius.allSm,
            ),
            AuraSkeleton(
              height: AuraTap.min,
              width: 128,
              radius: AuraRadius.allSm,
            ),
            AuraSkeleton(
              height: AuraTap.min,
              width: 104,
              radius: AuraRadius.allSm,
            ),
          ],
        ),
      ),
    );
  }

  /// Sin agenda publicada.
  ///
  /// `fetchLabAvailability` devuelve la lista vacía en dos casos que desde aquí
  /// no se distinguen: que el laboratorio no haya publicado horarios y que la
  /// consulta al servidor haya fallado. Por eso el texto nombra las dos
  /// posibilidades y siempre deja el reintento a mano, en vez de afirmar que no
  /// hay horas cuando lo que hubo fue un corte de red.
  ///
  /// El «Reintentar» de antes llevaba `minimumSize: Size.zero` y
  /// `shrinkWrap`: 21 px de alto, el control más pequeño de la pantalla y a la
  /// vez el único que permitía salir de este estado.
  Widget _noAgenda() {
    return AuraEmptyState(
      compact: true,
      icon: Icons.event_busy_rounded,
      title: 'Todavía no hay horas publicadas',
      message: 'Puede que el laboratorio aún no haya publicado su agenda para '
          'tu sector, o que no hayamos podido consultarla. Inténtalo de nuevo '
          'en un momento.',
      actionLabel: 'Reintentar',
      onAction: _loadAvailability,
    );
  }
}
