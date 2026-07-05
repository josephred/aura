import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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
import '../models/saved_address.dart';
import '../models/saved_payment_method.dart';
import '../models/service_request.dart';
import '../models/chat_message.dart';
import '../models/past_service.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';
import '../services/outbox_service.dart';
import '../services/push_service.dart';

class AppState extends ChangeNotifier {
  // Base URL configuration for both local Web and Android Emulator
  final String _baseUrl = kReleaseMode ? 'https://aura.hstn.me/api' : (kIsWeb ? 'http://localhost:8000/api' : 'http://10.0.2.2:8000/api');

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

  // Lists in state to support mutations
  List<ClinicalService> _services = List.from(clinicalServices);
  final List<Dependent> _dependents = List.from(initialDependents);
  final List<SavedAddress> _addresses = List.from(initialAddresses);
  final List<SavedPaymentMethod> _paymentMethods = List.from(initialPaymentMethods);
  final List<PastService> _pastServices = List.from(pastServicesHistory);

  // Form selection and active requests
  ClinicalService? _selectedService;
  ServiceRequest? _currentRequest;
  bool _isSearchingDoctor = false;

  // Chat Simulation
  int _pendingMessages = 0;
  String _currentRole = 'patient'; // 'patient' | 'dependent_tutor' | 'doctor_provider' | 'operator_admin' | 'ambulance_driver'
  bool _isChatTyping = false;
  final List<ChatMessage> _chatMessages = [];

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

  // A push arrived with the app in foreground: refresh the affected data
  Future<void> _onPushMessage(Map<String, dynamic> data) async {
    await fetchActiveRequest();
    if (_currentRequest != null && data['type'] == 'chat') {
      _pendingMessages += 1;
      await fetchChatMessages(_currentRequest!.id);
    }
  }

  // After queued offline mutations reach the server, refresh synced lists
  Future<void> _onOutboxFlushed() async {
    await fetchDependents();
    await fetchAddresses();
    await fetchPaymentMethods();
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
    _authToken = null;
    _apiService.authToken = null;
    _userName = '';
    _userEmail = '';
    _isDemoMode = false;
    _isOnboarded = false;
    _currentRequest = null;
    _pendingMessages = 0;
    _activeTab = 'home';
    _initializeChat();
    _persistSession();
    DbHelper.instance.clearAll().catchError((e) => debugPrint('Error clearing local DB: $e'));
    notifyListeners();
  }

  // Restore a previously saved session token and load data
  Future<void> _restoreSession() async {
    try {
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
      } else {
        _currentRequest = null;
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
        timeout: const Duration(seconds: 8),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _applyAuthResponse(data);
        return null;
      }
      return data['message'] ?? 'No se pudo iniciar sesión con $provider.';
    } catch (e) {
      debugPrint('Backend social login failed. Error: $e');
      return 'No se pudo conectar con el servidor. Verifica tu conexión o usa el modo demo.';
    }
  }

  void _applyAuthResponse(Map<String, dynamic> data) {
    _authToken = data['token'];
    _apiService.authToken = _authToken;
    _userName = data['user']?['name'] ?? '';
    _userEmail = data['user']?['email'] ?? '';
    _isDemoMode = false;
    _persistSession();
    _loadInitialData();
    _pushService.register();
    notifyListeners();
  }

  // Explore the app without a backend account (local simulation only)
  void enterDemoMode() {
    _isDemoMode = true;
    _userName = 'Usuario Demo';
    _userEmail = 'demo@aurasalud.app';
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
    _authToken = null;
    _apiService.authToken = null;
    _userName = '';
    _userEmail = '';
    _isDemoMode = false;
    _isOnboarded = false;
    _currentRequest = null;
    _pendingMessages = 0;
    _activeTab = 'home';
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

  List<ClinicalService> get services => _services;
  List<Dependent> get dependents => _dependents;
  List<SavedAddress> get addresses => _addresses;
  List<SavedPaymentMethod> get paymentMethods => _paymentMethods;
  List<PastService> get pastServices => _pastServices;

  ClinicalService? get selectedService => _selectedService;
  ServiceRequest? get currentRequest => _currentRequest;
  bool get isSearchingDoctor => _isSearchingDoctor;

  int get pendingMessages => _pendingMessages;
  String get currentRole => _currentRole;
  bool get isChatTyping => _isChatTyping;
  List<ChatMessage> get chatMessages => _chatMessages;

  // Filtered Services List
  List<ClinicalService> get filteredServices {
    return _services.where((service) {
      final matchesSearch = service.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());

      if (_selectedFilterCategory == 'require_rx') {
        return matchesSearch && service.requiresPrescription;
      }
      if (_selectedFilterCategory == 'no_rx') {
        return matchesSearch && !service.requiresPrescription;
      }
      return matchesSearch;
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
        await DbHelper.instance.saveDependents(_dependents);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchDependents failed, loading from local DB. Error: $e');
      final localDeps = await DbHelper.instance.getDependents();
      if (localDeps.isNotEmpty) {
        _dependents.clear();
        _dependents.addAll(localDeps);
        notifyListeners();
      }
    }
  }

  Future<void> fetchAddresses() async {
    try {
      final response = await _apiService.get('/addresses');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _addresses.clear();
        _addresses.addAll(data.map((a) => SavedAddress.fromJson(a)).toList());
        await DbHelper.instance.saveAddresses(_addresses);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchAddresses failed, loading from local DB. Error: $e');
      final localAddrs = await DbHelper.instance.getAddresses();
      if (localAddrs.isNotEmpty) {
        _addresses.clear();
        _addresses.addAll(localAddrs);
        notifyListeners();
      }
    }
  }

  Future<void> fetchPaymentMethods() async {
    try {
      final response = await _apiService.get('/payment-methods');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _paymentMethods.clear();
        _paymentMethods.addAll(data.map((p) => SavedPaymentMethod.fromJson(p)).toList());
        await DbHelper.instance.savePaymentMethods(_paymentMethods);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchPaymentMethods failed, loading from local DB. Error: $e');
      final localPays = await DbHelper.instance.getPaymentMethods();
      if (localPays.isNotEmpty) {
        _paymentMethods.clear();
        _paymentMethods.addAll(localPays);
        notifyListeners();
      }
    }
  }

  Future<void> fetchActiveRequest() async {
    try {
      final response = await _apiService.get('/bookings/active');
      if (response.statusCode == 200 && response.body.isNotEmpty && response.body != 'null') {
        final Map<String, dynamic> data = json.decode(response.body);
        _currentRequest = ServiceRequest.fromJson(data);
        await DbHelper.instance.saveBookings([_currentRequest!]);
        startActiveBookingStream(_currentRequest!.id);
        await fetchChatMessages(_currentRequest!.id);
      } else {
        stopActiveBookingStream();
        _currentRequest = null;
        await DbHelper.instance.saveBookings([]);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Backend fetchActiveRequest failed, loading from local DB. Error: $e');
      final localBookings = await DbHelper.instance.getBookings();
      final active = localBookings.where((b) => b.status != RequestStatus.completed && b.status != RequestStatus.cancelled).toList();
      if (active.isNotEmpty) {
        _currentRequest = active.first;
        startActiveBookingStream(_currentRequest!.id);
        await fetchChatMessages(_currentRequest!.id);
      } else {
        _currentRequest = null;
      }
      notifyListeners();
    }
  }

  Future<void> fetchChatMessages(String requestId) async {
    try {
      final response = await _apiService.get('/bookings/$requestId/chat');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _chatMessages.clear();
        _chatMessages.addAll(data.map((m) => ChatMessage.fromJson(m)).toList());
        await DbHelper.instance.saveChatMessages(requestId, _chatMessages);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchChatMessages failed, loading from local DB. Error: $e');
      final localMsgs = await DbHelper.instance.getChatMessages(requestId);
      if (localMsgs.isNotEmpty) {
        _chatMessages.clear();
        _chatMessages.addAll(localMsgs);
        notifyListeners();
      }
    }
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
    if (tab == 'messages') {
      _pendingMessages = 0;
    }
    notifyListeners();
  }

  void setOnboarded(bool value) {
    _isOnboarded = value;
    notifyListeners();
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

  void _initializeChat() {
    _chatMessages.clear();
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

  // Submit request and start match simulation
  Future<void> confirmRequest({
    required String patientType,
    String? dependentId,
    required String addressText,
    String? originAddress,
    String? destinationAddress,
    String? ambulanceType,
    String? symptomsDescription,
    String? prescriptionName,
    String? prescriptionPreview,
    required int finalPrice,
    required int etaMinutes,
  }) async {
    _isSearchingDoctor = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/bookings',
        body: {
          'service_id': _selectedService!.id,
          'patient_type': patientType,
          'dependent_id': dependentId,
          'address_text': addressText,
          'origin_address': originAddress,
          'destination_address': destinationAddress,
          'ambulance_type': ambulanceType,
          'symptoms_description': symptomsDescription,
          'prescription_name': prescriptionName,
          'prescription_preview': prescriptionPreview,
          'final_price': finalPrice,
          'eta_minutes': etaMinutes,
        },
      );

      _isSearchingDoctor = false;

      if (response.statusCode == 201) {
        _selectedService = null;
        await fetchActiveRequest();

        if (_currentRequest?.status == RequestStatus.pendingPayment) {
          // Real gateway flow: take the user to the payment screen and
          // open the Mercado Pago checkout in the browser
          _activeTab = 'appointments';
          notifyListeners();
          await launchPaymentCheckout();
        } else {
          _activeTab = 'home';
          _pendingMessages = 1;
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend confirmRequest failed, falling back to local simulation. Error: $e');
      // LOCAL FALLBACK SIMULATION:
      Timer(const Duration(milliseconds: 2800), () async {
        _isSearchingDoctor = false;

        final now = DateTime.now();
        final timeStr = DateFormat('HH:mm').format(now);

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
          symptomsDescription: symptomsDescription,
          prescriptionName: prescriptionName,
          prescriptionPreview: prescriptionPreview,
          paymentMethod: 'mercadopago',
          finalPrice: finalPrice,
          startTime: timeStr,
          etaMinutes: etaMinutes,
          currentStep: 1,
        );

        _selectedService = null;
        _activeTab = 'home';
        _pendingMessages = 1;

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

        notifyListeners();
      });
    }
  }

  // Advance simulation step
  Future<void> simulateNextStep() async {
    if (_currentRequest == null) return;

    try {
      final response = await _apiService.post('/bookings/${_currentRequest!.id}/simulate-step');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _currentRequest = ServiceRequest.fromJson(data);
        await DbHelper.instance.saveBookings([_currentRequest!]);
        _pendingMessages += 1;
        await fetchChatMessages(_currentRequest!.id);
        
        // If it was completed, reload past services history from backend
        if (_currentRequest!.currentStep == 4) {
          await fetchHistory();
        }
      }
    } catch (e) {
      debugPrint('Backend simulateNextStep failed, running local memory simulation. Error: $e');
      // Local simulation logic
      final currentStep = _currentRequest!.currentStep;
      RequestStatus nextStatus;
      int nextStep;

      if (currentStep == 1) {
        nextStatus = RequestStatus.enCamino;
        nextStep = 2;
      } else if (currentStep == 2) {
        nextStatus = RequestStatus.enAtencion;
        nextStep = 3;
      } else if (currentStep == 3) {
        nextStatus = RequestStatus.completed;
        nextStep = 4;
      } else {
        return;
      }

      _currentRequest = _currentRequest!.copyWith(
        status: nextStatus,
        currentStep: nextStep,
      );

      final timeStr = DateFormat('HH:mm').format(DateTime.now());

      if (nextStep == 2) {
        _pendingMessages += 1;
        _chatMessages.add(ChatMessage(
          id: 'msg_step2_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'provider',
          text: 'He ingresado a la autopista principal. El tráfico es moderado, voy en camino directo a tu domicilio.',
          timestamp: timeStr,
        ));
      } else if (nextStep == 3) {
        _pendingMessages += 1;
        _chatMessages.add(ChatMessage(
          id: 'msg_step3_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'provider',
          text: 'Acabo de llegar al domicilio. Por favor, indíqueme el número de timbre o si hay conserjería para anunciar mi ingreso.',
          timestamp: timeStr,
        ));
      } else if (nextStep == 4) {
        _chatMessages.add(ChatMessage(
          id: 'msg_step4_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'system',
          text: 'Atención completada con éxito. Resumen médico disponible en el historial.',
          timestamp: timeStr,
        ));
        
        // Simulating writing a past service locally
        final serviceTitle = _services.firstWhere((s) => s.id == _currentRequest!.serviceId).title;
        _pastServices.insert(0, PastService(
          id: 'past_${DateTime.now().millisecondsSinceEpoch}',
          serviceTitle: serviceTitle,
          serviceId: _currentRequest!.serviceId,
          date: 'Hoy',
          patient: _currentRequest!.patientType == 'self' ? 'Usuario Principal' : 'Familiar',
          price: _currentRequest!.finalPrice,
          status: 'completed',
          details: 'Atención completada con éxito. Procedimiento realizado en domicilio de forma satisfactoria.',
          professional: 'Personal de Guardia Aura',
        ));
        await DbHelper.instance.savePastServices(_pastServices);
      }

      await DbHelper.instance.saveBookings([_currentRequest!]);
      await DbHelper.instance.saveChatMessages(_currentRequest!.id, _chatMessages);

      notifyListeners();
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
        return (data['slots'] as List<dynamic>)
            .map((iso) => DateTime.parse(iso as String).toLocal())
            .toList();
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
      final response = await _apiService.post(
        '/appointments',
        body: {
          'professional_id': professionalId,
          'scheduled_at': scheduledAt.toIso8601String(),
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

  // Join a video consultation: fetches a fresh meeting token and opens
  // the Daily room. Returns null on success or an error message.
  Future<String?> joinVideoCall(String appointmentId) async {
    try {
      final response = await _apiService.get(
        '/appointments/$appointmentId/video-join',
        timeout: const Duration(seconds: 10),
      );
      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200 && data['join_url'] != null) {
        await launchUrl(
          Uri.parse(data['join_url'] as String),
          mode: LaunchMode.externalApplication,
        );
        return null;
      }
      return (data['error'] ?? 'No se pudo abrir la videoconsulta.') as String;
    } catch (e) {
      debugPrint('joinVideoCall failed. Error: $e');
      return 'Sin conexión. Intenta de nuevo.';
    }
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
          _pendingMessages = 1;
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
    _currentRequest = null;
    _pendingMessages = 0;
    _initializeChat();
    notifyListeners();
  }

  // Send message in chat and simulate reply
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _currentRequest == null) return;

    _isChatTyping = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/bookings/${_currentRequest!.id}/chat',
        body: {'text': text},
      );

      _isChatTyping = false;

      if (response.statusCode == 201) {
        await fetchChatMessages(_currentRequest!.id);
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend sendMessage failed, using local simulation. Error: $e');
      // Local fallback chat message
      final timeStr = DateFormat('HH:mm').format(DateTime.now());
      _chatMessages.add(ChatMessage(
        id: 'm_patient_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'patient',
        text: text,
        timestamp: timeStr,
      ));
      DbHelper.instance.saveChatMessages(_currentRequest!.id, _chatMessages);

      _isChatTyping = true;
      notifyListeners();

      Timer(const Duration(seconds: 2), () async {
        _isChatTyping = false;

        String replyText = 'Entendido. Ya voy con todos los insumos necesarios de grado clínico. Llego según el tiempo estipulado. Mantenga el hogar a una temperatura agradable, por favor.';
        final userTextLower = text.toLowerCase();

        if (userTextLower.contains('fiebre') || userTextLower.contains('temperatura')) {
          replyText = 'Llevo un termómetro clínico calibrado e insumos para ayudar a controlar la temperatura inmediatamente a mi llegada.';
        } else if (userTextLower.contains('dirección') || userTextLower.contains('calle') || userTextLower.contains('ubicacion') || userTextLower.contains('dirección')) {
          replyText = 'Gracias por la aclaración, el GPS me indica la ruta óptima. Llego según el tiempo estipulado.';
        } else if (userTextLower.contains('pago') || userTextLower.contains('pagar') || userTextLower.contains('precio')) {
          replyText = 'No se preocupe, visualizo que su pago ya fue procesado a través de su cuenta de forma 100% segura. No debe abonar nada extra al personal.';
        }

        _chatMessages.add(ChatMessage(
          id: 'm_reply_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'provider',
          text: replyText,
          timestamp: DateFormat('HH:mm').format(DateTime.now()),
        ));

        if (_currentRequest != null) {
          await DbHelper.instance.saveChatMessages(_currentRequest!.id, _chatMessages);
        }

        notifyListeners();
      });
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
        _reconnectActiveBookingStream(requestId);
        return;
      }

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
                bool updated = false;

                // Avoid redundant updates if nothing changed
                if (_currentRequest == null ||
                    _currentRequest!.status != newRequest.status ||
                    _currentRequest!.currentStep != newRequest.currentStep) {
                  _currentRequest = newRequest;
                  await DbHelper.instance.saveBookings([_currentRequest!]);
                  updated = true;
                }

                if (data.containsKey('messages')) {
                  final List<dynamic> msgsList = data['messages'] as List<dynamic>;
                  final newMessages = msgsList.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
                  
                  if (_chatMessages.length != newMessages.length ||
                      (_chatMessages.isNotEmpty && _chatMessages.last.text != newMessages.last.text)) {
                    _chatMessages.clear();
                    _chatMessages.addAll(newMessages);
                    await DbHelper.instance.saveChatMessages(newRequest.id, _chatMessages);
                    updated = true;
                  }
                }

                if (updated) {
                  notifyListeners();
                }
              }
            } catch (e) {
              debugPrint('Error decoding SSE payload: $e');
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

  void _reconnectActiveBookingStream(String requestId) {
    if (_currentRequest == null ||
        _currentRequest!.id != requestId ||
        _currentRequest!.status == RequestStatus.completed ||
        _currentRequest!.status == RequestStatus.cancelled) {
      return;
    }
    // Reconnect after 3 seconds
    Timer(const Duration(seconds: 3), () {
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

  @override
  void dispose() {
    stopActiveBookingStream();
    super.dispose();
  }
}
