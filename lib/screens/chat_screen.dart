import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/service_request.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../ui/service_visuals.dart';

/// Conversación con el profesional que atiende.
///
/// ## «Canal cifrado de extremo a extremo» se ha eliminado
///
/// Era el subtítulo por defecto de la cabecera. El canal es REST y SSE contra
/// el backend, que guarda los mensajes en claro y los sirve a los dos lados:
/// eso no es cifrado de extremo a extremo, que por definición significa que ni
/// siquiera el servidor puede leerlos.
///
/// No era un texto de relleno mal elegido. Es una afirmación de seguridad
/// concreta, en una app de salud, sobre datos clínicos, y alguien podría
/// escribir aquí algo que no escribiría si supiera cómo viaja de verdad. Se
/// sustituye por lo que sí es cierto: la conversación queda guardada y solo la
/// ven el paciente y el equipo que le atiende.
///
/// ## Los otros arreglos
///
/// - **Las respuestas rápidas ya no borran lo escrito.** Hacían
///   `_controller.text = text`, así que tocar un chip después de haber tecleado
///   media frase la hacía desaparecer sin manera de recuperarla. Ahora añaden
///   al final.
/// - **Un mensaje que no llegó se ve.** Antes `_send()` limpiaba el campo al
///   instante y, si el servidor rechazaba, el texto ya no estaba en ninguna
///   parte: solo quedaba un aviso rojo que se iba solo.
/// - **Se quitó el selector duplicado.** Había tres maneras simultáneas de
///   cambiar de conversación: los chips en línea, la píldora «Chats (N)» y el
///   selector del seguimiento. Y la píldora contaba `activeRequests` pero abría
///   una hoja que listaba otra cosa, así que con historial y una sola atención
///   activa decía «Chats (0)» y abría una hoja vacía. Queda una sola: los chips,
///   y solo cuando hay más de una conversación.
class ChatScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const ChatScreen({super.key, required this.state, required this.onBack});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  AppPalette get p => context.palette;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  /// Lo último que se intentó enviar y el servidor rechazó. Se conserva para
  /// poder reintentarlo sin volver a escribirlo.
  String? _failedText;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    // Sondeo rápido mientras la pantalla está a la vista, y marcar leído.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.setChatScreenVisible(true);
      widget.state.markMessagesRead();
    });
  }

  @override
  void dispose() {
    widget.state.setChatScreenVisible(false);
    widget.state.removeListener(_onStateChanged);
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;

    // Un envío rechazado devuelve el texto al campo en vez de perderlo.
    final error = widget.state.chatSendError;
    if (error != null) {
      final pending = _failedText;
      setState(() {
        _sending = false;
        if (pending != null && _controller.text.isEmpty) {
          _controller.text = pending;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: p.error,
          action: SnackBarAction(
            label: 'Reintentar',
            textColor: context.scheme.onError,
            onPressed: _send,
          ),
        ),
      );
      widget.state.clearChatSendError();
      return;
    }
    setState(() {});
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _failedText = text;
    });
    _controller.clear();

    await widget.state.sendMessage(text);

    if (!mounted) return;
    setState(() {
      _sending = false;
      // Si no hubo error, el borrador de reintento ya no hace falta.
      if (widget.state.chatSendError == null) _failedText = null;
    });
  }

  /// Añade la frase al final en vez de reemplazar lo escrito.
  void _appendQuick(String text) {
    final current = _controller.text.trimRight();
    final joined = current.isEmpty ? text : '$current $text';
    _controller
      ..text = joined
      ..selection = TextSelection.collapsed(offset: joined.length);
    _inputFocus.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final request = state.currentRequest;
    final messages = state.chatMessages;

    if (request == null && messages.isEmpty) return _noConversation();

    final open = request != null &&
        request.status != RequestStatus.completed &&
        request.status != RequestStatus.cancelled;

    final threads = state.activeRequests
        .where((r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.cancelled)
        .toList();

    return Column(
      children: [
        _header(request),
        if (threads.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.screenX,
              0,
              AuraSpace.screenX,
              AuraSpace.xs,
            ),
            child: _threadPicker(threads, request?.id),
          ),
        Expanded(
          child: messages.isEmpty
              ? _emptyThread(open)
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.screenX,
                    AuraSpace.md,
                    AuraSpace.screenX,
                    AuraSpace.md,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[messages.length - 1 - i];
                    return msg.sender == 'system'
                        ? _systemBubble(msg)
                        : _bubble(msg, msg.sender == 'patient');
                  },
                ),
        ),
        if (open) _composer() else _closedNotice(),
      ],
    );
  }

  // ------------------------------------------------------------- cabecera

  Widget _header(ServiceRequest? request) {
    final name = request?.professionalName;
    final title = (name != null && name.isNotEmpty)
        ? name
        : (request == null
            ? 'Mensajes'
            : 'Equipo de ${serviceShortName(request.serviceId, "Aura")}');

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.xs,
        AuraSpace.xs,
        AuraSpace.screenX,
        AuraSpace.sm,
      ),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          AuraIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver al inicio',
            onPressed: widget.onBack,
            color: p.textPrimary,
          ),
          const SizedBox(width: AuraSpace.xxs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: AuraSpace.xxxs),
                Text(
                  // Lo que sí es cierto. Ver la nota de clase.
                  'Solo tú y el equipo que te atiende ven esta conversación.',
                  maxLines: 2,
                  style: AppType.bodySmall.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _threadPicker(List<ServiceRequest> threads, String? currentId) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: threads.map((r) {
          final selected = r.id == currentId;
          final unread = widget.state.unreadFor(r.id);
          return Padding(
            padding: const EdgeInsets.only(right: AuraTap.gap),
            child: Semantics(
              button: true,
              selected: selected,
              label: unread > 0
                  ? '${serviceShortName(r.serviceId, "Atención")}, $unread sin leer'
                  : serviceShortName(r.serviceId, 'Atención'),
              child: ExcludeSemantics(
                child: Material(
                  color: selected ? p.accent : p.card,
                  borderRadius: AuraRadius.allSm,
                  child: InkWell(
                    onTap: () => widget.state.selectChatRequest(r.id),
                    borderRadius: AuraRadius.allSm,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: AuraTap.min),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: AuraRadius.allSm,
                        border: Border.all(
                          color: selected ? p.accent : p.borderStrong,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            serviceShortName(r.serviceId, 'Atención'),
                            style: AppType.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? context.scheme.onPrimary
                                  : p.textPrimary,
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: AuraSpace.xxs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: p.error,
                                borderRadius: AuraRadius.allPill,
                              ),
                              child: Text(
                                '$unread',
                                style: AppType.label.copyWith(
                                  color: context.scheme.onError,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // -------------------------------------------------------------- burbujas

  Widget _bubble(ChatMessage msg, bool isMine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.sm),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine &&
              msg.senderName != null &&
              msg.senderName!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AuraSpace.xs,
                bottom: AuraSpace.xxxs,
              ),
              child: Text(
                msg.senderName!,
                style: AppType.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.textMuted,
                ),
              ),
            ),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.sm,
              vertical: AuraSpace.xs + 2,
            ),
            decoration: BoxDecoration(
              color: isMine ? p.accent : p.card,
              border: isMine ? null : Border.all(color: p.border),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AuraRadius.md),
                topRight: const Radius.circular(AuraRadius.md),
                bottomLeft: Radius.circular(isMine ? AuraRadius.md : AuraRadius.xs),
                bottomRight: Radius.circular(isMine ? AuraRadius.xs : AuraRadius.md),
              ),
            ),
            child: Text(
              msg.text,
              style: AppType.bodyMedium.copyWith(
                color: isMine ? context.scheme.onPrimary : p.textPrimary,
              ),
            ),
          ),
          if (msg.timestamp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: AuraSpace.xxxs,
                left: AuraSpace.xs,
                right: AuraSpace.xs,
              ),
              child: Text(
                msg.timestamp,
                style: AppType.label.copyWith(color: p.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  /// Anotación automática del hilo.
  ///
  /// Sigue existiendo y sigue siendo `system`, en tercera persona y sin firma:
  /// «Dra. Camila Rojas tomó tu atención». Es un hecho anotado, no una voz
  /// prestada, y es lo que el contador de no leídos puede contar. Quitarlas y
  /// dejar solo un push deja el hilo del paciente con un único mensaje mientras
  /// el profesional ya está en su puerta.
  Widget _systemBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.xs),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.sm,
            vertical: AuraSpace.xs,
          ),
          decoration: BoxDecoration(
            color: p.fill,
            borderRadius: AuraRadius.allSm,
          ),
          child: Text(
            msg.text,
            textAlign: TextAlign.center,
            style: AppType.bodySmall.copyWith(color: p.textSecondary),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- redacción

  Widget _composer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.sm,
        AuraSpace.xs,
        AuraSpace.sm,
        AuraSpace.xs + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quick('¿Cuánto falta?'),
                _quick('Ya llegué a casa'),
                _quick('Gracias'),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocus,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppType.bodyMedium.copyWith(color: p.textPrimary),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Escribe tu mensaje',
                    constraints: const BoxConstraints(
                      minHeight: AuraTap.comfortable,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              // 52×52, no 42. Y deshabilitado mientras no hay texto, en vez de
              // aceptar el toque y no hacer nada.
              SizedBox(
                height: AuraTap.comfortable,
                width: AuraTap.comfortable,
                child: Material(
                  color: _controller.text.trim().isEmpty || _sending
                      ? p.disabledFill
                      : p.accent,
                  borderRadius: AuraRadius.allSm,
                  child: InkWell(
                    onTap: _controller.text.trim().isEmpty ? null : _send,
                    borderRadius: AuraRadius.allSm,
                    child: Semantics(
                      button: true,
                      label: 'Enviar mensaje',
                      child: Center(
                        child: _sending
                            ? SizedBox(
                                height: AuraIcon.sm,
                                width: AuraIcon.sm,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: p.onDisabled,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                size: AuraIcon.md,
                                color: _controller.text.trim().isEmpty
                                    ? p.onDisabled
                                    : context.scheme.onPrimary,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quick(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: AuraTap.gap),
      child: Material(
        color: p.fill,
        borderRadius: AuraRadius.allSm,
        child: InkWell(
          onTap: () => _appendQuick(text),
          borderRadius: AuraRadius.allSm,
          child: Container(
            constraints: const BoxConstraints(minHeight: AuraTap.min),
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.sm),
            alignment: Alignment.center,
            child: Text(
              text,
              style: AppType.bodySmall.copyWith(
                color: p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _closedNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AuraSpace.screenX,
        AuraSpace.md,
        AuraSpace.screenX,
        AuraSpace.md + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Text(
        'Esta atención ya terminó. Puedes leer la conversación, pero no enviar '
        'mensajes nuevos.',
        textAlign: TextAlign.center,
        style: AppType.bodySmall.copyWith(color: p.textMuted),
      ),
    );
  }

  // ---------------------------------------------------------------- vacíos

  Widget _emptyThread(bool open) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: AuraEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: open ? 'Todavía no hay mensajes' : 'No hubo mensajes',
          message: open
              ? 'Escribe lo que necesites. El profesional lo verá en cuanto tome '
                  'tu atención.'
              : 'Esta atención terminó sin mensajes.',
          compact: true,
        ),
      ),
    );
  }

  Widget _noConversation() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: AuraReadable(
          child: AuraEmptyState(
            icon: Icons.forum_outlined,
            title: 'Aún no tienes conversaciones',
            message:
                'Cuando pidas una atención, aquí podrás escribirte con el '
                'profesional que te atiende.',
            actionLabel: 'Pedir una atención',
            onAction: () => widget.state.setTab('home'),
          ),
        ),
      ),
    );
  }
}
