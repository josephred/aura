import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onBack;

  const ChatScreen({super.key, required this.state, required this.onBack});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    // Ver el hilo es lo que lo marca como leído. Se hace aquí y no solo al
    // cambiar de pestaña porque a esta pantalla también se llega desde el
    // seguimiento de la atención.
    //
    // Abrir el chat además pide el hilo al servidor y deja el canal en
    // refresco rápido mientras la pantalla esté a la vista: hasta ahora esta
    // pantalla no hacía ninguna llamada, así que un mensaje escrito desde el
    // portal del profesional solo aparecía si el stream SSE seguía vivo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.state.setChatScreenVisible(true);
      widget.state.markMessagesRead();
    });
  }

  /// Un envío rechazado por el servidor se avisa; en silencio, el paciente
  /// creía haber escrito al profesional.
  void _onStateChanged() {
    final error = widget.state.chatSendError;
    if (error == null) return;
    widget.state.clearChatSendError();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.state.sendMessage(text);
    _controller.clear();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    widget.state.setChatScreenVisible(false);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final currentRequest = state.currentRequest;
    final p = context.palette;
    final isClosed = currentRequest == null;
    if (currentRequest == null && state.chatMessages.isEmpty) {
      return _buildNoActiveRequestState();
    }

    // We reverse the list to support "reverse: true" in ListView, which handles auto-scrolling to bottom perfectly.
    final messages = state.chatMessages.reversed.toList();

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: p.card,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: p.accentSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: p.accentText,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                currentRequest?.professionalName != null
                                    ? currentRequest!.professionalName!
                                    : (isClosed
                                        ? 'Historial de Comunicación'
                                        : 'Mesa de Asistencia Aura'),
                                style: AppType.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: p.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                height: 6,
                                width: 6,
                                decoration: BoxDecoration(
                                  color: isClosed
                                      ? p.textMuted
                                      : const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentRequest?.professionalSpecialty != null
                                ? '${currentRequest!.professionalSpecialty!} · ${currentRequest.status.label}'
                                : (isClosed
                                    ? 'Atención finalizada (solo lectura)'
                                    : 'Canal cifrado de extremo a extremo'),
                            style: AppType.label.copyWith(
                              color: isClosed ? p.textMuted : p.accentText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (state.activeRequests.length > 1 || state.pastServices.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () => _showConversationsBottomSheet(context, state),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: p.accentSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: p.accent.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.forum_outlined, size: 14, color: p.accentText),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Chats (${state.activeRequests.length})',
                                    style: AppType.label.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: p.accentText,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: p.accentSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.security,
                          color: p.accentText,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Multi-Professional Selector (si hay más de una atención activa)
            _buildProfessionalSelector(state, p),
            // Safety banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isClosed
                  ? p.cardSubtle
                  : const Color(0xFF0D9488).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    isClosed ? Icons.history : Icons.lock_outline,
                    size: 14,
                    color: isClosed ? p.textMuted : p.accentText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isClosed
                          ? 'Registro histórico de mensajes de la consulta realizada.'
                          : 'Canal clínico directo con el profesional a cargo de esta atención.',
                      style: AppType.label.copyWith(
                        color: isClosed ? p.textMuted : p.accentText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Messages Area
            Expanded(
              child: Container(
                color: p.background,
                child: messages.isEmpty
                    ? _buildEmptyThread()
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, idx) {
                          final msg = messages[idx];

                          if (msg.sender == 'system') {
                            return _buildSystemBubble(msg);
                          }

                          final isMe = msg.sender == 'patient';
                          return _buildChatBubble(msg, isMe);
                        },
                      ),
              ),
            ),
            if (!isClosed) ...[
              // Quick reply chips row
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                color: p.card,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickChip('👋 Saludo', 'Hola, quedo atento a su llegada.'),
                      const SizedBox(width: 6),
                      _buildQuickChip('🔔 Timbre ok', 'El timbre y citófono funcionan correctamente.'),
                      const SizedBox(width: 6),
                      _buildQuickChip('🚪 En puerta', 'Estaré atento para abrir la puerta.'),
                      const SizedBox(width: 6),
                      _buildQuickChip('📍 Acceso', '¿Necesita alguna indicación para ingresar al domicilio?'),
                    ],
                  ),
                ),
              ),
              // Input text row
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                color: p.card,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.cardSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: AppType.bodyMedium.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Escriba su consulta al profesional...',
                            hintStyle: AppType.bodyMedium.copyWith(
                              color: p.textFaint,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: p.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: p.card,
                child: Center(
                  child: Text(
                    'Atención finalizada. El canal directo se encuentra cerrado.',
                    style: AppType.bodySmall.copyWith(
                      color: p.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBubble(ChatMessage msg) {
    final p = context.palette;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: p.accentSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          msg.text,
          textAlign: TextAlign.center,
          style: AppType.bodySmall.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg, bool isMe) {
    final p = context.palette;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            decoration: BoxDecoration(
              color: isMe ? p.accent : p.card,
              border: isMe ? null : Border.all(color: p.border),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.01),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe && msg.senderName != null) ...[
                  Text(
                    msg.senderName!,
                    style: AppType.label.copyWith(
                      color: p.accentText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  msg.text,
                  style: AppType.bodyMedium.copyWith(
                    color: isMe ? Colors.white : p.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg.timestamp,
                  style: AppType.label.copyWith(
                    color: isMe
                        ? const Color(0xFF99F6E4)
                        : p.textFaint,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String text) {
    final p = context.palette;
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.text = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: p.accentSurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.accentSurface),
        ),
        child: Text(
          label,
          style: AppType.label.copyWith(
            color: p.accentText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Hilo abierto pero todavía sin mensajes. Antes nunca se veía: la app
  /// sembraba dos mensajes de ejemplo firmados como si los hubiera escrito el
  /// profesional asignado.
  Widget _buildEmptyThread() {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 32, color: p.textFaint),
            const SizedBox(height: 12),
            Text(
              'Aún no hay mensajes en este canal.',
              textAlign: TextAlign.center,
              style: AppType.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Escribe tu consulta: el profesional asignado la ve en su portal '
              'y te responde por aquí mismo.',
              textAlign: TextAlign.center,
              style: AppType.bodyMedium.copyWith(color: p.textFaint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveRequestState() {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Beautiful Gradient Icon Container
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: p.accentSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: p.accent.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: p.accentText,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'Canal de Asistencia Inactivo',
                  style: AppType.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Subtitle
                Text(
                  'El canal de chat directo con los profesionales clínicos se activará automáticamente al confirmar una solicitud de atención domiciliaria.',
                  style: AppType.bodyMedium.copyWith(
                    color: p.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Services shortcut list
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESPECIALIDADES DISPONIBLES',
                        style: AppType.label.copyWith(
                          fontWeight: FontWeight.bold,
                          color: p.accentText,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceRow(
                        Icons.local_hospital,
                        'Atención Médica Domiciliaria',
                        'Médico general a casa',
                      ),
                      Divider(height: 16, color: p.border),
                      _buildServiceRow(
                        Icons.local_shipping,
                        'Ambulancia de Traslado',
                        'Traslado programado camilla',
                      ),
                      Divider(height: 16, color: p.border),
                      _buildServiceRow(
                        Icons.healing,
                        'Procedimientos de Enfermería',
                        'Inyectables, curaciones',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Button to Home
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: widget.onBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'SOLICITAR NUEVA ATENCIÓN',
                      style: AppType.button.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceRow(IconData icon, String title, String subtitle) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: p.accentSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: p.accentText, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: AppType.bodySmall.copyWith(color: p.textFaint),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: p.borderStrong, size: 16),
      ],
    );
  }

  Widget _buildProfessionalSelector(AppState state, AppPalette p) {
    if (state.activeRequests.length <= 1) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(
          bottom: BorderSide(color: p.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, size: 14, color: p.accentText),
                const SizedBox(width: 4),
                Text(
                  'ATENCIONES ACTIVAS (${state.activeRequests.length}) · SELECCIONE PROFESIONAL',
                  style: AppType.label.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: p.accentText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: state.activeRequests.map((req) {
                final isSelected = req.id == state.selectedChatRequestId ||
                    (state.selectedChatRequestId == null && req.id == state.currentRequest?.id);

                final profName = req.professionalName ?? _getServiceName(req.serviceId);
                final specialty = req.professionalSpecialty ?? req.status.label;
                final icon = _getServiceIcon(req.serviceId);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => state.selectChatRequest(req.id),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? p.accentSurface : p.fill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? p.accent : p.border,
                          width: isSelected ? 1.8 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: p.accent.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected ? p.accent : p.card,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              size: 14,
                              color: isSelected ? Colors.white : p.accentText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                profName,
                                style: AppType.label.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? p.textPrimary : p.textSecondary,
                                ),
                              ),
                              Text(
                                specialty,
                                style: AppType.label.copyWith(
                                  color: isSelected ? p.accentText : p.textFaint,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              height: 6,
                              width: 6,
                              decoration: BoxDecoration(
                                color: p.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getServiceName(String serviceId) {
    switch (serviceId) {
      case 'medico':
        return 'Médico General';
      case 'kine_motora':
      case 'kine_respiratoria':
        return 'Kinesiología';
      case 'enfermeria':
        return 'Enfermería';
      case 'laboratorio':
        return 'Laboratorio';
      case 'ambulancia':
      case 'traslado_simple':
      case 'traslado_avanzado':
        return 'Ambulancia';
      default:
        return 'Atención Domiciliaria';
    }
  }

  IconData _getServiceIcon(String serviceId) {
    switch (serviceId) {
      case 'medico':
        return Icons.local_hospital_rounded;
      case 'kine_motora':
      case 'kine_respiratoria':
        return Icons.accessibility_new_rounded;
      case 'enfermeria':
        return Icons.healing_rounded;
      case 'laboratorio':
        return Icons.biotech_rounded;
      case 'ambulancia':
      case 'traslado_simple':
      case 'traslado_avanzado':
        return Icons.local_shipping_rounded;
      default:
        return Icons.medical_services_rounded;
    }
  }

  void _showConversationsBottomSheet(BuildContext context, AppState state) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.forum_rounded, color: p.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Canales de Conversación',
                      style: AppType.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Seleccione la atención con la que desea comunicarse:',
                  style: AppType.bodySmall.copyWith(color: p.textFaint),
                ),
                const SizedBox(height: 16),
                if (state.activeRequests.isNotEmpty) ...[
                  Text(
                    'ATENCIONES EN CURSO',
                    style: AppType.label.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: p.accentText,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...state.activeRequests.map((req) {
                    final isSelected = req.id == state.selectedChatRequestId ||
                        (state.selectedChatRequestId == null && req.id == state.currentRequest?.id);
                    final profName = req.professionalName ?? _getServiceName(req.serviceId);
                    final specialty = req.professionalSpecialty ?? req.status.label;
                    final icon = _getServiceIcon(req.serviceId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? p.accentSurface : p.fill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? p.accent : p.border,
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? p.accent : p.card,
                          child: Icon(icon, color: isSelected ? Colors.white : p.accentText, size: 20),
                        ),
                        title: Text(
                          profName,
                          style: AppType.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '$specialty · ${req.status.label}',
                          style: AppType.bodySmall.copyWith(
                            color: isSelected ? p.accentText : p.textFaint,
                          ),
                        ),
                        trailing: isSelected
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: p.accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Activo',
                                  style: AppType.label.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              )
                            : Icon(Icons.chevron_right, color: p.textMuted),
                        onTap: () {
                          state.selectChatRequest(req.id);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
