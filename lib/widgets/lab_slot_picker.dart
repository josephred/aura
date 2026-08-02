import 'package:flutter/material.dart';

import '../models/lab_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

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
    });

    if (dates.isNotEmpty) {
      _selectDate(dates.first);
    }
  }

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _loadingSlots = true;
      _slots = [];
      _selectedSlot = null;
    });
    widget.onSlotSelected(null);

    final slots = await widget.state.fetchLabSlots(date, zone: widget.zone);
    if (!mounted) return;

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
    if (_sameDay(date, today)) return 'Hoy';
    if (_sameDay(date, today.add(const Duration(days: 1)))) return 'Mañana';

    return _weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined, color: p.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agenda tu toma de muestras',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      'Elige el día y el bloque horario que te acomode',
                      style: TextStyle(fontSize: 10, color: p.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingDates)
            _buildLoading('Buscando disponibilidad…')
          else if (_availableDates.isEmpty)
            _buildEmpty()
          else ...[
            _buildDateStrip(),
            const SizedBox(height: 14),
            if (_loadingSlots)
              _buildLoading('Cargando bloques…')
            else if (_slots.isEmpty)
              Text(
                'No quedan bloques libres ese día. Prueba con otra fecha.',
                style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.5),
              )
            else
              _buildSlotGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading(String message) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
        ),
        const SizedBox(width: 10),
        Text(message, style: TextStyle(fontSize: 11, color: p.textMuted)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Por ahora no hay horarios publicados para toma de muestras. '
              'Vuelve a intentarlo más tarde o comunícate con nosotros para coordinar.',
              style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
            ),
          ),
          TextButton(
            onPressed: _loadAvailability,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Reintentar', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _availableDates.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final selected = _selectedDate != null && _sameDay(_selectedDate!, date);

          return GestureDetector(
            onTap: () => _selectDate(date),
            child: Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? p.accent : p.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? p.accent : p.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayLabel(date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : p.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : p.textPrimary,
                    ),
                  ),
                  Text(
                    _months[date.month - 1],
                    style: TextStyle(
                      fontSize: 9,
                      color: selected ? Colors.white70 : p.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _slots.map((slot) {
        final selected = _selectedSlot?.scheduleId == slot.scheduleId &&
            _selectedSlot?.startsAt == slot.startsAt;

        return GestureDetector(
          onTap: () => _selectSlot(slot),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? p.accent : p.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? p.accent : p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : p.textPrimary,
                  ),
                ),
                Text(
                  slot.professionalName,
                  style: TextStyle(
                    fontSize: 9,
                    color: selected ? Colors.white70 : p.textFaint,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
