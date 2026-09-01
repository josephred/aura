import 'package:flutter/material.dart';

import '../models/lab_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../utils/money.dart';

/// E.4 — «Mis exámenes»: tomas de muestra agendadas e informes descargables.
///
/// Reúne las dos mitades del flujo de laboratorio en una sola pantalla, porque
/// desde el punto de vista del paciente son lo mismo: lo que viene y lo que ya
/// tiene resultado.
///
/// ## Qué se arregló
///
/// - **Un fallo de red ya no se lee como «no tienes nada».** `_load` daba la
///   carga por buena pasara lo que pasara, así que una caída de la conexión
///   pintaba las dos tarjetas de vacío diciendo que no había ni tomas ni
///   informes. Ahora el fallo tiene su propio estado, con reintento.
/// - **El pago pasa por [AppState].** `_pay` llamaba a `launchUrl` por su
///   cuenta y se saltaba el único sitio donde vive el manejo del checkout.
/// - **El precio se lee.** El botón decía `Pagar $19500`, sin separador de
///   miles: un número de cinco cifras seguidas se cuenta con el dedo.
/// - **Las tres acciones tenían el mismo peso.** Pagar manda; comprobar el pago
///   y cancelar bajan a texto.
/// - **«Ya pagué» dice en qué quedó y deja reintentar**, en la tarjeta y no en
///   un aviso que se va solo a los pocos segundos, que es justo cuando hace
///   falta volver a comprobarlo.
/// - **La insignia de estado y las indicaciones se ven en oscuro.** Estaban
///   escritas con un ámbar claro fijo sobre texto ámbar oscuro.
class LabResultsScreen extends StatefulWidget {
  final AppState state;

  const LabResultsScreen({super.key, required this.state});

  @override
  State<LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<LabResultsScreen> {
  AppPalette get p => context.palette;

  bool _loading = true;

  /// Qué falló al cargar. Distingue «no pudimos traer tus exámenes» de «no
  /// tienes ninguno», que antes se dibujaban exactamente igual.
  String? _error;

  /// Informe que se está abriendo.
  String? _openingId;

  /// Toma que tiene una petición en curso. Es por tarjeta y no global porque el
  /// resto de la lista sigue siendo usable mientras una de ellas trabaja.
  String? _busyId;

  /// En qué quedó la última comprobación de pago, y de qué toma.
  ///
  /// Vive en la tarjeta y no en un `SnackBar`: cuando el pago todavía no
  /// aparece, lo que hace falta es un sitio donde volver a intentarlo, y el
  /// aviso flotante desaparecía solo antes de que diera tiempo a nada.
  ({String requestId, String message, AuraTone tone})? _paymentNotice;

  @override
  void initState() {
    super.initState();
    if (widget.state.labResults.isNotEmpty || widget.state.labRequests.isNotEmpty) {
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        widget.state.fetchLabRequests(),
        widget.state.fetchLabResults(),
      ]);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      // Los dos `fetch` hoy se tragan sus propios fallos y devuelven void; esto
      // recoge lo que se les escape (y lo que empiecen a propagar cuando dejen
      // de tragárselos) para no volver a inventar un vacío.
      debugPrint('LabResultsScreen._load failed. Error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos cargar tus exámenes.';
      });
    }
  }

  void _notify(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? p.error : null,
      ),
    );
  }

  /// Esta pantalla se abre encima del contenedor de pestañas, así que cambiar
  /// de pestaña no se ve hasta cerrarla.
  void _goToServices() {
    widget.state.setTab('home');
    Navigator.pop(context);
  }

  Future<void> _open(LabResult result) async {
    setState(() => _openingId = result.id);
    final opened = await widget.state.openLabResult(result);
    if (!mounted) return;
    setState(() => _openingId = null);

    if (!opened) {
      _notify(
        'No pudimos abrir el informe. Revisa tu conexión e inténtalo de nuevo.',
        isError: true,
      );
    }
  }

  Future<void> _pay(LabRequest request) async {
    final url = request.paymentUrl;
    if (url == null || url.isEmpty) return;

    // Pasa por AppState y no por `launchUrl` directo: ahí es donde vive el
    // manejo del checkout y lo que deja rastro si la pasarela no abre.
    await widget.state.openCheckoutUrl(url);
  }

  Future<void> _verifyPayment(LabRequest request) async {
    setState(() {
      _busyId = request.id;
      _paymentNotice = null;
    });
    final confirmed = await widget.state.verifyLabPayment(request.id);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      _paymentNotice = confirmed
          ? (
              requestId: request.id,
              message: 'Pago confirmado. Tu toma de muestras quedó agendada.',
              tone: AuraTone.success,
            )
          : (
              requestId: request.id,
              message:
                  'Todavía no vemos el pago. Si acabas de pagarlo, espera un '
                  'momento y vuelve a comprobarlo.',
              tone: AuraTone.warning,
            );
    });
  }

  Future<void> _cancel(LabRequest request) async {
    // Los botones eran «Mantener» y «Cancelar toma». En un diálogo que pregunta
    // si cancelar, «Cancelar» se lee igual de bien como «sí» que como «no»:
    // ahora cada botón dice qué pasa al tocarlo.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar esta toma de muestras?'),
        content: Text(
          'Se cancela la toma agendada para '
          '${request.scheduledLabel ?? 'la fecha que elegiste'}. '
          'El horario queda libre para otro paciente y, si la vuelves a '
          'necesitar, tendrás que agendarla otra vez.',
        ),
        actions: [
          AuraButton.tertiary(
            label: 'No, mantenerla',
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          const SizedBox(width: AuraSpace.xs),
          AuraButton.danger(
            label: 'Sí, cancelar',
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyId = request.id);
    final error = await widget.state.cancelLabRequest(request.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    _notify(error ?? 'Toma de muestras cancelada.', isError: error != null);
  }

  @override
  Widget build(BuildContext context) {
    // Cancelar o verificar un pago actualiza el estado global; sin escucharlo,
    // la lista seguiría mostrando la toma que el paciente acaba de cancelar.
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _buildContent(),
    );
  }

  Widget _buildContent() {
    final results = widget.state.labResults;
    final upcoming =
        widget.state.labRequests.where((r) => r.isCancellable).toList();
    final isEmpty = upcoming.isEmpty && results.isEmpty;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Mis exámenes')),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.screenX,
                AuraSpace.md,
                AuraSpace.screenX,
                0,
              ),
              child: AuraReadable(
                child: AuraSkeleton.list(count: 3, height: 128),
              ),
            )
          : RefreshIndicator(
              color: p.accent,
              onRefresh: _load,
              child: ListView(
                // Sin esto, tirar para refrescar no funciona justo cuando más
                // falta hace: con el error o el vacío en pantalla la lista no
                // desborda y no acepta el gesto.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.screenX,
                  AuraSpace.xs,
                  AuraSpace.screenX,
                  AuraSpace.xl,
                ),
                children: [
                  AuraReadable(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Falló la carga y no hay nada que enseñar: esto es un
                        // error, no un paciente sin exámenes.
                        if (_error != null && isEmpty) ...[
                          const SizedBox(height: AuraSpace.xxl),
                          AuraErrorState(
                            title: 'No pudimos cargar tus exámenes',
                            message:
                                'Revisa tu conexión e inténtalo de nuevo. Tus '
                                'tomas agendadas y tus informes siguen ahí.',
                            onRetry: _load,
                          ),
                        ] else ...[
                          // Falló la carga pero hay datos guardados: se
                          // muestran con la advertencia. Esconder lo que sí
                          // tenemos es peor que enseñarlo desactualizado.
                          if (_error != null) ...[
                            const SizedBox(height: AuraSpace.xs),
                            AuraBanner(
                              tone: AuraTone.warning,
                              title: 'Lista sin actualizar',
                              message:
                                  'No pudimos contactar con el servidor, así '
                                  'que esto es lo último que teníamos guardado.',
                              actionLabel: 'Reintentar',
                              onAction: _load,
                            ),
                          ],

                          const SizedBox(height: AuraSpace.md),
                          const AuraSectionHeader(title: 'Tomas agendadas'),
                          if (upcoming.isEmpty)
                            AuraEmptyState(
                              icon: Icons.event_available_rounded,
                              compact: true,
                              title: 'No tienes tomas agendadas',
                              message:
                                  'Cuando pidas un examen de laboratorio, aquí '
                                  'verás el día, la hora y la dirección de la '
                                  'toma de muestras.',
                              actionLabel: 'Pedir un examen',
                              onAction: _goToServices,
                            ),
                          for (final request in upcoming) ...[
                            _requestCard(request),
                            const SizedBox(height: AuraSpace.sm),
                          ],

                          const SizedBox(height: AuraSpace.xl),
                          const AuraSectionHeader(title: 'Tus informes'),
                          if (results.isEmpty)
                            const AuraEmptyState(
                              icon: Icons.description_outlined,
                              compact: true,
                              title: 'Aún no hay informes',
                              message:
                                  'Cuando el laboratorio cargue tu resultado, '
                                  'aparecerá aquí y también te llegará por '
                                  'correo.',
                            ),
                          for (final result in results) ...[
                            _resultCard(result),
                            const SizedBox(height: AuraSpace.sm),
                          ],

                          const SizedBox(height: AuraSpace.xl),
                          Text(
                            'Los informes son documentos clínicos: no '
                            'reemplazan la interpretación de un profesional. '
                            'Si tienes dudas sobre lo que indican, agenda una '
                            'consulta para revisarlos.',
                            style: AppType.bodySmall.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Un dato de la toma: icono, y el texto al lado.
  ///
  /// Los emoji 📍 y 🧪 hacían de icono. Un lector de pantalla o los salta o los
  /// lee por su nombre Unicode, así que la dirección empezaba por «alfiler
  /// redondo» y el nombre del laboratorista, por «tubo de ensayo».
  Widget _metaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AuraIcon.sm, color: p.textMuted),
          const SizedBox(width: AuraSpace.xs),
          Expanded(
            child: Text(
              text,
              style: AppType.bodySmall.copyWith(color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(LabRequest request) {
    final busy = _busyId == request.id;
    final notice =
        _paymentNotice?.requestId == request.id ? _paymentNotice : null;
    final canPay = request.awaitsPayment && request.paymentUrl != null;
    final notes = request.clinicalNotes;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.scheduledLabel ?? 'Fecha por confirmar',
                  style: AppType.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              // Flexible y no fijo: con la letra al 200 % «Pago pendiente» es
              // más ancho que la tarjeta, y así se parte en vez de desbordar
              // sobre la fecha.
              Flexible(
                child: AuraBadge(
                  label: request.statusLabel,
                  tone: request.awaitsPayment
                      ? AuraTone.warning
                      : AuraTone.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          if (request.addressText.isNotEmpty)
            _metaRow(Icons.place_outlined, request.addressText),
          if (request.professionalName != null)
            _metaRow(Icons.science_outlined, request.professionalName!),
          if (request.examRequired != null)
            _metaRow(
              Icons.checklist_rounded,
              'Exámenes: ${request.examRequired}',
            ),

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.sm),
            AuraBanner(
              tone: AuraTone.info,
              icon: Icons.assignment_outlined,
              title: 'Indicaciones del laboratorio',
              message: notes,
            ),
          ],

          if (notice != null) ...[
            const SizedBox(height: AuraSpace.sm),
            AuraBanner(
              tone: notice.tone,
              message: notice.message,
              // El pago que aún no aparece es el caso en que hace falta
              // reintentar; el confirmado ya no lleva a ninguna parte.
              actionLabel:
                  notice.tone == AuraTone.success ? null : 'Comprobar otra vez',
              onAction: notice.tone == AuraTone.success || busy
                  ? null
                  : () => _verifyPayment(request),
            ),
          ],

          // Una sola acción manda. Pagar es a lo que vino quien tiene la toma
          // sin pagar; comprobar el pago y cancelar son salidas, y estaban
          // dibujadas con el mismo peso que ella.
          if (request.awaitsPayment) ...[
            const SizedBox(height: AuraSpace.md),
            AuraButton(
              label: 'Pagar ${Money.format(request.finalPrice)}',
              icon: Icons.account_balance_wallet_rounded,
              onPressed: canPay && !busy ? () => _pay(request) : null,
            ),
            if (!canPay) ...[
              const SizedBox(height: AuraSpace.xs),
              // Un botón apagado sin explicación es un callejón sin salida.
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
              expand: true,
              loading: busy,
              onPressed: busy ? null : () => _verifyPayment(request),
            ),
          ],

          if (request.isCancellable) ...[
            SizedBox(
              height: request.awaitsPayment ? AuraSpace.xs : AuraSpace.md,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AuraButton(
                label: 'Cancelar la toma',
                // Entrada discreta, confirmación contundente: el rojo vive en
                // el botón del diálogo, que es donde ya no hay vuelta atrás.
                kind: AuraButtonKind.tertiary,
                size: AuraButtonSize.small,
                expand: false,
                onPressed: busy ? null : () => _cancel(request),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(LabResult result) {
    final opening = _openingId == result.id;
    final issued = result.issuedAt;
    final meta = [
      if (issued != null)
        '${issued.day.toString().padLeft(2, '0')}/'
            '${issued.month.toString().padLeft(2, '0')}/${issued.year}',
      ?result.readableSize,
      if (result.emailedAt != null) 'enviado por correo',
    ].join(' · ');
    final notes = result.notes;

    return AuraCard(
      // Toda la tarjeta abre el informe. La única forma de abrirlo era un icono
      // de 20 px en la esquina derecha.
      onTap: opening ? null : () => _open(result),
      semanticLabel: 'Abrir el informe ${result.title}. $meta',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.accentSurface,
              borderRadius: AuraRadius.allSm,
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: p.accentText,
              size: AuraIcon.md,
            ),
          ),
          const SizedBox(width: AuraSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.xxxs),
                  Text(meta, style: AppType.label.copyWith(color: p.textMuted)),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.xxs),
                  Text(
                    notes,
                    style: AppType.bodySmall.copyWith(color: p.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.xs),
          SizedBox(
            width: AuraTap.min,
            height: AuraTap.min,
            child: opening
                ? Center(
                    child: SizedBox(
                      width: AuraIcon.md,
                      height: AuraIcon.md,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: p.accent,
                      ),
                    ),
                  )
                : Icon(
                    Icons.download_rounded,
                    color: p.accent,
                    size: AuraIcon.md,
                  ),
          ),
        ],
      ),
    );
  }
}
