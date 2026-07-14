import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Registers this device for FCM push notifications and keeps the
/// backend's device-token registry in sync with the session. Every
/// entry point degrades to a no-op on unsupported platforms or when
/// Firebase is not configured, so callers can fire and forget.
class PushService {
  final ApiService apiService;

  /// Invoked when a push arrives while the app is in the foreground,
  /// so the UI can refresh the affected booking/chat.
  final void Function(Map<String, dynamic> data)? onForegroundMessage;

  bool _initialized = false;
  String? _currentToken;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  PushService({required this.apiService, this.onForegroundMessage});

  bool get _isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Call after a successful login or session restore.
  Future<void> register() async {
    if (!_isSupported) return;

    try {
      debugPrint('[Firebase Push] Intentando inicializar Firebase...');
      if (!_initialized) {
        await Firebase.initializeApp();
        _initialized = true;
      }

      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[Firebase Push] Permiso de notificaciones denegado por el usuario.');
        return;
      }

      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('[Firebase Push] Inicializado con éxito. FCM Token: $token');
        await _syncToken(token);
      }

      _refreshSubscription ??= messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[Firebase Push] Token FCM renovado: $newToken');
        _syncToken(newToken);
      });
      
      _messageSubscription ??= FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[Firebase Push] Mensaje recibido en primer plano: ${message.messageId}');
        onForegroundMessage?.call(message.data);
      });
    } catch (e) {
      // Missing google-services.json / Firebase not configured: skip silently
      debugPrint('[Firebase Push] Omisión de registro (Firebase no configurado o sin servicios de Google Play). Detalle: $e');
    }
  }

  Future<void> _syncToken(String token) async {
    _currentToken = token;
    try {
      await apiService.post('/device-tokens', body: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (e) {
      debugPrint('Device token sync failed (will retry on next login). Error: $e');
    }
  }

  /// Call on logout while the session token is still valid.
  Future<void> unregister() async {
    if (!_isSupported || !_initialized) return;

    try {
      if (_currentToken != null) {
        await apiService.delete('/device-tokens', body: {'token': _currentToken});
      }
      await FirebaseMessaging.instance.deleteToken();
      _currentToken = null;
    } catch (e) {
      debugPrint('Device token unregister failed. Error: $e');
    }
  }
}
