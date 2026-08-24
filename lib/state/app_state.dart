import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';
import '../models/appointment.dart';
import '../models/professional.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/mock_data.dart';
import '../models/clinical_service.dart';
import '../models/dependent.dart';
import '../models/lab_models.dart';
import '../models/saved_address.dart';
import '../models/saved_payment_method.dart';
import '../models/service_request.dart';
import '../models/chat_message.dart';
import '../models/past_service.dart';
import '../models/staff_models.dart';
import '../models/subscription_models.dart';
import '../models/zone_eta_estimate.dart';
import '../services/api_service.dart';
import '../services/locality_service.dart';
import '../services/db_helper.dart';
import '../services/outbox_service.dart';
import '../services/push_service.dart';
import '../utils/text_search.dart';

class AppState extends ChangeNotifier {
  // Base URL configuration for both local Web and Android Emulator
  // NOTA: Cambia el puerto '8000' en 'https://aura-salud.redirectme.net:8000/api' por el puerto externo abierto en tu router.
  // Override at build time with: --dart-define=API_BASE=https://tu-host/api
  // Physical-device debug/profile builds default to the ngrok tunnel so the
  // backend is reachable over HTTPS from any network.
  final String _baseUrl = const String.fromEnvironment('API_BASE').isNotEmpty
      ? const String.fromEnvironment('API_BASE')
      : 'https://aura-backend-v77n.onrender.com/api';

  // API Service
  late final ApiService _apiService;

  // Offline outbox (queued CRUD mutations replayed when back online)
  late final OutboxService _outboxService;

  // FCM push notifications
  late final PushService _pushService;

  // Secure storage for sensitive session tokens
  final _secureStorage = const FlutterSecureStorage();

  // Authentication state
  String? _authToken;
  String _userName = '';
  String _userEmail = '';
  bool _isDemoMode = false;
  bool _isRestoringSession = true;

  // Global App States
  String _activeTab = 'home';
  bool _isOnboarded = false;
  String _searchQuery = '';
  String _selectedFilterCategory = 'all'; // 'all' | 'require_rx' | 'no_rx'

  // Lists in state to support mutations.
  //
  // They start empty on purpose: preloading `mock_data` meant a brand-new user
  // saw somebody else's dependents, addresses and clinical history until the
  // API answered — and kept seeing them if it never did. The demo catalogue is
  // only injected by `enterDemoMode()`.
  //
  // The service catalogue is the exception: it is public, identical for
  // everyone, and needed to render the home screen before login.
  List<ClinicalService> _services = List.from(clinicalServices);
  final List<Dependent> _dependents = [];
  final List<SavedAddress> _addresses = [];
  final List<SavedPaymentMethod> _paymentMethods = [];
  final List<PastService> _pastServices = [];
  List<SubscriptionPlan> _subscriptionPlans = [];
  UserSubscriptionInfo? _subscriptionInfo;
  bool _isLoadingSubscription = false;

  // Form selection and active requests
  ClinicalService? _selectedService;
  ServiceRequest? _currentRequest;
  List<ServiceRequest> _activeRequests = [];
  String? _selectedChatRequestId;
  bool _isSearchingDoctor = false;

  // Canal clinico
  //
  // Los no leidos son por hilo, no uno solo. Con dos atenciones a la vez
  // —un medico y un kinesiologo— un unico contador solo podia hablar del hilo
  // que estabas mirando: entrar al del medico hacia desaparecer del globo los
  // mensajes sin leer del otro, no porque los hubieras leido sino porque el
  // contador no tenia sitio para los dos.
  final Map<String, int> _unreadByRequest = {};
  String _currentRole = 'patient'; // 'patient' | 'dependent_tutor' | 'doctor_provider' | 'operator_admin' | 'ambulance_driver'
  final List<ChatMessage> _chatMessages = [];

  // Simulator Parameters
  double _simulationSpeed = 1.0;
  int _doctorSearchTimeSeconds = 3;
  double _commissionRate = 0.15;

  // Sample roster used only by the guided demo, so exploring the app without
  // an account still shows a plausible assignment. Real provider management
  // lives in the operations panel and writes to the server.
  final List<Map<String, dynamic>> _systemProviders = [
    {
      'id': 'prof_camila_rivera',
      'name': 'Dra. Camila Rivera N.',
      'specialty': 'Medicina Interna',
      'status': 'Disponible', // 'Disponible' | 'Ocupado' | 'Desconectado'
      'phone': '+56 9 8812 3410',
    },
    {
      'id': 'prof_sebastian_leyton',
      'name': 'Dr. Sebastián Leyton',
      'specialty': 'Medicina General',
      'status': 'Disponible',
      'phone': '+56 9 7721 9831',
    },
    {
      'id': 'prof_maria_diaz',
      'name': 'Klga. María José Díaz',
      'specialty': 'Kinesiología',
      'status': 'Disponible',
      'phone': '+56 9 6610 2110',
    },
    {
      'id': 'prof_patricia_jara',
      'name': 'Enf. Patricia Jara',
      'specialty': 'Enfermería',
      'status': 'Disponible',
      'phone': '+56 9 5543 2120',
    },
  ];

  String? _assignedProfessionalName;
  String? _assignedProfessionalPhone;
  String? _assignedProfessionalSpecialty;
  ThemeMode _themeMode = ThemeMode.system;
  // Baseline above 1.0: a large share of patients are older adults, and the
  // default type sizes were reported as too small to use comfortably.
  double _textScaleFactor = 1.15;

  AppState() {
    _apiService = ApiService(
      baseUrl: _baseUrl,
      onUnauthorized: _handleUnauthorized,
    );
    _outboxService = OutboxService(
      apiService: _apiService,
      onFlushed: _onOutboxFlushed,
    );
    _outboxService.start();
    _pushService = PushService(
      apiService: _apiService,
      onForegroundMessage: _onPushMessage,
    );
    _initializeChat();
    _restoreSession();
  }

  /// Roles que tienen bandeja de staff que refrescar.
  bool get _esCuentaClinica => const [
        'doctor_provider',
        'operator_admin',
        'ambulance_driver',
      ].contains(_serverAssignedRole);

  // A push arrived with the app in foreground: refresh the affected data
  Future<void> _onPushMessage(Map<String, dynamic> data) async {
    // Un aviso de cola va dirigido a un profesional, no al paciente: lo que
    // hay que refrescar es la bandeja de staff, no la solicitud activa del
    // usuario. Sin esto el push llegaba y la pantalla seguia igual hasta el
    // sondeo de los quince segundos, que es justo la inmediatez que el aviso
    // venia a dar.
    if (data['type'] == 'cola') {
      if (_esCuentaClinica) {
        await refreshStaffArea();
      }
      return;
    }

    await fetchActiveRequest();
    if (_currentRequest != null && data['type'] == 'chat') {
      // No se suma aquí: `fetchChatMessages` recalcula los no leídos sobre el
      // hilo completo. Incrementar además duplicaba la cuenta cada vez que un
      // push llegaba con la app abierta.
      await fetchChatMessages(_currentRequest!.id);
    }
  }

  // After queued offline mutations reach the server, refresh synced lists
  Future<void> _onOutboxFlushed() async {
    await fetchDependents();
    await fetchAddresses();
    await fetchPaymentMethods();
    // A queued chat message may have just been delivered: pull the real thread
    // (with the provider's reply, if any) back from the backend.
    if (_currentRequest != null) {
      await fetchChatMessages(_currentRequest!.id);
    }
  }

  // Queue a CRUD mutation that failed offline (real accounts only;
  // demo mode keeps data local by design)
  Future<void> _queueOffline(String method, String path, [Object? body]) async {
    if (_authToken == null) return;
    await _outboxService.enqueue(method, path, body != null ? json.encode(body) : null);
  }

  // Global handler for token revocation (401 response)
  void _handleUnauthorized() {
    if (_authToken == null) return; // Prevent infinite loop
    stopActiveBookingStream();
    stopChatPolling();
    _authToken = null;
    _apiService.authToken = null;
    _userName = '';
    _userEmail = '';
    _isDemoMode = false;
    _currentRequest = null;
    _unreadByRequest.clear();
    _activeTab = 'home';
    _currentRole = 'patient';
    _serverAssignedRole = null;
    _initializeChat();
    _persistSession();
    DbHelper.instance.clearAll().catchError((e) => debugPrint('Error clearing local DB: $e'));
    notifyListeners();
  }

  // Restore a previously saved session token and load data
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme_mode');
      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.name == savedTheme,
          orElse: () => ThemeMode.system,
        );
      }
      // Older installs have no stored value; 1.15 is the new baseline so the
      // app is legible for older adults out of the box.
      _textScaleFactor = prefs.getDouble('text_scale_factor') ?? 1.15;
      _userAge = prefs.getInt('user_age');
      // Última comuna conocida: se pinta de inmediato y se refresca por detrás.
      _currentLocality = prefs.getString('last_locality');
      _safetyNoticeDismissed = prefs.getBool('safety_notice_dismissed') ?? false;
      _isOnboarded = prefs.getBool('is_onboarded') ?? false;
      final token = await _secureStorage.read(key: 'auth_token');
      if (token != null) {
        _authToken = token;
        _apiService.authToken = token;
        final prefs = await SharedPreferences.getInstance();
        _userName = prefs.getString('user_name') ?? '';
        _userEmail = prefs.getString('user_email') ?? '';
        
        final validated = await _validateSession();
        if (validated) {
          await _loadInitialData();
          _pushService.register();
        } else {
          _handleUnauthorized();
        }
      } else {
        // Fallback: migrate from legacy SharedPreferences if exists
        final prefs = await SharedPreferences.getInstance();
        final legacyToken = prefs.getString('auth_token');
        if (legacyToken != null) {
          _authToken = legacyToken;
          _apiService.authToken = legacyToken;
          _userName = prefs.getString('user_name') ?? '';
          _userEmail = prefs.getString('user_email') ?? '';
          
          // Migrate to secure storage and remove from prefs
          await _secureStorage.write(key: 'auth_token', value: legacyToken);
          await prefs.remove('auth_token');
          
          final validated = await _validateSession();
          if (validated) {
            await _loadInitialData();
            _pushService.register();
          } else {
            _handleUnauthorized();
          }
        } else {
          // Only the public catalog is available before login
          await fetchServices();
        }
      }
    } catch (e) {
      debugPrint('Session restore failed (network error). Loading local database cache. Error: $e');
      if (_authToken != null) {
        await _loadLocalDatabaseCache();
      }
    }
    _isRestoringSession = false;
    notifyListeners();
  }

  Future<void> _loadLocalDatabaseCache() async {
    try {
      _dependents.clear();
      _dependents.addAll(await DbHelper.instance.getDependents());
      
      _addresses.clear();
      _addresses.addAll(await DbHelper.instance.getAddresses());
      
      _paymentMethods.clear();
      _paymentMethods.addAll(await DbHelper.instance.getPaymentMethods());
      
      _pastServices.clear();
      _pastServices.addAll(await DbHelper.instance.getPastServices());
      
      final activeBookings = await DbHelper.instance.getBookings();
      final active = activeBookings.where((b) => b.status != RequestStatus.completed && b.status != RequestStatus.cancelled).toList();
      if (active.isNotEmpty) {
        _currentRequest = active.first;
        startActiveBookingStream(_currentRequest!.id);
        _chatMessages.clear();
        _chatMessages.addAll(await DbHelper.instance.getChatMessages(_currentRequest!.id));
        _restartChatPolling();
      } else {
        _currentRequest = null;
        stopChatPolling();
      }
    } catch (e) {
      debugPrint('Error loading local SQLite cache: $e');
    }
  }

  Future<bool> _validateSession() async {
    try {
      final response = await _apiService.get('/auth/me', timeout: const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _userName = data['name'] ?? _userName;
        _userEmail = data['email'] ?? _userEmail;
        _applyServerRole(data['role'] as String?);
        return true;
      }
      return false; // Will trigger _handleUnauthorized if 401
    } catch (e) {
      debugPrint('Offline or connection error during session validation. Retaining session. Error: $e');
      return true; // Keep local session offline fallback
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_authToken != null) {
      await _secureStorage.write(key: 'auth_token', value: _authToken!);
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_email', _userEmail);
    } else {
      await _secureStorage.delete(key: 'auth_token');
      await prefs.remove('auth_token'); // Ensure legacy token is deleted
      await prefs.remove('user_name');
      await prefs.remove('user_email');
    }
  }

  // Register a new account. Returns null on success or an error message.
  Future<String?> register(String name, String email, String password) async {
    try {
      final response = await _apiService.post(
        '/auth/register',
        body: {'name': name, 'email': email, 'password': password},
        timeout: const Duration(seconds: 6),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 201) {
        _applyAuthResponse(data);
        return null;
      }
      return data['message'] ?? 'No se pudo crear la cuenta.';
    } catch (e) {
      debugPrint('Backend register failed. Error: $e');
      return 'No se pudo conectar con el servidor. Verifica tu conexión o usa el modo demo.';
    }
  }

  // Log in with existing credentials. Returns null on success or an error message.
  Future<String?> login(String email, String password) async {
    try {
      final response = await _apiService.post(
        '/auth/login',
        body: {'email': email, 'password': password},
        timeout: const Duration(seconds: 6),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200) {
        _applyAuthResponse(data);
        return null;
      }
      return data['message'] ?? 'Las credenciales ingresadas no son válidas.';
    } catch (e) {
      debugPrint('Backend login failed. Error: $e');
      return 'No se pudo conectar con el servidor. Verifica tu conexión o usa el modo demo.';
    }
  }

  // Sign in with Google and exchange the verified id_token with the
  // backend. Returns null on success or an error message.
  Future<String?> loginWithGoogle() async {
    final String? idToken;
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleServerClientId.isNotEmpty
            ? AppConfig.googleServerClientId
            : (const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID') == ''
                ? null
                : const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID')),
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        return null; // User dismissed the picker: not an error
      }
      idToken = (await account.authentication).idToken;
    } catch (e) {
      debugPrint('Google Sign-In failed. Error: $e');
      return 'Google Sign-In no está disponible en esta build. Usa correo y contraseña.';
    }

    if (idToken == null) {
      return 'No se pudo obtener la credencial de Google. Intenta de nuevo.';
    }

    return _loginWithSocialCredential('google', idToken);
  }

  // Sign in with Facebook and exchange the access token with the backend.
  // Returns null on success or an error message.
  Future<String?> loginWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken? accessToken = result.accessToken;
        if (accessToken != null) {
          return _loginWithSocialCredential('facebook', accessToken.tokenString);
        }
      } else if (result.status == LoginStatus.cancelled) {
        return null; // User cancelled
      }
      return 'No se pudo iniciar sesión con Facebook (Estado: ${result.status})';
    } catch (e) {
      debugPrint('Facebook Sign-In failed. Error: $e');
      return 'Facebook Sign-In no está disponible en esta build. Usa correo y contraseña.';
    }
  }

  // Exchange a provider credential for an Aura session token.
  Future<String?> _loginWithSocialCredential(String provider, String credential) async {
    try {
      final response = await _apiService.post(
        '/auth/social',
        body: {
          'provider': provider,
          'credential': credential,
        },
        timeout: const Duration(seconds: 15),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _applyAuthResponse(data);
        return null;
      }
      return data['message'] ?? 'No se pudo iniciar sesión con $provider.';
    } catch (e) {
      debugPrint('Backend social login failed. Error: $e');
      return 'No se pudo conectar con el servidor ($e). Verifica tu conexión o intenta nuevamente.';
    }
  }

  void _applyAuthResponse(Map<String, dynamic> data) {
    _authToken = data['token'];
    _apiService.authToken = _authToken;
    _userName = data['user']?['name'] ?? '';
    _userEmail = data['user']?['email'] ?? '';
    // The backend owns the role: test accounts land straight on the dashboard
    // that matches them instead of relying on the manual role switcher.
    _applyServerRole(data['user']?['role'] as String?);
    _isDemoMode = false;
    _persistSession();
    _loadInitialData();
    _pushService.register();
    notifyListeners();
  }

  // Explore the app without a backend account (local simulation only).
  // This is the only path that loads the sample catalogue.
  void enterDemoMode() {
    _isDemoMode = true;
    _userName = 'Usuario Demo';
    _userEmail = 'demo@aurasalud.app';

    _dependents
      ..clear()
      ..addAll(initialDependents);
    _addresses
      ..clear()
      ..addAll(initialAddresses);
    _paymentMethods
      ..clear()
      ..addAll(initialPaymentMethods);
    _pastServices
      ..clear()
      ..addAll(pastServicesHistory);

    notifyListeners();
  }

  Future<void> logout() async {
    // Remove this device from push notifications while the token is valid
    await _pushService.unregister();
    try {
      await _apiService.post('/auth/logout', timeout: const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Backend logout failed (token cleared locally). Error: $e');
    }
    stopActiveBookingStream();
    stopChatPolling();
    _authToken = null;
    _apiService.authToken = null;
    _userName = '';
    _userEmail = '';
    _isDemoMode = false;
    _isOnboarded = false;
    _currentRequest = null;
    _unreadByRequest.clear();
    _activeTab = 'home';
    _currentRole = 'patient';
    _serverAssignedRole = null;
    _initializeChat();
    await _persistSession();
    await DbHelper.instance.clearAll();
    notifyListeners();
  }

  // Load backend data on startup
  Future<void> _loadInitialData() async {
    // Deliver any mutations queued while offline before refreshing lists
    await _outboxService.flush();
    await fetchServices();
    await fetchDependents();
    await fetchAddresses();
    await fetchPaymentMethods();
    await fetchActiveRequest();
    await fetchHistory();
    await fetchSubscriptionPlans();
    await fetchCurrentSubscription();
  }

  // Getters
  bool get isAuthenticated => _authToken != null || _isDemoMode;
  bool get isDemoMode => _isDemoMode;
  bool get isRestoringSession => _isRestoringSession;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get activeTab => _activeTab;
  bool get isOnboarded => _isOnboarded;
  String get searchQuery => _searchQuery;
  String get selectedFilterCategory => _selectedFilterCategory;

  List<SubscriptionPlan> get subscriptionPlans => _subscriptionPlans;
  UserSubscriptionInfo? get subscriptionInfo => _subscriptionInfo;
  bool get hasActiveSubscription => _subscriptionInfo?.hasSubscription ?? false;
  bool get isLoadingSubscription => _isLoadingSubscription;

  List<ClinicalService> get services => _services;
  List<Dependent> get dependents => _dependents;
  List<SavedAddress> get addresses => _addresses;
  List<SavedPaymentMethod> get paymentMethods => _paymentMethods;
  List<PastService> get pastServices => _pastServices;

  ClinicalService? get selectedService => _selectedService;
  List<ServiceRequest> get activeRequests => _activeRequests;
  String? get selectedChatRequestId => _selectedChatRequestId;
  ServiceRequest? get currentRequest {
    if (_selectedChatRequestId != null) {
      final match = _activeRequests.where((r) => r.id == _selectedChatRequestId).toList();
      if (match.isNotEmpty) return match.first;
    }
    if (_activeRequests.isNotEmpty) return _activeRequests.first;
    return _currentRequest;
  }
  bool get isSearchingDoctor => _isSearchingDoctor;

  /// Cambia la conversacion activa del chat al profesional de otra solicitud
  Future<void> selectChatRequest(String requestId) async {
    _selectedChatRequestId = requestId;
    final match = _activeRequests.where((r) => r.id == requestId).toList();
    if (match.isNotEmpty) {
      _currentRequest = match.first;
    }
    startActiveBookingStream(requestId);
    await fetchChatMessages(requestId);
    _restartChatPolling();
    notifyListeners();
  }

  /// Total para el globo de la pestana Mensajes: la suma de todos los hilos.
  int get pendingMessages =>
      _unreadByRequest.values.fold(0, (total, n) => total + n);

  /// Sin leer en un hilo concreto, para el punto de cada pestana de profesional.
  int unreadFor(String requestId) => _unreadByRequest[requestId] ?? 0;
  String get currentRole => _currentRole;
  List<ChatMessage> get chatMessages => _chatMessages;

  double get simulationSpeed => _simulationSpeed;
  int get doctorSearchTimeSeconds => _doctorSearchTimeSeconds;
  double get commissionRate => _commissionRate;
  bool get simulateOffline => _apiService.simulateOffline;

  String? get assignedProfessionalName => _assignedProfessionalName;
  String? get assignedProfessionalPhone => _assignedProfessionalPhone;
  String? get assignedProfessionalSpecialty => _assignedProfessionalSpecialty;
  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;

  // Filtered Services List
  //
  // The search is accent- and case-insensitive and matches every typed word
  // against the title, subtitle, description and a list of common synonyms,
  // so "medico", "Médico", "MEDICO" and "doctor" all return the same result.
  List<ClinicalService> get filteredServices {
    return _services.where((service) {
      final matches = matchesSearch(_searchQuery, [
        service.id,
        service.title,
        service.shortTitle,
        service.subtitle,
        service.description,
        ...?serviceSearchAliases[service.id],
      ]);

      if (_selectedFilterCategory == 'require_rx') {
        return matches && service.requiresPrescription;
      }
      if (_selectedFilterCategory == 'no_rx') {
        return matches && !service.requiresPrescription;
      }
      return matches;
    }).toList();
  }

  // API Fetching methods
  Future<void> fetchServices() async {
    try {
      final response = await _apiService.get('/services');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _services = data.map((s) => ClinicalService.fromJson(s)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchServices failed, using mock data. Error: $e');
    }
  }

  Future<void> fetchDependents() async {
    try {
      final response = await _apiService.get('/dependents');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _dependents.clear();
        _dependents.addAll(data.map((d) => Dependent.fromJson(d)).toList());
        try {
          await DbHelper.instance.saveDependents(_dependents);
        } catch (dbErr) {
          debugPrint('Local SQLite saveDependents warning: $dbErr');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchDependents failed, loading from local DB. Error: $e');
      try {
        final localDeps = await DbHelper.instance.getDependents();
        if (localDeps.isNotEmpty) {
          _dependents.clear();
          _dependents.addAll(localDeps);
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  Future<void> fetchAddresses() async {
    try {
      final response = await _apiService.get('/addresses');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _addresses.clear();
        _addresses.addAll(data.map((a) => SavedAddress.fromJson(a)).toList());
        try {
          await DbHelper.instance.saveAddresses(_addresses);
        } catch (dbErr) {
          debugPrint('Local SQLite saveAddresses warning: $dbErr');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchAddresses failed, loading from local DB. Error: $e');
      try {
        final localAddrs = await DbHelper.instance.getAddresses();
        if (localAddrs.isNotEmpty) {
          _addresses.clear();
          _addresses.addAll(localAddrs);
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  Future<void> fetchPaymentMethods() async {
    try {
      final response = await _apiService.get('/payment-methods');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _paymentMethods.clear();
        _paymentMethods.addAll(data.map((p) => SavedPaymentMethod.fromJson(p)).toList());
        try {
          await DbHelper.instance.savePaymentMethods(_paymentMethods);
        } catch (dbErr) {
          debugPrint('Local SQLite savePaymentMethods warning: $dbErr');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchPaymentMethods failed, loading from local DB. Error: $e');
      try {
        final localPays = await DbHelper.instance.getPaymentMethods();
        if (localPays.isNotEmpty) {
          _paymentMethods.clear();
          _paymentMethods.addAll(localPays);
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  /// True cuando el cuerpo de `/bookings/active` significa "no hay ninguna".
  ///
  /// El servidor **nunca manda `null`**: la `JsonResponse` de Symfony convierte
  /// un null en `{}`. La comprobación anterior era `body != 'null'`, así que
  /// cada vez que el paciente no tenía solicitud activa la app intentaba
  /// parsear `{}`, lanzaba excepción y se iba al `catch` a leer la caché local.
  /// Es decir, "no tienes nada" se trataba como un fallo de red y la app
  /// confiaba en datos viejos del teléfono.
  bool _isEmptyActiveResponse(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == '{}' || trimmed == '[]') {
      return true;
    }
    try {
      final decoded = json.decode(trimmed);
      return decoded == null || (decoded is Map && decoded['id'] == null);
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchActiveRequest() async {
    try {
      debugPrint('[CHAT-DEBUG] fetchActiveRequest → GET /bookings/active-all');
      http.Response response;
      try {
        response = await _apiService.get('/bookings/active-all');
        if (response.statusCode != 200) {
          response = await _apiService.get('/bookings/active');
        }
      } catch (_) {
        response = await _apiService.get('/bookings/active');
      }

      debugPrint('[CHAT-DEBUG] fetchActiveRequest status=${response.statusCode}, '
          'bodyLen=${response.body.length}, body=${response.body.substring(0, response.body.length.clamp(0, 300))}');

      if (response.statusCode == 200 && !_isEmptyActiveResponse(response.body)) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> list = decoded is List ? decoded : [decoded];
        _activeRequests = list
            .where((item) => item is Map && item['id'] != null)
            .map((item) => ServiceRequest.fromJson(item as Map<String, dynamic>))
            .toList();

        if (_activeRequests.isNotEmpty) {
          if (_selectedChatRequestId == null ||
              !_activeRequests.any((r) => r.id == _selectedChatRequestId)) {
            _selectedChatRequestId = _activeRequests.first.id;
          }
          _currentRequest = _activeRequests.firstWhere(
            (r) => r.id == _selectedChatRequestId,
            orElse: () => _activeRequests.first,
          );
          debugPrint('[CHAT-DEBUG] fetchActiveRequest ✓ ${_activeRequests.length} active request(s), '
              'selected id=${_currentRequest!.id} status=${_currentRequest!.status}');

          try {
            await DbHelper.instance.saveBookings(_activeRequests);
          } catch (dbErr) {
            debugPrint('[CHAT-DEBUG] Local SQLite saveBookings warning: $dbErr');
          }

          startActiveBookingStream(_currentRequest!.id);
          await fetchChatMessages(_currentRequest!.id);
          // Estado inicial de los puntos de las otras atenciones.
          await refreshUnreadSummary();
          _restartChatPolling();
        } else {
          _handleNoActiveRequests();
        }
      } else {
        _handleNoActiveRequests();
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('[CHAT-DEBUG] fetchActiveRequest EXCEPTION: $e');
      debugPrint('[CHAT-DEBUG] fetchActiveRequest stackTrace: ${st.toString().substring(0, st.toString().length.clamp(0, 500))}');
      try {
        final localBookings = await DbHelper.instance.getBookings();
        final active = localBookings
            .where((b) => b.status != RequestStatus.completed && b.status != RequestStatus.cancelled)
            .toList();
        if (active.isNotEmpty) {
          _activeRequests = active;
          if (_selectedChatRequestId == null || !_activeRequests.any((r) => r.id == _selectedChatRequestId)) {
            _selectedChatRequestId = active.first.id;
          }
          _currentRequest = _activeRequests.firstWhere(
            (r) => r.id == _selectedChatRequestId,
            orElse: () => _activeRequests.first,
          );
          debugPrint('[CHAT-DEBUG] fetchActiveRequest fallback to local: id=${_currentRequest!.id}');
          startActiveBookingStream(_currentRequest!.id);
          await fetchChatMessages(_currentRequest!.id);
          _restartChatPolling();
        } else {
          _handleNoActiveRequests();
        }
      } catch (localErr) {
        debugPrint('[CHAT-DEBUG] Local fallback failed: $localErr');
        _handleNoActiveRequests();
      }
      notifyListeners();
    }
  }

  void _handleNoActiveRequests() {
    debugPrint('[CHAT-DEBUG] fetchActiveRequest → empty/null response');
    stopActiveBookingStream();
    stopChatPolling();
    _activeRequests.clear();
    _selectedChatRequestId = null;

    if (_currentRequest != null &&
        _currentRequest!.status != RequestStatus.completed &&
        _currentRequest!.status != RequestStatus.cancelled) {
      // Mantener visible el estado completado y evaluación antes de salir al inicio.
      _currentRequest = _currentRequest!.copyWith(
        status: RequestStatus.completed,
        currentStep: 4,
      );
    } else if (_currentRequest?.status != RequestStatus.completed) {
      _currentRequest = null;
      _chatMessages.clear();
      _unreadByRequest.clear();
      try {
        DbHelper.instance.saveBookings([]);
      } catch (_) {}
    }
  }

  /// True cuando dos hilos son el mismo mensaje a mensaje.
  ///
  /// Con el chat abierto esto se consulta cada pocos segundos y `notifyListeners`
  /// repinta el árbol entero: sin esta comparación, la app se reconstruiría en
  /// bucle aunque no hubiera llegado nada.
  bool _sameThread(List<ChatMessage> a, List<ChatMessage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].text != b[i].text ||
          a[i].sender != b[i].sender ||
          a[i].senderName != b[i].senderName) {
        return false;
      }
    }
    return true;
  }

  // ------------------------------------------- estado de la atencion en vivo
  //
  // El estado de la reserva solo se actualizaba por el stream SSE. Cuando ese
  // stream no entrega —un proxy que almacena en bufer, la conexion que muere
  // con el telefono en segundo plano, la ventana de reconexion— la pantalla de
  // seguimiento se quedaba congelada en el estado que tenia al abrirla, que
  // para el paciente recien pagado es "Confirmado". El profesional salia,
  // llegaba y cerraba la atencion desde el portal, y en el telefono no se movia
  // nada. Es exactamente lo que ya habia pasado con el hilo del chat: un solo
  // camino en vivo, sin nadie que preguntara si ese camino seguia abierto.
  //
  // Con esto el SSE pasa a ser una mejora —llega antes— y no un requisito.

  DateTime? _ultimoSondeoEstado;
  static const _cadaCuantoEstado = Duration(seconds: 5);

  /// Vuelve a pedir las atenciones abiertas y actualiza sus estados.
  ///
  /// Deliberadamente ligero: no reabre streams, no recarga el hilo y no toca
  /// los temporizadores salvo cuando la atencion se cierra. `fetchActiveRequest`
  /// hace todo eso y llamarlo desde el propio temporizador lo reiniciaria en
  /// cada vuelta.
  Future<void> refreshActiveStatuses({bool forzar = false}) async {
    if (_authToken == null || _activeRequests.isEmpty) return;

    final ahora = DateTime.now();
    if (!forzar &&
        _ultimoSondeoEstado != null &&
        ahora.difference(_ultimoSondeoEstado!) < _cadaCuantoEstado) {
      return;
    }
    _ultimoSondeoEstado = ahora;

    try {
      final response = await _apiService.get('/bookings/active-all');
      if (response.statusCode != 200) return;

      final decoded = json.decode(response.body);
      if (decoded is! List) return;

      final frescas = decoded
          .where((item) => item is Map && item['id'] != null)
          .map((item) => ServiceRequest.fromJson(item as Map<String, dynamic>))
          .toList();

      final anterior = _currentRequest?.status;
      final previas = {for (final r in _activeRequests) r.id: r};

      // Las que ya no vienen es que se cerraron o se anularon.
      var cambio = frescas.length != _activeRequests.length;

      for (final fresca in frescas) {
        final vieja = previas[fresca.id];
        if (vieja == null ||
            vieja.status != fresca.status ||
            vieja.currentStep != fresca.currentStep ||
            vieja.professionalLat != fresca.professionalLat ||
            vieja.professionalLng != fresca.professionalLng ||
            vieja.professionalName != fresca.professionalName) {
          cambio = true;
        }
      }

      if (!cambio) return;

      _activeRequests = frescas;

      if (frescas.isEmpty) {
        // La ultima atencion se cerro mientras mirabas.
        if (_currentRequest != null &&
            _currentRequest!.status != RequestStatus.completed &&
            _currentRequest!.status != RequestStatus.cancelled) {
          _currentRequest = _currentRequest!.copyWith(
            status: RequestStatus.completed,
            currentStep: 4,
          );
          _activeRequests.clear();
          stopChatPolling();
          stopActiveBookingStream();
          await fetchHistory();
          notifyListeners();
          return;
        } else if (_currentRequest?.status == RequestStatus.completed) {
          return;
        }
        _currentRequest = null;
        stopChatPolling();
        stopActiveBookingStream();
        await fetchHistory();
        notifyListeners();
        return;
      }

      final porId = {for (final r in frescas) r.id: r};
      _currentRequest = porId[_selectedChatRequestId] ?? frescas.first;
      _selectedChatRequestId = _currentRequest!.id;

      try {
        await DbHelper.instance.saveBookings(_activeRequests);
      } catch (dbErr) {
        debugPrint('saveBookings tras sondeo de estado: $dbErr');
      }

      // Las mismas consecuencias que aplica el stream, para que el paciente vea
      // lo mismo llegue la noticia por donde llegue.
      if (anterior != _currentRequest!.status) {
        if (_currentRequest!.status == RequestStatus.completed) {
          await fetchHistory();
        }
        _restartChatPolling();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('refreshActiveStatuses failed. Error: $e');
    }
  }

  Future<void> fetchChatMessages(String requestId) async {
    try {
      debugPrint('[CHAT-DEBUG] fetchChatMessages → GET /bookings/$requestId/chat');
      final response = await _apiService.get('/bookings/$requestId/chat');
      debugPrint('[CHAT-DEBUG] fetchChatMessages status=${response.statusCode}, '
          'bodyLen=${response.body.length}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('[CHAT-DEBUG] fetchChatMessages parsed ${data.length} messages');
        final incoming =
            data.map((m) => ChatMessage.fromJson(m)).toList();
        if (_sameThread(_chatMessages, incoming)) {
          debugPrint('[CHAT-DEBUG] fetchChatMessages → same thread, skipping update');
          return;
        }

        debugPrint('[CHAT-DEBUG] fetchChatMessages → NEW messages detected! '
            'old=${_chatMessages.length} new=${incoming.length}');
        for (final m in incoming) {
          debugPrint('[CHAT-DEBUG]   msg id=${m.id} sender=${m.sender} '
              'senderName=${m.senderName} text="${m.text.substring(0, m.text.length.clamp(0, 60))}"');
        }

        _chatMessages
          ..clear()
          ..addAll(incoming);
        try {
          await DbHelper.instance.saveChatMessages(requestId, _chatMessages);
        } catch (dbErr) {
          debugPrint('[CHAT-DEBUG] Local SQLite saveChatMessages warning: $dbErr');
        }
        await _refreshUnreadCount(requestId);
        notifyListeners();
      } else {
        debugPrint('[CHAT-DEBUG] fetchChatMessages non-200: ${response.statusCode} body=${response.body.substring(0, response.body.length.clamp(0, 200))}');
      }
    } catch (e, st) {
      debugPrint('[CHAT-DEBUG] fetchChatMessages EXCEPTION: $e');
      debugPrint('[CHAT-DEBUG] fetchChatMessages stackTrace: ${st.toString().substring(0, st.toString().length.clamp(0, 400))}');
      final localMsgs = await DbHelper.instance.getChatMessages(requestId);
      if (localMsgs.isNotEmpty) {
        _chatMessages.clear();
        _chatMessages.addAll(localMsgs);
        await _refreshUnreadCount(requestId);
        notifyListeners();
      }
    }
  }

  // -------------------------------------------------- mensajes sin leer
  //
  // Primero fue un `_pendingMessages = 1` escrito a mano en tres sitios al
  // confirmar una solicitud. Siempre decía 1 —daba igual que el servidor
  // hubiese creado dos mensajes de apertura o que llegaran seis— y se borraba
  // al abrir la pestaña, hubieras leído o no.
  //
  // Despues fue un unico contador correcto, pero de un solo hilo. Con varias
  // atenciones a la vez volvia a mentir por otro motivo: solo sabia hablar de
  // la conversacion que tenias abierta.

  /// Cuantos mensajes del hilo ya vio el paciente, por solicitud.
  ///
  /// Se guarda un numero y no el id del ultimo visto porque asi se puede saber
  /// lo que falta por leer en los hilos que no estan cargados: el servidor
  /// dice cuantos lleva cada atencion (`/bookings/unread-summary`) y la resta
  /// da el pendiente, sin descargar cada conversacion entera en cada sondeo.
  ///
  /// La primera vez tras actualizar no existe la marca y todo cuenta como
  /// nuevo. Es deliberado: pasarse contando avisa de mas una vez, quedarse
  /// corto esconde un mensaje del profesional.
  static String _seenKey(String requestId) => 'seen_count_$requestId';

  int _fromProvider(List<ChatMessage> mensajes) =>
      mensajes.where((m) => m.sender != 'patient').length;

  /// Recalcula los no leidos del hilo que esta cargado en memoria.
  Future<void> _refreshUnreadCount(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final vistos = prefs.getInt(_seenKey(requestId)) ?? 0;
    final recibidos = _fromProvider(_chatMessages);

    // Nunca negativo: un mensaje borrado en el servidor no puede dejar el
    // contador por debajo de cero.
    final pendiente = recibidos - vistos;
    _unreadByRequest[requestId] = pendiente > 0 ? pendiente : 0;

    // Si ya esta mirando ese chat, no tiene sentido marcarle un pendiente.
    // Con una sola atencion `_selectedChatRequestId` puede seguir en null, y
    // entonces el hilo abierto es sencillamente el actual.
    final abierto = _selectedChatRequestId ?? _currentRequest?.id;
    if (_activeTab == 'messages' &&
        abierto == requestId &&
        _unreadByRequest[requestId]! > 0) {
      await markMessagesRead();
    }
  }

  /// Lo que falta por leer en las demas atenciones abiertas.
  ///
  /// Solo se pregunta con mas de una atencion en curso: con una sola, el hilo
  /// que ya esta cargado contesta lo mismo sin pedirle nada al servidor.
  Future<void> refreshUnreadSummary() async {
    if (_authToken == null || _activeRequests.length < 2) return;

    try {
      final response = await _apiService.get('/bookings/unread-summary');
      if (response.statusCode != 200) return;

      final List<dynamic> data = json.decode(response.body);
      final prefs = await SharedPreferences.getInstance();

      for (final fila in data) {
        if (fila is! Map) continue;
        final id = '${fila['booking_id']}';
        // El hilo abierto se cuenta con lo que hay en memoria, que esta mas
        // fresco que este resumen.
        if (id == _selectedChatRequestId) continue;

        final recibidos = int.tryParse('${fila['from_provider'] ?? 0}') ?? 0;
        final vistos = prefs.getInt(_seenKey(id)) ?? 0;
        final pendiente = recibidos - vistos;
        _unreadByRequest[id] = pendiente > 0 ? pendiente : 0;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('refreshUnreadSummary failed. Error: $e');
    }
  }

  /// Marca como leido el hilo que el paciente tiene abierto.
  Future<void> markMessagesRead() async {
    final requestId = _selectedChatRequestId ?? _currentRequest?.id;
    if (requestId == null) {
      notifyListeners();
      return;
    }

    _unreadByRequest[requestId] = 0;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seenKey(requestId), _fromProvider(_chatMessages));
  }

  // -------------------------------------------------- refresco del hilo
  //
  // El unico camino en vivo para un mensaje del profesional era el stream SSE
  // de la reserva. Cuando ese stream no llegaba —un proxy que almacena en
  // bufer, el max_execution_time de PHP cortando el bucle de 50 s, la app
  // volviendo de segundo plano con el socket muerto— el paciente no volvia a
  // pedir el hilo nunca: abrir la pestana de mensajes no hacia ninguna
  // llamada. Eso es exactamente lo que se veia desde el portal: el
  // profesional escribe y al paciente no le llega nada.
  //
  // El portal resuelve lo mismo consultando cada 2 s. Aqui se hace igual, con
  // dos ritmos para no gastar bateria cuando el chat no esta a la vista.

  Timer? _chatPollTimer;
  bool _chatScreenVisible = false;

  static const _chatPollVisible = Duration(seconds: 2);
  static const _chatPollHidden = Duration(seconds: 5);

  /// La pantalla de chat avisa cuando se monta y cuando se va.
  void setChatScreenVisible(bool visible) {
    _chatScreenVisible = visible;
    _restartChatPolling();
    if (visible) refreshChatNow();
  }

  /// Pide el hilo al servidor ahora mismo: al abrir el chat y al volver la app
  /// a primer plano. Si falla, `fetchChatMessages` cae a la copia local y el
  /// timer lo reintenta.
  Future<void> refreshChatNow() async {
    final requestId = _currentRequest?.id;
    if (requestId == null || _authToken == null) return;
    await fetchChatMessages(requestId);
    // Sin esperar a la siguiente vuelta del temporizador: abrir la pantalla es
    // justo cuando el paciente quiere ver el estado de ahora.
    await refreshActiveStatuses(forzar: true);
  }

  void _restartChatPolling() {
    _chatPollTimer?.cancel();
    _chatPollTimer = null;

    final request = _currentRequest;
    // Sin sesion o sin atencion en curso no hay canal que consultar; cerrada o
    // anulada la atencion, tampoco.
    if (request == null || _authToken == null) return;
    if (request.status == RequestStatus.completed ||
        request.status == RequestStatus.cancelled) {
      return;
    }

    final every = _chatScreenVisible ? _chatPollVisible : _chatPollHidden;
    _chatPollTimer = Timer.periodic(every, (_) {
      fetchChatMessages(request.id);
      // Y el estado de la atencion, que hasta aqui solo llegaba por SSE. Se
      // limita solo a si mismo a una vez cada cinco segundos, asi que subir el
      // ritmo del chat cuando la pantalla esta a la vista no lo arrastra.
      refreshActiveStatuses();
      // Y lo que falta por leer en las otras atenciones. `refreshUnreadSummary`
      // no pide nada cuando solo hay una en curso, asi que el caso habitual no
      // paga ninguna llamada extra.
      refreshUnreadSummary();
    });
  }

  void stopChatPolling() {
    _chatPollTimer?.cancel();
    _chatPollTimer = null;
  }

  /// La app vuelve del segundo plano: el stream SSE ya murio y pueden haber
  /// entrado mensajes mientras tanto. `fetchActiveRequest` reabre el stream,
  /// trae el hilo y reanuda el polling.
  Future<void> handleAppResumed() async {
    if (_authToken == null) return;
    await fetchActiveRequest();
  }

  Future<void> fetchHistory() async {
    try {
      final response = await _apiService.get('/history');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _pastServices.clear();
        _pastServices.addAll(data.map((p) => PastService.fromJson(p)).toList());
        await DbHelper.instance.savePastServices(_pastServices);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchHistory failed, loading from local DB. Error: $e');
      final localPast = await DbHelper.instance.getPastServices();
      if (localPast.isNotEmpty) {
        _pastServices.clear();
        _pastServices.addAll(localPast);
        notifyListeners();
      }
    }
  }

  // Setters & Actions
  void setTab(String tab) {
    _activeTab = tab;
    notifyListeners();

    // Abrir la pestaña marca el hilo como leído hasta el último mensaje, y lo
    // persiste. Antes solo se ponía el contador a cero en memoria: al volver a
    // abrir la app el globo reaparecía o no según el azar.
    if (tab == 'messages') {
      markMessagesRead();
    }
  }

  void setOnboarded(bool value) {
    _isOnboarded = value;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('is_onboarded', value);
    }).catchError((_) {});
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setFilterCategory(String category) {
    _selectedFilterCategory = category;
    notifyListeners();
  }

  Future<void> addDependent(Dependent dep) async {
    // 1. Local optimistic update
    _dependents.add(dep);
    await DbHelper.instance.saveDependents(_dependents);
    notifyListeners();

    // 2. Sync with backend
    try {
      final response = await _apiService.post('/dependents', body: dep.toJson());
      if (response.statusCode == 201) {
        await fetchDependents();
      }
    } catch (e) {
      debugPrint('Backend addDependent failed, kept in local memory & SQLite. Error: $e');
      await _queueOffline('POST', '/dependents', dep.toJson());
    }
  }

  Future<void> updateDependent(Dependent dep) async {
    final idx = _dependents.indexWhere((d) => d.id == dep.id);
    if (idx != -1) {
      _dependents[idx] = dep;
      await DbHelper.instance.saveDependents(_dependents);
      notifyListeners();
    }

    try {
      final response = await _apiService.put('/dependents/${dep.id}', body: dep.toJson());
      if (response.statusCode == 200) {
        await fetchDependents();
      }
    } catch (e) {
      debugPrint('Backend updateDependent failed, kept in local memory & SQLite. Error: $e');
      await _queueOffline('PUT', '/dependents/${dep.id}', dep.toJson());
    }
  }

  Future<void> deleteDependent(String id) async {
    // 1. Local update
    _dependents.removeWhere((d) => d.id == id);
    await DbHelper.instance.saveDependents(_dependents);
    notifyListeners();

    // 2. Sync with backend
    try {
      final response = await _apiService.delete('/dependents/$id');
      if (response.statusCode == 200) {
        await fetchDependents();
      }
    } catch (e) {
      debugPrint('Backend deleteDependent failed, removed locally & SQLite. Error: $e');
      await _queueOffline('DELETE', '/dependents/$id');
    }
  }

  Future<void> addAddress(SavedAddress addr) async {
    // 1. Local update
    _addresses.add(addr);
    await DbHelper.instance.saveAddresses(_addresses);
    notifyListeners();

    // 2. Sync with backend
    try {
      final response = await _apiService.post('/addresses', body: addr.toJson());
      if (response.statusCode == 201) {
        await fetchAddresses();
      }
    } catch (e) {
      debugPrint('Backend addAddress failed, kept in local memory & SQLite. Error: $e');
      await _queueOffline('POST', '/addresses', addr.toJson());
    }
  }

  Future<void> updateAddress(SavedAddress addr) async {
    final idx = _addresses.indexWhere((a) => a.id == addr.id);
    if (idx != -1) {
      _addresses[idx] = addr;
      await DbHelper.instance.saveAddresses(_addresses);
      notifyListeners();
    }

    try {
      final response = await _apiService.put('/addresses/${addr.id}', body: addr.toJson());
      if (response.statusCode == 200) {
        await fetchAddresses();
      }
    } catch (e) {
      debugPrint('Backend updateAddress failed, kept in local memory & SQLite. Error: $e');
      await _queueOffline('PUT', '/addresses/${addr.id}', addr.toJson());
    }
  }

  Future<void> deleteAddress(String id) async {
    _addresses.removeWhere((a) => a.id == id);
    await DbHelper.instance.saveAddresses(_addresses);
    notifyListeners();

    try {
      final response = await _apiService.delete('/addresses/$id');
      if (response.statusCode == 200) {
        await fetchAddresses();
      }
    } catch (e) {
      debugPrint('Backend deleteAddress failed, removed locally & SQLite. Error: $e');
      await _queueOffline('DELETE', '/addresses/$id');
    }
  }

  Future<void> addPaymentMethod(SavedPaymentMethod pay) async {
    _paymentMethods.add(pay);
    await DbHelper.instance.savePaymentMethods(_paymentMethods);
    notifyListeners();

    try {
      final response = await _apiService.post('/payment-methods', body: pay.toJson());
      if (response.statusCode == 201) {
        await fetchPaymentMethods();
      }
    } catch (e) {
      debugPrint('Backend addPaymentMethod failed, kept in local memory & SQLite. Error: $e');
      await _queueOffline('POST', '/payment-methods', pay.toJson());
    }
  }

  Future<void> deletePaymentMethod(String id) async {
    _paymentMethods.removeWhere((p) => p.id == id);
    await DbHelper.instance.savePaymentMethods(_paymentMethods);
    notifyListeners();

    try {
      final response = await _apiService.delete('/payment-methods/$id');
      if (response.statusCode == 200) {
        await fetchPaymentMethods();
      }
    } catch (e) {
      debugPrint('Backend deletePaymentMethod failed, removed locally & SQLite. Error: $e');
      await _queueOffline('DELETE', '/payment-methods/$id');
    }
  }

  void selectService(ClinicalService? service) {
    _selectedService = service;
    notifyListeners();
  }

  void setRole(String role) {
    _currentRole = role;
    notifyListeners();
  }

  /// Roles the app can render a dashboard for. Anything else is ignored so a
  /// future backend value can't leave the user on a blank screen.
  static const List<String> knownRoles = [
    'patient',
    'dependent_tutor',
    'doctor_provider',
    'operator_admin',
    'ambulance_driver',
  ];

  /// Applies the role reported by the backend for the logged-in account.
  void _applyServerRole(String? role) {
    if (role == null || !knownRoles.contains(role)) return;
    _currentRole = role;
    _serverAssignedRole = role;
  }

  String? _serverAssignedRole;

  /// The role that came from the account, if any. When set, the profile screen
  /// shows it as the account's real role and the manual switcher becomes a
  /// preview tool only.
  String? get serverAssignedRole => _serverAssignedRole;

  void setSimulationSpeed(double speed) {
    _simulationSpeed = speed;
    notifyListeners();
  }

  void setDoctorSearchTimeSeconds(int seconds) {
    _doctorSearchTimeSeconds = seconds;
    notifyListeners();
  }

  void setCommissionRate(double rate) {
    _commissionRate = rate;
    notifyListeners();
  }

  void setSimulateOffline(bool val) {
    _apiService.simulateOffline = val;
    notifyListeners();
  }

  Future<void> forceFlushOutbox() async {
    await _outboxService.flush();
  }

  Future<void> clearLocalCache() async {
    stopActiveBookingStream();
    stopChatPolling();
    _authToken = null;
    _apiService.authToken = null;
    _userName = '';
    _userEmail = '';
    _isDemoMode = false;
    _currentRequest = null;
    _unreadByRequest.clear();
    _assignedProfessionalName = null;
    _assignedProfessionalPhone = null;
    _assignedProfessionalSpecialty = null;
    _activeTab = 'home';
    _initializeChat();
    _persistSession();
    await DbHelper.instance.clearAll();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  /// Whether the patient dismissed the "what Aura is / when to call 131"
  /// notice on the home screen. Persisted so a returning user does not have to
  /// read it every single time.
  bool _safetyNoticeDismissed = false;
  bool get safetyNoticeDismissed => _safetyNoticeDismissed;

  Future<void> dismissSafetyNotice() async {
    _safetyNoticeDismissed = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safety_notice_dismissed', true);
  }

  /// Brings the notice back from the accessibility section of the profile.
  Future<void> restoreSafetyNotice() async {
    _safetyNoticeDismissed = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safety_notice_dismissed', false);
  }

  Future<void> setTextScaleFactor(double factor) async {
    _textScaleFactor = factor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_scale_factor', factor);
  }

  // ==================== Ubicación del usuario ====================

  final _localityService = const LocalityService();

  String? _currentLocality;
  LocalityStatus _localityStatus = LocalityStatus.idle;
  double? _currentLat;
  double? _currentLng;

  /// Comuna donde está el usuario, o null si aún no se sabe.
  ///
  /// Nunca se rellena con un valor por defecto: la cabecera mostraba
  /// "Providencia" fijo, lo que le decía a cualquiera —viviese donde viviese—
  /// que estaba en una comuna de Santiago.
  String? get currentLocality => _currentLocality;
  LocalityStatus get localityStatus => _localityStatus;
  double? get currentLat => _currentLat;
  double? get currentLng => _currentLng;

  /// Resuelve la comuna actual.
  ///
  /// [askPermission] solo se activa cuando la persona toca el indicador: pedir
  /// el permiso de ubicación nada más abrir, sin que haya hecho nada, es
  /// intrusivo y se deniega más.
  Future<void> resolveCurrentLocality({bool askPermission = false}) async {
    if (_localityStatus == LocalityStatus.locating) return;

    _localityStatus = LocalityStatus.locating;
    notifyListeners();

    final result = await _localityService.resolve(askPermission: askPermission);

    _localityStatus = result.status;
    if (result.status == LocalityStatus.ready) {
      _currentLocality = result.locality;
      _currentLat = result.latitude;
      _currentLng = result.longitude;

      // Se guarda para que al volver a abrir la app se vea la comuna al
      // instante en lugar de un "Ubicando…" de tres segundos.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_locality', result.locality!);
    }

    notifyListeners();
  }

  /// Edad del titular, usada por las alertas preventivas por rango etario
  /// (D.2). Vive en el dispositivo y no en el servidor: la cuenta todavía no
  /// tiene fecha de nacimiento, y guardarla aquí evita inventar un dato
  /// clínico en el perfil. Persistirla en el backend es el paso siguiente.
  int? _userAge;
  int? get userAge => _userAge;

  Future<void> setUserAge(int? age) async {
    _userAge = (age != null && age > 0 && age < 120) ? age : null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (_userAge == null) {
      await prefs.remove('user_age');
    } else {
      await prefs.setInt('user_age', _userAge!);
    }
  }

  /// Deja el canal clinico en blanco.
  ///
  /// Antes sembraba dos mensajes escritos a mano —uno firmado como "el
  /// personal de enfermeria asignado"— en el arranque de la app, al cerrar
  /// sesion y al terminar una atencion. En una cuenta real eso ponia en el
  /// chat palabras que ningun profesional dijo y hacia que el canal pareciera
  /// vivo justo cuando no habia nadie del otro lado. Los mensajes reales
  /// llegan del servidor; aqui no se inventa ninguno.
  void _initializeChat() {
    _chatMessages.clear();
    if (!_isDemoMode) return;

    // El recorrido guiado si necesita un hilo de ejemplo: no tiene backend
    // detras y sin el la pantalla de mensajes queda muda.
    final nowStr = DateFormat('HH:mm').format(DateTime.now());
    _chatMessages.addAll([
      ChatMessage(
        id: 'm1',
        sender: 'system',
        text: 'Canal clínico seguro iniciado para su prestación.',
        timestamp: nowStr,
      ),
      ChatMessage(
        id: 'm2',
        sender: 'provider',
        text: 'Estimado/a, soy el personal de enfermería asignado. Acabo de preparar los insumos para las curaciones y voy saliendo hacia su domicilio en mi vehículo de asistencia médica. ¿Me podría confirmar si el paciente tiene alguna herida infectada o fiebre severa en este momento?',
        timestamp: nowStr,
      ),
    ]);
  }

  // ==================== Staff area (professional / operator) ====================
  //
  // These hit `/api/staff/*`, which is backed by the same controllers as the
  // web portal. Nothing here is simulated: what the professional sees on the
  // phone is what the coordinator sees on the desktop.

  List<StaffBooking> _staffBookings = [];
  StaffProfile? _staffProfile;
  bool _staffLoading = false;
  String? _staffError;

  List<StaffBooking> get staffBookings => _staffBookings;
  StaffProfile? get staffProfile => _staffProfile;
  bool get staffLoading => _staffLoading;
  String? get staffError => _staffError;

  /// Requests inside the professional's coverage, newest first.
  List<StaffBooking> get staffBookingsInZone =>
      _staffBookings.where((b) => !b.outsideZone && b.isOpen).toList();

  /// Open requests outside their coverage, offered as a fallback.
  List<StaffBooking> get staffBookingsOutsideZone =>
      _staffBookings.where((b) => b.outsideZone && b.isOpen).toList();

  // El cupo de atenciones simultaneas lo sirve `/staff/queue` y sale de la
  // tabla de parametros: operaciones lo cambia sin desplegar, asi que el
  // cliente no puede tenerlo quemado.
  int _staffQueueCap = 1;
  int _staffOpenCases = 0;
  String? _staffQueueNotice;

  int get staffQueueCap => _staffQueueCap;
  int get staffOpenCases => _staffOpenCases;

  /// Por que la cola se ve vacia cuando lo esta por configuracion y no por
  /// falta de pacientes (por ejemplo, nadie le habilito servicios).
  String? get staffQueueNotice => _staffQueueNotice;

  bool get staffAtCap =>
      _staffProfile?.professionalId != null && _staffOpenCases >= _staffQueueCap;

  /// Lo que este profesional ya tomo. Una cuenta de coordinacion no toma
  /// pacientes: para ella son todas las que tienen profesional asignado.
  List<StaffBooking> get staffMyBookings {
    final ownId = _staffProfile?.professionalId;
    return _staffBookings
        .where((b) =>
            b.isOpen &&
            (ownId == null ? !b.isUnassigned : b.professionalId == ownId))
        .toList();
  }

  /// La cola propiamente tal: abiertas, sin duenno y dentro de su zona.
  List<StaffBooking> get staffQueueInZone => _staffBookings
      .where((b) => b.isOpen && b.isUnassigned && !b.outsideZone)
      .toList();

  List<StaffBooking> get staffQueueOutsideZone => _staffBookings
      .where((b) => b.isOpen && b.isUnassigned && b.outsideZone)
      .toList();

  /// Visits already carried out, newest first.
  ///
  /// `/staff/bookings` returns the closed requests alongside the live queue, so
  /// this needs no extra round trip. A professional only counts the ones
  /// assigned to them; an admin has no `professional_id` and sees every closed
  /// visit, which is the same scoping the rest of the staff area uses.
  List<StaffBooking> get staffBookingsCompleted {
    final ownId = _staffProfile?.professionalId;
    final completed = _staffBookings
        .where((b) =>
            b.isCompleted && (ownId == null || b.professionalId == ownId))
        .toList();

    completed.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });
    return completed;
  }

  Future<void> refreshStaffArea() async {
    _staffLoading = true;
    _staffError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.get('/staff/duty', timeout: const Duration(seconds: 8)),
        _apiService.get('/staff/bookings', timeout: const Duration(seconds: 8)),
        _apiService.get('/staff/queue', timeout: const Duration(seconds: 8)),
      ]);

      if (results[0].statusCode == 200) {
        _staffProfile = StaffProfile.fromJson(
          json.decode(results[0].body) as Map<String, dynamic>,
        );
      } else if (results[0].statusCode == 403) {
        _staffError = (json.decode(results[0].body)['error'] as String?) ??
            'Tu cuenta no tiene acceso al área clínica.';
      }

      if (results[1].statusCode == 200) {
        final List<dynamic> data = json.decode(results[1].body);
        _staffBookings = data
            .map((b) => StaffBooking.fromJson(b as Map<String, dynamic>))
            .toList();
      }

      if (results[2].statusCode == 200) {
        final cola = json.decode(results[2].body) as Map<String, dynamic>;
        _staffQueueCap = int.tryParse('${cola['tope'] ?? 1}') ?? 1;
        _staffOpenCases = int.tryParse('${cola['casos_abiertos'] ?? 0}') ?? 0;
        _staffQueueNotice = cola['aviso'] as String?;
      }

      if (_staffProfile?.providesLab == true) {
        await fetchStaffLabCollections();
      }
    } catch (e) {
      debugPrint('refreshStaffArea failed. Error: $e');
      _staffError = 'No pudimos conectar con el servidor.';
    }

    _staffLoading = false;
    notifyListeners();
  }

  /// Tomar una solicitud de la cola.
  ///
  /// Antes esto ocurria solo, como efecto colateral de avanzar el estado o de
  /// transmitir la posicion. Ahora es un acto explicito y el servidor lo
  /// resuelve con un UPDATE condicionado a que siga libre: si dos profesionales
  /// pulsan a la vez, el segundo recibe 409 y se entera, en vez de pisar al
  /// primero en silencio.
  /// Devuelve el mensaje de error, o null si se tomo.
  Future<String?> claimStaffBooking(String id) async {
    try {
      final response = await _apiService.post(
        '/staff/bookings/$id/claim',
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        await refreshStaffArea();
        return null;
      }

      final body = json.decode(response.body);
      return (body is Map ? body['error'] as String? : null) ??
          'No se pudo tomar la solicitud.';
    } catch (e) {
      debugPrint('claimStaffBooking failed. Error: $e');
      return 'Sin conexion con el servidor.';
    }
  }

  /// Devolver una solicitud a la cola.
  ///
  /// Sin esto, un toque equivocado deja al paciente esperando a alguien que no
  /// va a ir y a nadie mas le aparece para tomarla.
  Future<String?> releaseStaffBooking(String id) async {
    try {
      final response = await _apiService.post(
        '/staff/bookings/$id/release',
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        await refreshStaffArea();
        return null;
      }

      final body = json.decode(response.body);
      return (body is Map ? body['error'] as String? : null) ??
          'No se pudo devolver la solicitud a la cola.';
    } catch (e) {
      debugPrint('releaseStaffBooking failed. Error: $e');
      return 'Sin conexion con el servidor.';
    }
  }

  /// Avanza una atencion ya tomada.
  ///
  /// Ya no acepta ni asigna: sobre una solicitud sin duenno el servidor
  /// responde 409 y hay que tomarla antes con [claimStaffBooking].
  /// Returns an error message, or null on success.
  Future<String?> updateStaffBookingStatus(String id, String status) async {
    try {
      final response = await _apiService.post(
        '/staff/bookings/$id/status',
        body: {'status': status},
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        await refreshStaffArea();
        return null;
      }

      final body = json.decode(response.body);
      return (body is Map ? body['error'] as String? : null) ??
          'No se pudo actualizar la atención.';
    } catch (e) {
      debugPrint('updateStaffBookingStatus failed. Error: $e');
      return 'Sin conexión con el servidor.';
    }
  }

  /// Go on or off shift. The backend refuses to go off duty mid-visit.
  Future<String?> setStaffDutyStatus(String dutyStatus) async {
    try {
      final response = await _apiService.post(
        '/staff/duty',
        body: {'duty_status': dutyStatus},
        timeout: const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        await refreshStaffArea();
        return null;
      }

      final body = json.decode(response.body);
      return (body is Map ? body['error'] as String? : null) ??
          'No se pudo cambiar tu estado de turno.';
    } catch (e) {
      debugPrint('setStaffDutyStatus failed. Error: $e');
      return 'Sin conexión con el servidor.';
    }
  }

  /// Actualiza la hoja de vida y datos del profesional autenticado (REQ-08).
  Future<String?> updateStaffProfile({
    String? bio,
    String? registrationNumber,
    int? yearsOfExperience,
    String? phone,
    List<String>? coverageZones,
    String? photoUrl,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (bio != null) payload['bio'] = bio;
      if (registrationNumber != null) payload['registration_number'] = registrationNumber;
      if (yearsOfExperience != null) payload['years_of_experience'] = yearsOfExperience;
      if (phone != null) payload['phone'] = phone;
      if (coverageZones != null) payload['coverage_zones'] = coverageZones;
      if (photoUrl != null) payload['photo_url'] = photoUrl;

      final response = await _apiService.post(
        '/staff/profile',
        body: payload,
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        await refreshStaffArea();
        return null;
      }

      final body = json.decode(response.body);
      return (body is Map ? body['error'] as String? : null) ??
          'No se pudo actualizar el perfil.';
    } catch (e) {
      debugPrint('updateStaffProfile failed. Error: $e');
      return 'Sin conexión con el servidor.';
    }
  }

  /// Envía la calificación de estrellas y reseña de una atención finalizada (REQ-09).
  Future<String?> submitRating({
    required String bookingId,
    required int rating,
    String? feedback,
  }) async {
    try {
      final response = await _apiService.post(
        '/bookings/$bookingId/rating',
        body: {
          'rating': rating,
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        return null;
      }

      final body = json.decode(response.body);
      return (body is Map ? body['error'] as String? : null) ??
          'No se pudo enviar la calificación.';
    } catch (e) {
      debugPrint('submitRating failed. Error: $e');
      return 'Sin conexión con el servidor.';
    }
  }

  // ==================== Tomas de Muestra / Laboratorio Staff (REQ-15) ====================

  List<StaffLabCollection> _staffLabCollections = [];
  List<StaffLabCollection> get staffLabCollections => _staffLabCollections;

  Future<void> fetchStaffLabCollections() async {
    try {
      final response = await _apiService.get('/staff/lab/collections', timeout: const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        _staffLabCollections = data
            .map((b) => StaffLabCollection.fromJson(b as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchStaffLabCollections failed. Error: $e');
    }
  }

  // ==================== Operations panel (operator/admin role) ====================

  OperationsMetrics? _opsMetrics;
  List<ZoneLoad> _opsZones = [];
  List<ManagedProfessional> _opsProfessionals = [];
  bool _opsLoading = false;

  OperationsMetrics? get opsMetrics => _opsMetrics;
  List<ZoneLoad> get opsZones => _opsZones;
  List<ManagedProfessional> get opsProfessionals => _opsProfessionals;
  bool get opsLoading => _opsLoading;

  Future<void> refreshOperations() async {
    _opsLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.get('/staff/admin/metrics', timeout: const Duration(seconds: 8)),
        _apiService.get('/staff/admin/zones', timeout: const Duration(seconds: 8)),
        _apiService.get('/staff/admin/professionals', timeout: const Duration(seconds: 8)),
      ]);

      if (results[0].statusCode == 200) {
        _opsMetrics = OperationsMetrics.fromJson(
          json.decode(results[0].body) as Map<String, dynamic>,
        );
      }
      if (results[1].statusCode == 200) {
        final List<dynamic> data = json.decode(results[1].body);
        _opsZones =
            data.map((z) => ZoneLoad.fromJson(z as Map<String, dynamic>)).toList();
      }
      if (results[2].statusCode == 200) {
        final List<dynamic> data = json.decode(results[2].body);
        _opsProfessionals = data
            .map((p) => ManagedProfessional.fromJson(p as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('refreshOperations failed. Error: $e');
    }

    _opsLoading = false;
    notifyListeners();
  }

  /// Change a provider's duty status from the operations panel. Unlike the old
  /// local-only toggle, this reaches the server.
  Future<String?> setProviderDutyStatus(String professionalId, String dutyStatus) async {
    try {
      final response = await _apiService.post(
        '/staff/admin/professionals/$professionalId',
        body: {'duty_status': dutyStatus},
        timeout: const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        await refreshOperations();
        return null;
      }
      return 'No se pudo actualizar el turno del prestador.';
    } catch (e) {
      debugPrint('setProviderDutyStatus failed. Error: $e');
      return 'Sin conexión con el servidor.';
    }
  }

  /// Live wait estimate for a service in the zone of [address].
  ///
  /// The backend looks at how many requests are open in that comuna and how
  /// many professionals of the discipline are on duty, so the number reflects
  /// real demand instead of the static per-service ETA. Returns null when the
  /// backend is unreachable, and the caller falls back to the catalog ETA.
  Future<ZoneEtaEstimate?> fetchZoneEta({
    required String serviceId,
    String? address,
  }) async {
    try {
      final query = <String, String>{
        'service_id': serviceId,
        if (address != null && address.isNotEmpty) 'address': address,
      };
      final queryString = query.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');

      final response = await _apiService.get('/dispatch/eta?$queryString');
      if (response.statusCode == 200) {
        return ZoneEtaEstimate.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('fetchZoneEta failed. Error: $e');
    }
    return null;
  }

  /// Cotiza la tarifa de un traslado georreferenciado (REQ-11).
  Future<Map<String, dynamic>?> quoteTransport({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String ambulanceType = 'basic',
  }) async {
    try {
      final response = await _apiService.get(
        '/transport/quote?origin_lat=$originLat&origin_lng=$originLng&destination_lat=$destinationLat&destination_lng=$destinationLng&ambulance_type=$ambulanceType',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('quoteTransport failed: $e');
      return null;
    }
  }

  // Submit request and start match simulation
  Future<String?> confirmRequest({
    required String patientType,
    String? dependentId,
    required String addressText,
    String? originAddress,
    String? destinationAddress,
    String? ambulanceType,
    double? patientLat,
    double? patientLng,
    double? destinationLat,
    double? destinationLng,
    String? symptomsDescription,
    String? symptomAudioPath,
    String? prescriptionName,
    String? prescriptionPreview,
    required int finalPrice,
    required int etaMinutes,
  }) async {
    _isSearchingDoctor = true;
    notifyListeners();

    try {
      // `prescriptionPreview` holds the local device path of the file the user
      // picked from the camera/gallery. When it points to a real file we upload
      // the actual bytes with a multipart request; otherwise we keep the plain
      // JSON booking so services without a prescription are unaffected.
      final localPrescriptionPath = prescriptionPreview;
      final hasPrescriptionFile = localPrescriptionPath != null &&
          localPrescriptionPath.isNotEmpty &&
          File(localPrescriptionPath).existsSync();

      // Optional voice note recorded in the symptom descriptor.
      final hasSymptomAudio = symptomAudioPath != null &&
          symptomAudioPath.isNotEmpty &&
          File(symptomAudioPath).existsSync();

      final http.Response response;
      if (hasPrescriptionFile || hasSymptomAudio) {
        final files = <http.MultipartFile>[
          if (hasPrescriptionFile)
            await http.MultipartFile.fromPath(
              'prescription_file',
              localPrescriptionPath,
              filename: prescriptionName,
            ),
          if (hasSymptomAudio)
            await http.MultipartFile.fromPath(
              'symptom_audio',
              symptomAudioPath,
              filename: symptomAudioPath.split(Platform.pathSeparator).last,
            ),
        ];

        final fields = <String, String>{
          'service_id': _selectedService!.id,
          'patient_type': patientType,
          'address_text': addressText,
          'final_price': finalPrice.toString(),
          'eta_minutes': etaMinutes.toString(),
        };
        if (dependentId != null) fields['dependent_id'] = dependentId;
        if (originAddress != null) fields['origin_address'] = originAddress;
        if (destinationAddress != null) fields['destination_address'] = destinationAddress;
        if (ambulanceType != null) fields['ambulance_type'] = ambulanceType;
        if (patientLat != null) fields['patient_lat'] = patientLat.toString();
        if (patientLng != null) fields['patient_lng'] = patientLng.toString();
        if (destinationLat != null) fields['destination_lat'] = destinationLat.toString();
        if (destinationLng != null) fields['destination_lng'] = destinationLng.toString();
        if (symptomsDescription != null) fields['symptoms_description'] = symptomsDescription;
        if (prescriptionName != null) fields['prescription_name'] = prescriptionName;

        response = await _apiService.postMultipart(
          '/bookings',
          fields: fields,
          files: files,
        );
      } else {
        response = await _apiService.post(
          '/bookings',
          body: {
            'service_id': _selectedService!.id,
            'patient_type': patientType,
            'dependent_id': dependentId,
            'address_text': addressText,
            'origin_address': originAddress,
            'destination_address': destinationAddress,
            'ambulance_type': ambulanceType,
            'patient_lat': patientLat,
            'patient_lng': patientLng,
            'destination_lat': destinationLat,
            'destination_lng': destinationLng,
            'symptoms_description': symptomsDescription,
            'prescription_name': prescriptionName,
            'prescription_preview': prescriptionPreview,
            'final_price': finalPrice,
            'eta_minutes': etaMinutes,
          },
        );
      }

      _isSearchingDoctor = false;

      if (response.statusCode == 201) {
        await fetchActiveRequest();

        if (_currentRequest?.status == RequestStatus.pendingPayment) {
          // Real gateway flow: land on the confirmation screen showing the
          // amount. We deliberately do NOT open Mercado Pago here — the user
          // must accept the total (or cancel the request) first.
          _activeTab = 'appointments';
        } else {
          _activeTab = 'appointments';
          // El servidor abre el canal con sus mensajes; el recuento sale de
          // ellos, no de un 1 escrito a mano.
          if (_currentRequest != null) {
            await _refreshUnreadCount(_currentRequest!.id);
          }
        }
        notifyListeners();
        return null;
      } else {
        String? errorMessage;
        try {
          final data = jsonDecode(response.body);
          if (data is Map) {
            if (data['message'] != null) {
              errorMessage = data['message'].toString();
            } else if (data['error'] != null) {
              errorMessage = data['error'].toString();
            } else if (data['errors'] != null && data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
              final firstVal = (data['errors'] as Map).values.first;
              if (firstVal is List && firstVal.isNotEmpty) {
                errorMessage = firstVal.first.toString();
              }
            }
          }
        } catch (_) {}
        errorMessage ??= 'Error al procesar la solicitud (código ${response.statusCode})';
        notifyListeners();
        return errorMessage;
      }
    } catch (e) {
      debugPrint('Backend confirmRequest failed, falling back to local simulation. Error: $e');
      // LOCAL FALLBACK SIMULATION:
      Timer(Duration(seconds: _doctorSearchTimeSeconds), () async {
        _isSearchingDoctor = false;

        final now = DateTime.now();
        final timeStr = DateFormat('HH:mm').format(now);

        // Dynamic routing logic based on provider status
        String docName = '';
        String docPhone = '';
        String docSpecialty = '';

        final requestedServiceId = _selectedService?.id ?? 'medico';
        
        final matchingProviders = _systemProviders.where((p) {
          if (requestedServiceId == 'medico' && p['id']!.contains('leyton')) return true;
          if (requestedServiceId == 'medico' && p['id']!.contains('rivera')) return true;
          if (requestedServiceId == 'enfermeria' && p['id']!.contains('jara')) return true;
          if (requestedServiceId == 'kine_motora' && p['id']!.contains('diaz')) return true;
          if (requestedServiceId == 'kine_respiratoria' && p['id']!.contains('diaz')) return true;
          return false;
        }).toList();

        final availableProvider = matchingProviders.firstWhere(
          (p) => p['status'] == 'Disponible',
          orElse: () => {},
        );

        // Only the guided demo names a professional. When the backend is
        // genuinely unreachable the request never left the device, so claiming
        // that somebody accepted it — with a phone number the patient might
        // call — would be a lie. The tracking screen shows "asignando
        // profesional" while these stay null.
        if (_isDemoMode && availableProvider.isNotEmpty) {
          docName = availableProvider['name'] as String;
          docPhone = availableProvider['phone'] as String;
          docSpecialty = '${availableProvider['specialty'] as String} • On-Duty';
        }

        _assignedProfessionalName = docName.isEmpty ? null : docName;
        _assignedProfessionalPhone = docPhone.isEmpty ? null : docPhone;
        _assignedProfessionalSpecialty = docSpecialty.isEmpty ? null : docSpecialty;

        _currentRequest = ServiceRequest(
          id: 'req_${DateTime.now().millisecondsSinceEpoch}',
          serviceId: _selectedService?.id ?? 'medico',
          status: RequestStatus.accepted,
          patientType: patientType,
          dependentId: dependentId,
          addressText: addressText,
          originAddress: originAddress,
          destinationAddress: destinationAddress,
          ambulanceType: ambulanceType,
          patientLat: patientLat,
          patientLng: patientLng,
          symptomsDescription: symptomsDescription,
          prescriptionName: prescriptionName,
          prescriptionPreview: prescriptionPreview,
          paymentMethod: 'mercadopago',
          finalPrice: finalPrice,
          startTime: timeStr,
          etaMinutes: etaMinutes,
          currentStep: 1,
        );

        _activeTab = 'appointments';

        final serviceTitle = _services.firstWhere((s) => s.id == _currentRequest?.serviceId).shortTitle;
        _chatMessages.clear();
        _chatMessages.addAll([
          ChatMessage(
            id: 'm1',
            sender: 'system',
            text: 'Canal clínico seguro iniciado para: $serviceTitle.',
            timestamp: timeStr,
          ),
          ChatMessage(
            id: 'm2',
            sender: 'provider',
            text: 'Hola, soy el especialista asignado para tu atención de $serviceTitle. Ya estoy coordinando los insumos médicos necesarios y me dirijo hacia tu ubicación. ¿Hay algún detalle adicional que deba saber del paciente?',
            timestamp: timeStr,
          ),
        ]);

        await DbHelper.instance.saveBookings([_currentRequest!]);
        await DbHelper.instance.saveChatMessages(_currentRequest!.id, _chatMessages);

        // Los dos mensajes de apertura son nuevos para el paciente: el
        // contador sale de contarlos, no de darlos por supuestos.
        await _refreshUnreadCount(_currentRequest!.id);

        notifyListeners();
      });
      return null;
    }
  }

  // ==================== Scheduled appointments ====================

  List<Professional> _professionals = [];
  List<Appointment> _appointments = [];

  List<Professional> get professionals => _professionals;
  List<Appointment> get appointments => _appointments;

  Future<void> fetchProfessionals() async {
    try {
      final response = await _apiService.get('/professionals');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _professionals = data
            .map((j) => Professional.fromJson(j as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchProfessionals failed. Error: $e');
    }
  }

  Future<List<DateTime>> fetchSlots(String professionalId, DateTime date) async {
    try {
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _apiService.get(
        '/professionals/$professionalId/slots?date=$dateStr',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return (data['slots'] as List<dynamic>).map((iso) {
          final s = iso as String;
          final clean = s.length >= 19 ? s.substring(0, 19) : s;
          return DateTime.parse(clean);
        }).toList();
      }
    } catch (e) {
      debugPrint('fetchSlots failed. Error: $e');
    }
    return [];
  }

  Future<void> fetchAppointments() async {
    try {
      final response = await _apiService.get('/appointments');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _appointments = data
            .map((j) => Appointment.fromJson(j as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchAppointments failed. Error: $e');
    }
  }

  // Book an appointment. Returns (appointment, null) on success or
  // (null, error message) on failure.
  Future<(Appointment?, String?)> createAppointment({
    required String professionalId,
    required DateTime scheduledAt,
    String? reason,
    String type = 'presencial',
  }) async {
    try {
      final formattedScheduledAt =
          '${scheduledAt.year.toString().padLeft(4, '0')}-${scheduledAt.month.toString().padLeft(2, '0')}-${scheduledAt.day.toString().padLeft(2, '0')}T${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}:00';

      final response = await _apiService.post(
        '/appointments',
        body: {
          'professional_id': professionalId,
          'scheduled_at': formattedScheduledAt,
          'type': type,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
        timeout: const Duration(seconds: 12),
      );

      if (response.statusCode == 201) {
        final appointment = Appointment.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
        await fetchAppointments();
        return (appointment, null);
      }

      if (response.statusCode == 409) {
        return (null, 'Ese horario acaba de ser tomado. Elige otro.');
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      return (null, (body['error'] ?? 'No se pudo agendar la cita.') as String);
    } catch (e) {
      debugPrint('createAppointment failed. Error: $e');
      return (null, 'Sin conexión. Intenta de nuevo.');
    }
  }

  // Re-check an appointment payment with the backend.
  // Returns true once it is confirmed.
  Future<bool> verifyAppointmentPayment(String id) async {
    try {
      final response = await _apiService.get(
        '/appointments/$id/payment-status',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final appointment = Appointment.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
        final index = _appointments.indexWhere((a) => a.id == id);
        if (index >= 0) {
          _appointments[index] = appointment;
          notifyListeners();
        }
        return appointment.status == AppointmentStatus.confirmed;
      }
    } catch (e) {
      debugPrint('verifyAppointmentPayment failed. Error: $e');
    }
    return false;
  }

  Future<String?> cancelAppointment(String id) async {
    try {
      final response = await _apiService.post('/appointments/$id/cancel');
      if (response.statusCode == 200) {
        await fetchAppointments();
        return null;
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      return (body['error'] ?? 'No se pudo cancelar la cita.') as String;
    } catch (e) {
      debugPrint('cancelAppointment failed. Error: $e');
      return 'Sin conexión. Intenta de nuevo.';
    }
  }

  // ==================== Laboratorio (Módulo E) ====================
  //
  // La toma de muestras se agenda contra bloques que el laboratorista publicó,
  // así que no pasa por `/bookings` ni por la cola por zona. Y a diferencia del
  // resto del estado, aquí no hay simulación local de respaldo: inventar un
  // cupo que el servidor no reservó le prometería al paciente una visita que
  // nadie va a hacer.

  List<LabRequest> _labRequests = [];
  List<LabResult> _labResults = [];

  List<LabRequest> get labRequests => _labRequests;
  List<LabResult> get labResults => _labResults;

  /// Próxima toma de muestras vigente, si la hay.
  LabRequest? get nextLabRequest {
    final upcoming = _labRequests
        .where((r) => r.isCancellable && r.scheduledAt != null)
        .toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// Fechas próximas con al menos un cupo libre, para marcar el calendario.
  Future<List<DateTime>> fetchLabAvailability({String? zone, int days = 14}) async {
    try {
      final query = StringBuffer('/lab/availability?days=$days');
      if (zone != null && zone.isNotEmpty) {
        query.write('&zone=${Uri.encodeQueryComponent(zone)}');
      }
      final response = await _apiService.get(query.toString(), timeout: const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (data['dates'] as List<dynamic>)
            .map((d) => DateTime.parse('${d}T00:00:00').toLocal())
            .toList();
      }
    } catch (e) {
      debugPrint('fetchLabAvailability failed. Error: $e');
    }
    return const [];
  }

  /// Cupos libres de una fecha concreta.
  Future<List<LabSlot>> fetchLabSlots(DateTime date, {String? zone}) async {
    final day = DateFormat('yyyy-MM-dd').format(date);
    try {
      final query = StringBuffer('/lab/slots?date=$day');
      if (zone != null && zone.isNotEmpty) {
        query.write('&zone=${Uri.encodeQueryComponent(zone)}');
      }
      final response = await _apiService.get(query.toString(), timeout: const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (data['slots'] as List<dynamic>)
            .map((s) => LabSlot.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('fetchLabSlots failed. Error: $e');
    }
    return const [];
  }

  /// Agenda una toma de muestras. Devuelve (solicitud, null) o (null, error).
  Future<(LabRequest?, String?)> createLabRequest({
    required LabSlot slot,
    required String patientType,
    String? dependentId,
    required String addressText,
    double? patientLat,
    double? patientLng,
    required String examRequired,
    String? clinicalNotes,
    String? prescriptionName,
    String? prescriptionPath,
  }) async {
    try {
      final fields = <String, String>{
        'schedule_id': slot.scheduleId.toString(),
        'starts_at': slot.startsAt.toUtc().toIso8601String(),
        'patient_type': patientType,
        // ignore: use_null_aware_elements
        if (dependentId != null) 'dependent_id': dependentId,
        'address_text': addressText,
        if (patientLat != null) 'patient_lat': patientLat.toString(),
        if (patientLng != null) 'patient_lng': patientLng.toString(),
        'exam_required': examRequired,
        if (clinicalNotes != null && clinicalNotes.isNotEmpty)
          'clinical_notes': clinicalNotes,
        // ignore: use_null_aware_elements
        if (prescriptionName != null) 'prescription_name': prescriptionName,
      };

      final hasPrescription = prescriptionPath != null &&
          prescriptionPath.isNotEmpty &&
          File(prescriptionPath).existsSync();

      final http.Response response;
      if (hasPrescription) {
        response = await _apiService.postMultipart(
          '/lab/requests',
          fields: fields,
          files: [
            await http.MultipartFile.fromPath(
              'prescription_file',
              prescriptionPath,
              filename: prescriptionName,
            ),
          ],
        );
      } else {
        response = await _apiService.post(
          '/lab/requests',
          body: fields,
          timeout: const Duration(seconds: 15),
        );
      }

      final body = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        final request = LabRequest.fromJson(body);
        await fetchLabRequests();
        return (request, null);
      }

      if (response.statusCode == 409) {
        return (null, 'Ese horario acaba de ser tomado. Elige otro bloque.');
      }

      // 422 trae el detalle por campo; mostrar el primero es más útil que un
      // "revisa los datos" genérico.
      if (response.statusCode == 422 && body['errors'] is Map) {
        final errors = (body['errors'] as Map).values.first;
        if (errors is List && errors.isNotEmpty) {
          return (null, errors.first as String);
        }
      }

      return (null, (body['error'] ?? body['message'] ?? 'No se pudo agendar la toma de muestras.') as String);
    } catch (e) {
      debugPrint('createLabRequest failed. Error: $e');
      return (null, 'Sin conexión. Intenta de nuevo.');
    }
  }

  Future<void> fetchLabRequests() async {
    try {
      final response = await _apiService.get('/lab/requests', timeout: const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _labRequests = data
            .map((j) => LabRequest.fromJson(j as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchLabRequests failed. Error: $e');
    }
  }

  Future<String?> cancelLabRequest(String id) async {
    try {
      final response = await _apiService.post('/lab/requests/$id/cancel');
      if (response.statusCode == 200) {
        await fetchLabRequests();
        return null;
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      return (body['error'] ?? 'No se pudo cancelar la toma de muestras.') as String;
    } catch (e) {
      debugPrint('cancelLabRequest failed. Error: $e');
      return 'Sin conexión. Intenta de nuevo.';
    }
  }

  /// Re-consulta el pago de una toma agendada. True cuando quedó confirmada.
  Future<bool> verifyLabPayment(String id) async {
    try {
      final response = await _apiService.get(
        '/lab/requests/$id/payment-status',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final request = LabRequest.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
        final index = _labRequests.indexWhere((r) => r.id == id);
        if (index >= 0) {
          _labRequests[index] = request;
          notifyListeners();
        }
        return !request.awaitsPayment;
      }
    } catch (e) {
      debugPrint('verifyLabPayment failed. Error: $e');
    }
    return false;
  }

  /// "Mis Exámenes": histórico de informes descargables.
  Future<void> fetchLabResults() async {
    try {
      final response = await _apiService.get('/lab/results', timeout: const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _labResults = data
            .map((j) => LabResult.fromJson(j as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchLabResults failed. Error: $e');
    }
  }

  /// Abre el informe en el visor del sistema.
  ///
  /// El visor externo no lleva el token de sesión, así que primero se pide al
  /// servidor un enlace firmado de vida corta. Abrir directamente
  /// `downloadUrl` devolvería 403, y dejar esa URL accesible sin firma
  /// convertiría un informe clínico en un enlace público.
  Future<bool> openLabResult(LabResult result) async {
    try {
      final response = await _apiService.get(
        '/lab/results/${result.id}/link',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode != 200) return false;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null || url.isEmpty) return false;

      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('openLabResult failed. Error: $e');
      return false;
    }
  }

  /// Opens a clinical attachment (voice note or prescription) by obtaining
  /// a short-lived signed link from the server to prevent 403 authorization errors.
  Future<bool> openMediaAttachment(String mediaUrl) async {
    try {
      String? bookingId;
      String? kind;

      if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
        final uri = Uri.parse(mediaUrl);
        final segments = uri.pathSegments;
        if (segments.length >= 4 && segments[0] == 'media' && segments[1] == 'bookings') {
          bookingId = segments[2];
          kind = segments[3];
        }
      } else {
        final segments = mediaUrl.split('/').where((s) => s.isNotEmpty).toList();
        if (segments.length >= 4 && segments[0] == 'media' && segments[1] == 'bookings') {
          bookingId = segments[2];
          kind = segments[3];
        }
      }

      if (bookingId != null && kind != null) {
        final response = await _apiService.get(
          '/media/bookings/$bookingId/$kind/link',
          timeout: const Duration(seconds: 8),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final signedUrl = data['url'] as String?;
          if (signedUrl != null && signedUrl.isNotEmpty) {
            return await launchUrl(
              Uri.parse(signedUrl),
              mode: LaunchMode.externalApplication,
            );
          }
        }
      }

      return await launchUrl(
        Uri.parse(mediaUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('openMediaAttachment failed. Error: $e');
      return false;
    }
  }

  // Ask the backend for the WebRTC session config of a video consultation.
  // Returns (iceServers, null) on success or (null, error message).
  Future<(List<Map<String, dynamic>>?, String?)> fetchVideoJoinConfig(
      String appointmentId) async {
    try {
      final response = await _apiService.get(
        '/appointments/$appointmentId/video-join',
        timeout: const Duration(seconds: 10),
      );
      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200) {
        final servers = (data['ice_servers'] as List<dynamic>)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        return (servers, null);
      }
      return (null, (data['error'] ?? 'No se pudo abrir la videoconsulta.') as String);
    } catch (e) {
      debugPrint('fetchVideoJoinConfig failed. Error: $e');
      return (null, 'Sin conexión. Intenta de nuevo.');
    }
  }

  // Push a WebRTC signal (answer/candidate/ready/hangup) to the backend.
  // Retries transient failures. Returns null on success or a short
  // description of the failure so the call screen can surface it.
  Future<String?> postVideoSignal(String appointmentId, String type,
      [Map<String, dynamic>? payload]) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await _apiService.post(
          '/appointments/$appointmentId/video-signals',
          body: {'type': type, 'payload': payload},
          timeout: const Duration(seconds: 8),
        );
        if (response.statusCode == 201) return null;

        lastError = 'HTTP ${response.statusCode} ${response.body}';
        debugPrint('postVideoSignal($type) rejected: $lastError');
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return lastError.toString(); // definitive rejection: do not retry
        }
      } catch (e) {
        lastError = e;
        debugPrint('postVideoSignal($type) attempt $attempt failed. Error: $e');
      }
      await Future.delayed(Duration(milliseconds: 400 * attempt));
    }
    return lastError?.toString() ?? 'sin respuesta del servidor';
  }

  // Poll signals sent by the clinical staff, newer than [afterId].
  Future<List<Map<String, dynamic>>> fetchVideoSignals(
      String appointmentId, int afterId) async {
    try {
      final response = await _apiService.get(
        '/appointments/$appointmentId/video-signals?after=$afterId',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return (data['signals'] as List<dynamic>)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('fetchVideoSignals failed. Error: $e');
    }
    return [];
  }

  // Open an external checkout URL (Mercado Pago) for an appointment
  Future<void> openCheckoutUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open checkout URL. Error: $e');
    }
  }

  // Open the Mercado Pago checkout for the current pending-payment booking
  Future<void> launchPaymentCheckout() async {
    final url = _currentRequest?.paymentUrl;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open payment checkout URL. Error: $e');
    }
  }

  // Ask the backend to (re)check the payment with Mercado Pago.
  // Returns true once the payment is approved and the booking activated.
  Future<bool> verifyPayment() async {
    if (_currentRequest == null) return false;

    try {
      final response = await _apiService.get(
        '/bookings/${_currentRequest!.id}/payment-status',
        timeout: const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _currentRequest = ServiceRequest.fromJson(data);

        if (_currentRequest!.status != RequestStatus.pendingPayment) {
          // fetchChatMessages recalcula los no leídos por sí solo.
          await fetchChatMessages(_currentRequest!.id);
        }
        notifyListeners();
        return _currentRequest!.status == RequestStatus.accepted;
      }
    } catch (e) {
      debugPrint('Backend verifyPayment failed. Error: $e');
    }
    return false;
  }

  Future<void> cancelRequest() async {
    if (_currentRequest == null) return;

    try {
      final response = await _apiService.post('/bookings/${_currentRequest!.id}/cancel');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _currentRequest = ServiceRequest.fromJson(data);
        await DbHelper.instance.saveBookings([_currentRequest!]);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend cancelRequest failed. Error: $e');
      _currentRequest = _currentRequest!.copyWith(
        status: RequestStatus.cancelled,
        currentStep: 0,
      );
      await DbHelper.instance.saveBookings([_currentRequest!]);
      notifyListeners();
    }
  }

  void completeSimulation() {
    if (_currentRequest != null) {
      DbHelper.instance.saveBookings([]);
    }
    stopChatPolling();
    _currentRequest = null;
    _unreadByRequest.clear();
    _assignedProfessionalName = null;
    _assignedProfessionalPhone = null;
    _assignedProfessionalSpecialty = null;
    _initializeChat();
    notifyListeners();
  }

  /// Ultimo fallo de envio, para que la pantalla lo cuente una sola vez.
  String? _chatSendError;
  String? get chatSendError => _chatSendError;

  void clearChatSendError() {
    _chatSendError = null;
  }

  /// Envia un mensaje del paciente al canal clinico.
  ///
  /// El globo propio aparece de inmediato. Antes, mientras el mensaje viajaba,
  /// se mostraba en su lugar un indicador de "el profesional esta
  /// escribiendo" que no correspondia a nadie: nadie estaba escribiendo, era
  /// el propio envio en curso.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _currentRequest == null) return;
    final requestId = _currentRequest!.id;

    final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    _chatMessages.add(ChatMessage(
      id: localId,
      sender: 'patient',
      text: trimmed,
      timestamp: DateFormat('HH:mm').format(DateTime.now()),
    ));
    _chatSendError = null;
    notifyListeners();

    // El recorrido guiado no tiene cuenta ni servidor detrás: el mensaje se
    // queda donde está en vez de salir a la API y volver con un 401.
    if (_isDemoMode) return;

    try {
      final response = await _apiService.post(
        '/bookings/$requestId/chat',
        body: {'text': trimmed},
      );

      if (response.statusCode == 201) {
        // Manda el hilo del servidor: reemplaza el eco local por el mensaje
        // guardado, con su id y su hora reales.
        await fetchChatMessages(requestId);
      } else {
        // El servidor lo rechazo. No puede quedarse en pantalla como si
        // hubiera salido.
        _chatMessages.removeWhere((m) => m.id == localId);
        _chatSendError =
            'No se pudo enviar tu mensaje. Intentalo nuevamente en unos segundos.';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend sendMessage failed, queuing for retry when online. Error: $e');

      // Sin conexion: el globo se queda y la peticion va a la bandeja de
      // salida, que la reenvia a /chat al recuperar red. No se genera ninguna
      // respuesta automatica: contesta el profesional cuando le llega.
      await DbHelper.instance.saveChatMessages(requestId, _chatMessages);
      await _queueOffline('POST', '/bookings/$requestId/chat', {'text': trimmed});

      notifyListeners();
    }
  }

  // --- Server-Sent Events (SSE) Stream Subscriber ---
  StreamSubscription<String>? _activeBookingSubscription;
  http.Client? _sseClient;

  void startActiveBookingStream(String requestId) {
    if (_activeBookingSubscription != null) {
      _activeBookingSubscription!.cancel();
      _activeBookingSubscription = null;
    }
    if (_sseClient != null) {
      _sseClient!.close();
    }

    _sseClient = http.Client();
    final url = Uri.parse('$_baseUrl/bookings/$requestId/sse');
    final request = http.Request('GET', url);
    request.headers['Authorization'] = 'Bearer $_authToken';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    debugPrint('Starting SSE Stream for booking: $requestId');

    _sseClient!.send(request).then((response) {
      if (response.statusCode != 200) {
        debugPrint('Failed to connect to SSE stream: ${response.statusCode}');

        // Un 401/403/404 no se arregla reintentando: la reserva no es de este
        // usuario, o la sesión ya no vale. Se reintentaba cada 3 s para
        // siempre, una petición por segundo y medio contra un servidor que
        // seguía contestando lo mismo. El hilo llega igual por el polling.
        if (const [401, 403, 404, 204].contains(response.statusCode)) {
          debugPrint('SSE stream unavailable for this booking; relying on polling.');
          return;
        }

        _reconnectActiveBookingStream(requestId);
        return;
      }

      // Conexión buena: la espera vuelve al mínimo.
      _sseBackoffSeconds = _sseBackoffMinSeconds;

      _activeBookingSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) async {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6);
            if (dataStr.trim().isEmpty) return;
            try {
              final Map<String, dynamic> data = json.decode(dataStr);
              if (data.containsKey('booking')) {
                final newRequest = ServiceRequest.fromJson(data['booking']);
                final previousStatus = _currentRequest?.status;
                bool updated = false;

                // Avoid redundant updates if nothing changed. The professional's
                // live GPS is included so the tracking map marker moves in real
                // time, not only on status/step transitions.
                if (_currentRequest == null ||
                    _currentRequest!.status != newRequest.status ||
                    _currentRequest!.currentStep != newRequest.currentStep ||
                    _currentRequest!.professionalLat != newRequest.professionalLat ||
                    _currentRequest!.professionalLng != newRequest.professionalLng) {
                  _currentRequest = newRequest;
                  await DbHelper.instance.saveBookings([_currentRequest!]);
                  updated = true;
                }

                // The professional just closed the service from the portal:
                // pull the freshly-created past-service record into history.
                if (newRequest.status == RequestStatus.completed &&
                    previousStatus != RequestStatus.completed) {
                  await fetchHistory();
                }

                // Cerrada o anulada la atencion el canal deja de existir, y
                // reabierta vuelve a hacer falta: el timer se ajusta aqui.
                if (previousStatus != newRequest.status) {
                  _restartChatPolling();
                }

                if (data.containsKey('messages')) {
                  final List<dynamic> msgsList = data['messages'] as List<dynamic>;
                  final newMessages = msgsList.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
                  debugPrint('[CHAT-DEBUG] SSE received ${newMessages.length} messages');
                  
                  if (!_sameThread(_chatMessages, newMessages)) {
                    debugPrint('[CHAT-DEBUG] SSE → NEW messages via SSE! '
                        'old=${_chatMessages.length} new=${newMessages.length}');
                    _chatMessages.clear();
                    _chatMessages.addAll(newMessages);
                    try {
                      await DbHelper.instance.saveChatMessages(newRequest.id, _chatMessages);
                    } catch (dbErr) {
                      debugPrint('[CHAT-DEBUG] Local SQLite saveChatMessages SSE warning: $dbErr');
                    }
                    await _refreshUnreadCount(newRequest.id);
                    updated = true;
                  }
                } else {
                  debugPrint('[CHAT-DEBUG] SSE payload has NO messages key');
                }

                if (updated) {
                  notifyListeners();
                }
              }
            } catch (e) {
              debugPrint('[CHAT-DEBUG] SSE decode error: $e');
            }
          }
        },
        onError: (error) {
          debugPrint('SSE Stream error: $error');
          _reconnectActiveBookingStream(requestId);
        },
        onDone: () {
          debugPrint('SSE Stream disconnected');
          _reconnectActiveBookingStream(requestId);
        },
        cancelOnError: true,
      );
    }).catchError((e) {
      debugPrint('Failed to start SSE request stream: $e');
      _reconnectActiveBookingStream(requestId);
    });
  }

  // Espera antes de reabrir el stream. Era fija en 3 s: detrás de un proxy que
  // nunca deja pasar el evento —lo normal en un PaaS— eso son veinte intentos
  // por minuto, indefinidamente y en el teléfono del paciente. Ahora cede.
  static const int _sseBackoffMinSeconds = 3;
  static const int _sseBackoffMaxSeconds = 60;
  int _sseBackoffSeconds = _sseBackoffMinSeconds;

  void _reconnectActiveBookingStream(String requestId) {
    if (_currentRequest == null ||
        _currentRequest!.id != requestId ||
        _currentRequest!.status == RequestStatus.completed ||
        _currentRequest!.status == RequestStatus.cancelled) {
      return;
    }

    final wait = _sseBackoffSeconds;
    _sseBackoffSeconds =
        (_sseBackoffSeconds * 2).clamp(_sseBackoffMinSeconds, _sseBackoffMaxSeconds);

    Timer(Duration(seconds: wait), () {
      if (_currentRequest != null && _currentRequest!.id == requestId) {
        startActiveBookingStream(requestId);
      }
    });
  }

  void stopActiveBookingStream() {
    if (_activeBookingSubscription != null) {
      _activeBookingSubscription!.cancel();
      _activeBookingSubscription = null;
    }
    if (_sseClient != null) {
      _sseClient!.close();
      _sseClient = null;
    }
    debugPrint('SSE Stream stopped cleanly.');
  }

  // =========================================================================
  // GESTIÓN DE SUSCRIPCIONES Y PLANES RECURRENTES (REQ-13)
  // =========================================================================

  Future<void> fetchSubscriptionPlans() async {
    try {
      final res = await _apiService.get('/subscriptions/plans');
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        _subscriptionPlans = data.map((e) => SubscriptionPlan.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching subscription plans: $e');
    }
  }

  Future<void> fetchCurrentSubscription() async {
    if (!isAuthenticated) return;
    try {
      _isLoadingSubscription = true;
      notifyListeners();
      final res = await _apiService.get('/subscriptions/current');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _subscriptionInfo = UserSubscriptionInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching current subscription: $e');
    } finally {
      _isLoadingSubscription = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> subscribeToPlan(String planId) async {
    try {
      final res = await _apiService.post('/subscriptions/subscribe', body: {
        'plan_id': planId,
      });
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = json.decode(res.body);
        await fetchCurrentSubscription();
        return data;
      }
    } catch (e) {
      debugPrint('Error subscribing to plan: $e');
    }
    return null;
  }

  Future<bool> cancelSubscription() async {
    try {
      final res = await _apiService.post('/subscriptions/cancel');
      if (res.statusCode == 200) {
        await fetchCurrentSubscription();
        return true;
      }
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
    }
    return false;
  }

  @override
  void dispose() {
    stopActiveBookingStream();
    stopChatPolling();
    super.dispose();
  }
}
