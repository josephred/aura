import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme/app_theme.dart';

/// Voice controls for the symptom descriptor.
///
/// Two independent capabilities, both optional:
///  - **Dictado**: on-device speech recognition (Android `SpeechRecognizer`,
///    iOS `SFSpeechRecognizer`). Transcribed text is appended to the notes
///    field. No cloud service and no per-minute cost.
///  - **Nota de voz**: records an audio file that travels with the request so
///    the clinician can listen to the patient describe the symptoms.
///
/// Every plugin call is guarded: if permissions are denied or the device has
/// no recognizer, the widget degrades to text-only and tells the user why.
class SymptomVoiceInput extends StatefulWidget {
  /// Notes field the dictation writes into.
  final TextEditingController controller;

  /// Called with the recorded file path, or null when the note is discarded.
  final ValueChanged<String?> onAudioChanged;

  /// Called when audio recording starts or stops.
  final ValueChanged<bool>? onRecordingChanged;

  /// Called when speech recognition produces new text.
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

  /// Text already in the field when dictation started, so partial results
  /// replace only the dictated tail instead of wiping what was typed.
  String _textBeforeDictation = '';

  bool _recording = false;
  String? _audioPath;
  Duration _recordedFor = Duration.zero;
  Timer? _recordTimer;

  String? _notice;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _speech.stop();
    _recorder.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- dictation

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
            setState(() {
              _listening = false;
              _notice = 'No se pudo usar el dictado (${error.errorMsg}).';
            });
          },
        );
      } catch (e) {
        debugPrint('speech_to_text initialize failed: $e');
        _speechReady = false;
      }
    }

    if (!_speechReady) {
      if (mounted) {
        setState(() {
          _notice = 'Este dispositivo no tiene reconocimiento de voz disponible. '
              'Puedes escribir los síntomas o enviar una nota de voz.';
        });
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

  // ------------------------------------------------------------- voice note

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
          setState(() => _notice = 'Necesitamos permiso de micrófono para grabar.');
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
        // Hard cap: keeps uploads small and the clinician's queue readable.
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
        setState(() => _notice = 'No se pudo iniciar la grabación.');
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
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _recording ? null : _toggleDictation,
                icon: Icon(
                  _listening ? Icons.stop_circle_outlined : Icons.mic_none,
                  size: 16,
                ),
                label: Text(_listening ? 'Detener dictado' : 'Dictar síntomas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _listening ? const Color(0xFFDC2626) : p.accent,
                  side: BorderSide(
                    color: _listening ? const Color(0xFFDC2626) : p.border,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _listening ? null : _toggleRecording,
                icon: Icon(
                  _recording ? Icons.stop_circle_outlined : Icons.graphic_eq,
                  size: 16,
                ),
                label: Text(
                  _recording
                      ? 'Detener (${_formatDuration(_recordedFor)})'
                      : 'Nota de voz',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _recording ? const Color(0xFFDC2626) : p.accent,
                  side: BorderSide(
                    color: _recording ? const Color(0xFFDC2626) : p.border,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_listening) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.hearing, size: 13, color: p.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _partialTranscript.isEmpty
                      ? 'Escuchando… habla con normalidad.'
                      : _partialTranscript,
                  style: TextStyle(fontSize: 12, color: p.accent),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        if (_audioPath != null && !_recording) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: p.accentSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.audiotrack, size: 15, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nota de voz adjunta (${_formatDuration(_recordedFor)})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: p.accent,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _discardAudio,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_notice != null) ...[
          const SizedBox(height: 8),
          Text(
            _notice!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
          ),
        ],
      ],
    );
  }
}
