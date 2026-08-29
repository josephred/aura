import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../utils/money.dart';
import 'book_appointment_screen.dart';
import 'video_call_screen.dart';

const _kDaysEs = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _kMonthsEs = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String formatAppointmentDate(DateTime dt) {
  final day = _kDaysEs[dt.weekday - 1];
  final month = _kMonthsEs[dt.month - 1];
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day ${dt.day} $month · $hour:$minute';
}

/// Se mantiene el nombre porque lo importan otras pantallas, pero el formato
/// vive ahora en [Money]: había tres implementaciones distintas del mismo
/// importe y dos de ellas lo etiquetaban en la moneda equivocada.
String formatClp(int amount) => Money.format(amount);

/// Agenda de citas.
///
/// ## Qué se arregló
///
/// - **Un fallo de red ya no se lee como «no tienes citas».** `_refresh` ponía
///   `_loading = false` pasara lo que pasara, así que una caída de la conexión
///   pintaba el mismo vacío amable que una agenda realmente vacía. Ahora el
///   error tiene su propio estado, con reintento, y si hay citas en memoria se
///   avisa de que la lista puede estar desactualizada en vez de esconderlas.
/// - **El diálogo de cancelar se entiende.** Se titulaba «Cancelar cita» y sus
///   dos botones eran «Cancelar cita» y «Volver»: en ese diálogo, «cancelar»
///   quería decir dos cosas opuestas.
/// - **Cancelar solo aparece cuando se puede.** `canCancel` era
///   `appointment.isUpcoming` a secas.
/// - **Las acciones tienen pesos distintos.** Eran cuatro botones del mismo
///   tamaño y ninguno mandaba.
/// - **Las esperas de red se ven.** Unirse a la videoconsulta y verificar el
///   pago hacen una petición; la tarjeta ahora marca cuál está ocupada.
class AppointmentsScreen extends StatefulWidget {
  final AppState state;

  const AppointmentsScreen({super.key, required this.state});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  AppPalette get p => context.palette;
  bool _loading = true;

  /// Qué falló al cargar. Distingue «no pudimos traer la agenda» de «la agenda
  /// está vacía», que antes se dibujaban igual.
  String? _error;

  /// Id de la cita que tiene una petición en curso. Es por tarjeta y no global
  /// porque la lista sigue siendo usable mientras una de ellas trabaja.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChange);
    _refresh();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    try {
      await widget.state.fetchAppointments();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      // `fetchAppointments` hoy se traga sus propios fallos y devuelve void;
      // esto recoge lo que se le escape (y lo que empiece a propagar cuando
      // deje de tragárselos) para no volver a dibujar un vacío inventado.
      debugPrint('AppointmentsScreen._refresh failed. Error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos cargar tus citas.';
      });
    }
  }

  Future<void> _book() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(state: widget.state),
      ),
    );
    await _refresh();
  }

  void _notify(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? p.error : null,
      ),
    );
  }

  Future<void> _cancel(Appointment appointment) async {
    // El título pregunta y cada botón dice qué hace. Antes el diálogo se
    // titulaba «Cancelar cita», el botón que cancelaba decía «Cancelar cita» y
    // el que no hacía nada decía «Volver»: la misma palabra para la acción y
    // para desistir de ella.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar esta cita?'),
        content: Text(
          'Se cancela la cita con '
          '${appointment.professionalName ?? 'el profesional'} del '
          '${formatAppointmentDate(appointment.scheduledAt)}. '
          'Si la vuelves a necesitar, tendrás que agendarla otra vez.',
        ),
        actions: [
          AuraButton.tertiary(
            label: 'No, mantenerla',
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          const SizedBox(width: AuraSpace.xs),
          AuraButton.danger(
            label: 'Sí, cancelar la cita',
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = appointment.id);
    final error = await widget.state.cancelAppointment(appointment.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    _notify(error ?? 'Cita cancelada.', isError: error != null);
  }

  Future<void> _joinVideo(Appointment appointment) async {
    setState(() => _busyId = appointment.id);
    final (iceServers, error) =
        await widget.state.fetchVideoJoinConfig(appointment.id);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (iceServers == null) {
      _notify(error ?? 'No se pudo abrir la videoconsulta.', isError: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          state: widget.state,
          appointment: appointment,
          iceServers: iceServers,
        ),
      ),
    );
  }

  Future<void> _verifyPayment(Appointment appointment) async {
    setState(() => _busyId = appointment.id);
    final approved =
        await widget.state.verifyAppointmentPayment(appointment.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    _notify(
      approved
          ? 'Pago confirmado. Tu cita quedó agendada.'
          : 'Aún no vemos el pago. Si ya pagaste, espera un momento y reintenta.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // Orden explícito. `upcoming` salía de invertir el orden en que llegaron
    // del servidor, que no es ningún orden: la próxima cita podía quedar
    // tercera. Las próximas van de la más cercana a la más lejana; las
    // anteriores, de la más reciente hacia atrás.
    final upcoming = widget.state.appointments.where((a) => a.isUpcoming).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final past = widget.state.appointments.where((a) => !a.isUpcoming).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    final isEmpty = upcoming.isEmpty && past.isEmpty;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Mis citas')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: p.accent,
        foregroundColor: context.scheme.onPrimary,
        icon: const Icon(Icons.calendar_month_rounded),
        label: const Text('Agendar cita'),
        onPressed: _book,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.fromLTRB(
                AuraSpace.screenX,
                AuraSpace.md,
                AuraSpace.screenX,
                0,
              ),
              child: AuraReadable(child: _LoadingList()),
            )
          : RefreshIndicator(
              color: p.accent,
              onRefresh: _refresh,
              child: ListView(
                // Sin esto, tirar para refrescar no funciona justo cuando más
                // falta hace: con el estado de error o el vacío en pantalla la
                // lista no desborda y no acepta el gesto.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.screenX,
                  AuraSpace.xs,
                  AuraSpace.screenX,
                  AuraSpace.navClearance,
                ),
                children: [
                  AuraReadable(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Falló la carga y no hay nada que enseñar: esto es un
                        // error, no una agenda vacía.
                        if (_error != null && isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AuraSpace.xxl),
                            child: AuraErrorState(
                              title: 'No pudimos cargar tus citas',
                              message:
                                  'Revisa tu conexión e inténtalo de nuevo. '
                                  'Tus citas siguen agendadas.',
                              onRetry: _refresh,
                            ),
                          )
                        // Falló la carga pero hay citas guardadas: se muestran,
                        // avisando de que pueden no estar al día. Esconder
                        // datos que sí tenemos es peor que mostrarlos con una
                        // advertencia.
                        else if (_error != null) ...[
                          const SizedBox(height: AuraSpace.xs),
                          AuraBanner(
                            tone: AuraTone.warning,
                            title: 'Lista sin actualizar',
                            message:
                                'No pudimos contactar con el servidor, así que '
                                'esto es lo último que teníamos guardado.',
                            actionLabel: 'Reintentar',
                            onAction: _refresh,
                          ),
                        ],

                        if (_error == null && isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AuraSpace.xxl),
                            child: AuraEmptyState(
                              icon: Icons.event_available_rounded,
                              title: 'Aún no tienes citas',
                              message:
                                  'Aquí aparecerán tus consultas con fecha y '
                                  'hora, presenciales o por videollamada.',
                              actionLabel: 'Agendar una cita',
                              onAction: _book,
                            ),
                          ),

                        if (upcoming.isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.md),
                          const AuraSectionHeader(title: 'Próximas'),
                          for (final a in upcoming) ...[
                            _buildCard(a),
                            const SizedBox(height: AuraSpace.sm),
                          ],
                        ],
                        if (past.isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.md),
                          const AuraSectionHeader(title: 'Anteriores'),
                          for (final a in past) ...[
                            _buildCard(a),
                            const SizedBox(height: AuraSpace.sm),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Estado e insignia de una cita.
  ///
  /// Los chips anteriores pintaban el color de estado con `alpha: 0.12` sobre
  /// la tarjeta: en modo oscuro ese tinte desaparecía y quedaba texto de color
  /// flotando. [AuraBadge] trae la superficie y el texto ya emparejados en las
  /// dos paletas.
  ({String label, AuraTone tone}) _statusBadge(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.confirmed => (label: 'Confirmada', tone: AuraTone.success),
      AppointmentStatus.pendingPayment => (
        label: 'Pago pendiente',
        tone: AuraTone.warning,
      ),
      AppointmentStatus.completed => (
        label: 'Completada',
        tone: AuraTone.neutral,
      ),
      AppointmentStatus.cancelled => (label: 'Cancelada', tone: AuraTone.error),
      AppointmentStatus.noShow => (label: 'No asistió', tone: AuraTone.warning),
      // Antes se dibujaba un guion. Un guion no es un estado: no dice si la
      // cita está en pie, y deja a quien usa lector de pantalla sin nada.
      AppointmentStatus.unknown => (
        label: 'Estado no disponible',
        tone: AuraTone.neutral,
      ),
    };
  }

  Widget _buildCard(Appointment appointment) {
    final badge = _statusBadge(appointment.status);
    final isPendingPayment =
        appointment.status == AppointmentStatus.pendingPayment;

    // Cancelar solo tiene sentido en una cita que sigue en pie. Antes la
    // condición era `isUpcoming` a secas, y por tanto dependía de que la
    // definición de `isUpcoming` siguiera filtrando por estado: el día que deje
    // de hacerlo, una cita ya cancelada volvería a ofrecer "Cancelar cita".
    final canCancel =
        appointment.isUpcoming &&
        (appointment.status == AppointmentStatus.confirmed ||
            appointment.status == AppointmentStatus.pendingPayment);

    final busy = _busyId == appointment.id;
    final specialty = appointment.specialty?.trim() ?? '';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  appointment.professionalName ?? 'Profesional Aura',
                  style: AppType.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              // Flexible y no fijo: con la letra al 200 %, "Estado no
              // disponible" es más ancho que la tarjeta y así se parte en dos
              // líneas en vez de desbordar sobre el nombre.
              Flexible(child: AuraBadge(label: badge.label, tone: badge.tone)),
            ],
          ),
          if (specialty.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.xxxs),
            Text(
              specialty,
              style: AppType.bodySmall.copyWith(color: p.textMuted),
            ),
          ],
          if (appointment.isVideo) ...[
            const SizedBox(height: AuraSpace.xs),
            const AuraBadge(
              label: 'Videoconsulta',
              tone: AuraTone.info,
              icon: Icons.videocam_rounded,
            ),
          ],
          const SizedBox(height: AuraSpace.sm),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: AuraIcon.sm, color: p.accent),
              const SizedBox(width: AuraSpace.xs),
              Expanded(
                child: Text(
                  formatAppointmentDate(appointment.scheduledAt),
                  style: AppType.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              Text(
                formatClp(appointment.price),
                style: AppType.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),

          // Jerarquía de acciones: la videoconsulta o el pago mandan (una sola
          // primaria, y nunca las dos a la vez: unirse exige la cita
          // confirmada). «Ya pagué» y «Cancelar» bajan a texto.
          if (appointment.canJoinVideo) ...[
            const SizedBox(height: AuraSpace.md),
            AuraButton(
              label: 'Unirse a la videoconsulta',
              icon: Icons.videocam_rounded,
              loading: busy,
              onPressed: busy ? null : () => _joinVideo(appointment),
            ),
          ],
          if (isPendingPayment) ...[
            const SizedBox(height: AuraSpace.md),
            AuraButton(
              label: 'Pagar',
              icon: Icons.account_balance_wallet_rounded,
              onPressed: appointment.paymentUrl == null || busy
                  ? null
                  : () =>
                      widget.state.openCheckoutUrl(appointment.paymentUrl!),
            ),
            if (appointment.paymentUrl == null) ...[
              const SizedBox(height: AuraSpace.xs),
              // Un botón inhabilitado sin explicación es un callejón: se dice
              // por qué no se puede pagar todavía.
              Text(
                'El enlace de pago todavía no está disponible. Desliza hacia '
                'abajo para actualizar.',
                style: AppType.bodySmall.copyWith(color: p.textMuted),
              ),
            ],
            const SizedBox(height: AuraTap.gap),
            AuraButton(
              label: 'Ya pagué',
              kind: AuraButtonKind.tertiary,
              size: AuraButtonSize.small,
              loading: busy,
              expand: true,
              onPressed: busy ? null : () => _verifyPayment(appointment),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: AuraSpace.xs),
            Align(
              alignment: Alignment.centerRight,
              child: AuraButton(
                label: 'Cancelar cita',
                // Entrada discreta, confirmación contundente: el rojo vive en
                // el botón del diálogo, que es donde la acción es irreversible.
                kind: AuraButtonKind.tertiary,
                size: AuraButtonSize.small,
                expand: false,
                onPressed: busy ? null : () => _cancel(appointment),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Siluetas mientras llega la agenda: conservan la forma de la lista, así que
/// la pantalla no salta cuando entran los datos.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AuraSpace.md),
        AuraSkeleton.list(count: 3, height: 128),
      ],
    );
  }
}
