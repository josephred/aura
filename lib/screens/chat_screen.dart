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

    if (currentRequest == null) {
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
                                'Mesa de Asistencia Aura',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: p.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                height: 6,
                                width: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Canal de Chat Seguro Encriptado',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.accentSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: p.accentText,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Clínica Digital',
                          style: TextStyle(
                            color: p.accentText,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Message List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: messages.isEmpty
                    ? _buildEmptyThread()
                    : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
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
            // Input text row
            Container(
              padding: const EdgeInsets.all(12),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: p.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Escriba su consulta al profesional...',
                          hintStyle: TextStyle(
                            color: p.textFaint,
                            fontSize: 12,
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
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 12,
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
                    style: TextStyle(
                      color: p.accentText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  msg.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : p.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg.timestamp,
                  style: TextStyle(
                    color: isMe
                        ? const Color(0xFF99F6E4)
                        : p.textFaint,
                    fontSize: 12,
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Escribe tu consulta: el profesional asignado la ve en su portal '
              'y te responde por aquí mismo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: p.textFaint, height: 1.5),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Subtitle
                Text(
                  'El canal de chat directo con los profesionales clínicos se activará automáticamente al confirmar una solicitud de atención domiciliaria.',
                  style: TextStyle(
                    fontSize: 12,
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
                        style: TextStyle(
                          fontSize: 12,
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
                    child: const Text(
                      'SOLICITAR NUEVA ATENCIÓN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: p.textFaint),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: p.borderStrong, size: 16),
      ],
    );
  }
}
