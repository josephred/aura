import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/appointment.dart';
import '../state/app_state.dart';

/// In-app WebRTC video consultation. The clinical staff (web portal) is
/// always the offerer; this screen announces itself with a `ready` signal,
/// waits for an offer, answers it and exchanges ICE candidates through the
/// backend signaling endpoints. Media flows peer-to-peer, end-to-end
/// encrypted — it never touches the server.
class VideoCallScreen extends StatefulWidget {
  final AppState state;
  final Appointment appointment;
  final List<Map<String, dynamic>> iceServers;

  const VideoCallScreen({
    super.key,
    required this.state,
    required this.appointment,
    required this.iceServers,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  Timer? _pollTimer;
  bool _polling = false;

  int _lastSignalId = 0;
  int _lastOfferId = 0;
  DateTime _lastReadyAt = DateTime.now();
  final List<RTCIceCandidate> _queuedCandidates = [];

  bool _micOn = true;
  bool _camOn = true;
  bool _connected = false;
  bool _ended = false;
  String _status = 'Preparando cámara…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
    } catch (e) {
      debugPrint('getUserMedia failed. Error: $e');
      if (mounted) {
        setState(() => _status =
            'No se pudo acceder a la cámara o micrófono. Revisa los permisos de la app.');
      }
      return;
    }

    _localRenderer.srcObject = _localStream;
    await Helper.setSpeakerphoneOn(true);
    if (mounted) {
      setState(() => _status = 'Esperando al profesional…');
    }

    // Announce ourselves: if the professional is already in, they will
    // (re)send a fresh offer
    await _announceReady();

    _pollTimer = Timer.periodic(const Duration(milliseconds: 900), (_) => _poll());
  }

  // Send the `ready` signal, surfacing failures on screen. Re-announces
  // periodically from the poll loop while the handshake has not started,
  // so a lost signal self-heals instead of hanging the call forever.
  Future<void> _announceReady() async {
    _lastReadyAt = DateTime.now();
    final error = await widget.state.postVideoSignal(widget.appointment.id, 'ready');
    if (error != null && mounted && !_connected && !_ended) {
      setState(() => _status = 'No se pudo avisar al servidor.\n$error');
    }
  }

  Future<void> _poll() async {
    if (_ended || _polling) return;
    _polling = true;
    try {
      // Handshake never started (no offer yet): re-announce every 8s in
      // case the previous `ready` was lost in transit
      if (!_connected &&
          _lastOfferId == 0 &&
          DateTime.now().difference(_lastReadyAt).inSeconds >= 8) {
        await _announceReady();
      }

      final signals = await widget.state
          .fetchVideoSignals(widget.appointment.id, _lastSignalId);

      for (final signal in signals) {
        if (_ended) break;
        final id = (signal['id'] as num).toInt();
        if (id > _lastSignalId) _lastSignalId = id;
        final payload = signal['payload'] as Map<String, dynamic>?;

        switch (signal['type'] as String) {
          case 'offer':
            if (id > _lastOfferId && payload?['sdp'] != null) {
              _lastOfferId = id;
              await _handleOffer(payload!['sdp'] as String);
            }
            break;
          case 'candidate':
            if (payload != null) {
              final candidate = RTCIceCandidate(
                payload['candidate'] as String?,
                payload['sdpMid'] as String?,
                (payload['sdpMLineIndex'] as num?)?.toInt(),
              );
              final pc = _pc;
              if (pc != null && await _hasRemoteDescription(pc)) {
                try {
                  await pc.addCandidate(candidate);
                } catch (e) {
                  debugPrint('addCandidate failed. Error: $e');
                }
              } else {
                _queuedCandidates.add(candidate);
              }
            }
            break;
          case 'hangup':
            _onRemoteHangup();
            break;
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _poll: $e\n$stack');
    } finally {
      _polling = false;
    }
  }

  Future<bool> _hasRemoteDescription(RTCPeerConnection pc) async {
    try {
      return await pc.getRemoteDescription() != null;
    } catch (_) {
      return false;
    }
  }

  // A (new) offer arrived: build a fresh peer connection and answer it
  Future<void> _handleOffer(String sdp) async {
    try {
      if (mounted) setState(() => _status = 'Conectando video…');

      final oldPc = _pc;
      _pc = null;
      if (oldPc != null) {
        try {
          await oldPc.close();
        } catch (_) {}
      }
      _queuedCandidates.clear();

      final pc = await createPeerConnection({
        'iceServers': widget.iceServers,
        'sdpSemantics': 'unified-plan',
      });
      _pc = pc;

      final stream = _localStream;
      if (stream != null) {
        for (final track in stream.getTracks()) {
          await pc.addTrack(track, stream);
        }
      }

      pc.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          widget.state.postVideoSignal(widget.appointment.id, 'candidate', {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }).then((error) {
            if (error != null) {
              debugPrint('ICE candidate POST failed: $error');
            }
          });
        }
      };
      pc.onTrack = (event) {
        if (event.streams.isNotEmpty && mounted) {
          _remoteRenderer.srcObject = event.streams[0];
          setState(() {
            _connected = true;
            _status = '';
          });
        }
      };
      pc.onConnectionState = (state) {
        if (_ended || !mounted) return;
        if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          setState(() => _status = '');
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          setState(() => _status = 'Conexión perdida. Reconectando…');
        }
      };

      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

      for (final candidate in _queuedCandidates) {
        try {
          await pc.addCandidate(candidate);
        } catch (e) {
          debugPrint('flush candidate failed. Error: $e');
        }
      }
      _queuedCandidates.clear();

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      final error = await widget.state.postVideoSignal(
          widget.appointment.id, 'answer', {'sdp': answer.sdp});

      if (error != null && mounted && !_ended) {
        // The professional will never see our answer: report it on screen
        // and allow a fresh session to start via the ready re-announce
        setState(() =>
            _status = 'No se pudo enviar la respuesta al servidor.\n$error');
        _lastOfferId = 0;
      }
    } catch (e, stack) {
      debugPrint('Error inside _handleOffer: $e\n$stack');
      if (mounted) {
        setState(() => _status = 'Error al conectar llamada: $e');
      }
    }
  }

  void _onRemoteHangup() {
    if (_ended) return;
    _ended = true;
    _pollTimer?.cancel();
    if (mounted) {
      setState(() {
        _connected = false;
        _status = 'El profesional finalizó la llamada.';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _hangUp() async {
    _ended = true;
    _pollTimer?.cancel();
    await widget.state.postVideoSignal(widget.appointment.id, 'hangup');
    if (mounted) Navigator.pop(context);
  }

  void _toggleMic() {
    final track = _localStream?.getAudioTracks().firstOrNull;
    if (track == null) return;
    track.enabled = !track.enabled;
    setState(() => _micOn = track.enabled);
  }

  void _toggleCam() {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track == null) return;
    track.enabled = !track.enabled;
    setState(() => _camOn = track.enabled);
  }

  Future<void> _switchCamera() async {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track != null) {
      await Helper.switchCamera(track);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (!_ended) {
      // Best effort: tell the other side we left
      widget.state.postVideoSignal(widget.appointment.id, 'hangup');
    }
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            Positioned.fill(
              child: _connected
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                                color: Color(0xFF2DD4BF), strokeWidth: 3),
                            const SizedBox(height: 22),
                            Text(
                              widget.appointment.professionalName ??
                                  'Profesional Aura',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _status,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            // Local preview
            Positioned(
              top: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 110,
                  height: 150,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
            // Controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlButton(
                    icon: _micOn ? Icons.mic : Icons.mic_off,
                    active: _micOn,
                    onTap: _toggleMic,
                  ),
                  const SizedBox(width: 16),
                  _controlButton(
                    icon: _camOn ? Icons.videocam : Icons.videocam_off,
                    active: _camOn,
                    onTap: _toggleCam,
                  ),
                  const SizedBox(width: 16),
                  _controlButton(
                    icon: Icons.cameraswitch,
                    active: true,
                    onTap: _switchCamera,
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _hangUp,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end,
                          color: Colors.white, size: 28),
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

  Widget _controlButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFF475569),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
