import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// Controles de voz del campo de síntomas.
///
/// Son dos cosas distintas, las dos opcionales:
///  - **Dictado**: reconocimiento de voz del propio teléfono (Android
///    `SpeechRecognizer`, iOS `SFSpeechRecognizer`). Lo que se dicta se añade
///    al campo de notas. No pasa por ningún servicio de pago.
///  - **Nota de voz**: graba un audio que viaja con la solicitud, para que el
///    profesional oiga a la persona describir lo que le pasa.
///
/// Toda llamada a un plugin está protegida: si faltan permisos o el teléfono no
/// trae reconocedor, el widget se queda en modo texto y explica por qué.
class SymptomVoiceInput extends StatefulWidget {
  /// Campo de notas en el que escribe el dictado.
  final TextEditingController controller;

  /// Recibe la ruta del audio grabado, o null cuando se descarta la nota.
  final ValueChanged<String?> onAudioChanged;

  /// Avisa cuando empieza o termina una grabación.
  final ValueChanged<bool>? onRecordingChanged;

  /// Avisa cuando el reconocimiento de voz produce texto nuevo.
  final ValueChanged<String>? onTextChanged;

  const SymptomVoiceInput({
    super.key,
    required this.controller,
    required this.onAudioChanged,
    this.onRecordingChanged,
    this.onTextChanged,
  });

  @override
  State<SymptomVoiceInput> createState() => _SymptomVoiceInputState();
}

class _SymptomVoiceInputState extends State<SymptomVoiceInput> {
  final SpeechToText _speech = SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();

  bool _speechReady = false;
  bool _listening = false;
  String _partialTranscript = '';

  /// Lo que ya había escrito cuando empezó el dictado, para que los resultados
  /// parciales reemplacen solo la parte dictada y no borren lo tecleado.
  String _textBeforeDictation = '';

  bool _recording = false;
  String? _audioPath;
  Duration _recordedFor = Duration.zero;
  Timer? _recordTimer;

  String? _notice;

  /// Con qué gravedad se pinta el aviso. No todos son lo mismo: que el
  /// teléfono no traiga reconocedor es un dato; que falte el permiso del
  /// micrófono es algo que la persona puede arreglar.
  AuraTone _noticeTone = AuraTone.info;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _speech.stop();
    _recorder.dispose();
    super.dispose();
  }

  void _setNotice(String message, AuraTone tone) {
    setState(() {
      _notice = message;
      _noticeTone = tone;
    });
  }

  // ----------------------------------------------------------------- dictado

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    if (!_speechReady) {
      try {
        _speechReady = await _speech.initialize(
          onStatus: (status) {
            if (!mounted) return;
            if (status == 'done' || status == 'notListening') {
              setState(() => _listening = false);
            }
          },
          onError: (error) {
            if (!mounted) return;
            // El código del plugin («error_speech_timeout») va al registro, no
            // a la pantalla: no le dice nada a nadie y aparecía en mitad del
            // formulario, donde parece que se rompió la solicitud entera.
            debugPrint('speech_to_text error: ${error.errorMsg}');
            _listening = false;
            _setNotice(
              'El dictado se detuvo. Puedes volver a intentarlo o escribir '
              'los síntomas.',
              AuraTone.warning,
            );
          },
        );
      } catch (e) {
        debugPrint('speech_to_text initialize failed: $e');
        _speechReady = false;
      }
    }

    if (!_speechReady) {
      if (mounted) {
        _setNotice(
          'Este teléfono no tiene dictado por voz. Puedes escribir los '
          'síntomas o grabar una nota de voz.',
          AuraTone.info,
        );
      }
      return;
    }

    _textBeforeDictation = widget.controller.text.trim();
    setState(() {
      _listening = true;
      _partialTranscript = '';
      _notice = null;
    });

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'es_CL',
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _partialTranscript = result.recognizedWords);

        final dictated = result.recognizedWords.trim();
        if (dictated.isEmpty) return;

        final newText = _textBeforeDictation.isEmpty
            ? dictated
            : '$_textBeforeDictation $dictated';
        widget.controller.text = newText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
        widget.onTextChanged?.call(newText);
      },
    );
  }

  // ------------------------------------------------------------ nota de voz

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      _recordTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _audioPath = path;
      });
      widget.onRecordingChanged?.call(false);
      widget.onAudioChanged(path);
      return;
    }

    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          _setNotice(
            'Necesitamos permiso para usar el micrófono. Actívalo en los '
            'ajustes del teléfono y vuelve a intentarlo.',
            AuraTone.warning,
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final target =
          '${directory.path}/sintomas_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
        path: target,
      );

      _recordedFor = Duration.zero;
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordedFor += const Duration(seconds: 1));
        // Tope duro: mantiene pequeño lo que se sube y legible la cola del
        // profesional.
        if (_recordedFor.inSeconds >= 120) _toggleRecording();
      });

      if (mounted) {
        setState(() {
          _recording = true;
          _notice = null;
        });
        widget.onRecordingChanged?.call(true);
      }
    } catch (e) {
      debugPrint('Audio recording failed: $e');
      if (mounted) {
        _setNotice('No pudimos empezar a grabar. Inténtalo otra vez.',
            AuraTone.error);
        widget.onRecordingChanged?.call(false);
      }
    }
  }

  Future<void> _discardAudio() async {
    final path = _audioPath;
    setState(() {
      _audioPath = null;
      _recordedFor = Duration.zero;
    });
    widget.onAudioChanged(null);

    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } catch (e) {
        debugPrint('Could not delete voice note: $e');
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Uno debajo del otro y con el texto de botón del sistema. Antes iban
        // en dos columnas y con el rótulo en 13 pt —el tamaño de un metadato—,
        // y el de la grabación crece con el cronómetro: «Detener (01:12)» no
        // cabía en media pantalla y se cortaba justo en el número.
        AuraButton.secondary(
          label: _listening ? 'Detener el dictado' : 'Dictar los síntomas',
          icon: _listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
          onPressed: _recording ? null : _toggleDictation,
        ),
        const SizedBox(height: AuraTap.gap),
        AuraButton.secondary(
          label: _recording
              ? 'Detener la grabación (${_formatDuration(_recordedFor)})'
              : 'Grabar una nota de voz',
          icon: _recording
              ? Icons.stop_circle_outlined
              : Icons.graphic_eq_rounded,
          onPressed: _listening ? null : _toggleRecording,
        ),

        if (_listening) ...[
          const SizedBox(height: AuraSpace.xs),
          _listeningStrip(),
        ],

        if (_audioPath != null && !_recording) ...[
          const SizedBox(height: AuraSpace.xs),
          _attachedNote(),
        ],

        if (_notice != null) ...[
          const SizedBox(height: AuraSpace.xs),
          AuraBanner(
            message: _notice!,
            tone: _noticeTone,
            onDismiss: () => setState(() => _notice = null),
          ),
        ],
      ],
    );
  }

  /// Lo que el teléfono va entendiendo mientras se dicta.
  ///
  /// Sin `liveRegion` a propósito: el texto cambia palabra a palabra y un
  /// lector de pantalla estaría interrumpiendo a quien está hablando.
  Widget _listeningStrip() {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.sm),
      decoration: BoxDecoration(
        color: p.accentSurface,
        borderRadius: AuraRadius.allSm,
        border: Border.all(color: p.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hearing_rounded, size: AuraIcon.sm, color: p.accentText),
          const SizedBox(width: AuraSpace.xs),
          Expanded(
            child: Text(
              _partialTranscript.isEmpty
                  ? 'Te escuchamos. Habla con normalidad.'
                  : _partialTranscript,
              style: AppType.bodySmall.copyWith(color: p.accentText),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachedNote() {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.only(
        left: AuraSpace.sm,
        top: AuraSpace.xxs,
        right: AuraSpace.xxs,
        bottom: AuraSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: p.accentSurface,
        borderRadius: AuraRadius.allSm,
        border: Border.all(color: p.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.audiotrack_rounded, size: AuraIcon.sm, color: p.accentText),
          const SizedBox(width: AuraSpace.xs),
          Expanded(
            child: Text(
              'Nota de voz lista (${_formatDuration(_recordedFor)})',
              style: AppType.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: p.accentText,
              ),
            ),
          ),
          // Quitar la nota era una equis de 16 px sin nombre: el objetivo
          // tocable más pequeño de todo el formulario, y el único que borra
          // algo que la persona acaba de grabar.
          AuraIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Quitar la nota de voz',
            color: p.error,
            size: AuraIcon.sm,
            onPressed: _discardAudio,
          ),
        ],
      ),
    );
  }
}
