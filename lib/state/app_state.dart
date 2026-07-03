import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_data.dart';
import '../models/clinical_service.dart';
import '../models/dependent.dart';
import '../models/saved_address.dart';
import '../models/saved_payment_method.dart';
import '../models/service_request.dart';
import '../models/chat_message.dart';
import '../models/past_service.dart';

class AppState extends ChangeNotifier {
  // Base URL configuration for both local Web and Android Emulator
  final String _baseUrl = kIsWeb ? 'http://localhost:8000/api' : 'http://10.0.2.2:8000/api';

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
    _initializeChat();
    _restoreSession();
  }

  // Headers for every API call; includes the bearer token once logged in
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // Restore a previously saved session token and load data
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        _authToken = token;
        _userName = prefs.getString('user_name') ?? '';
        _userEmail = prefs.getString('user_email') ?? '';
        await _loadInitialData();
      } else {
        // Only the public catalog is available before login
        await fetchServices();
      }
    } catch (e) {
      debugPrint('Session restore failed. Error: $e');
    }
    _isRestoringSession = false;
    notifyListeners();
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_authToken != null) {
      await prefs.setString('auth_token', _authToken!);
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_email', _userEmail);
    } else {
      await prefs.remove('auth_token');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
    }
  }

  // Register a new account. Returns null on success or an error message.
  Future<String?> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: _headers,
        body: json.encode({'name': name, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 6));

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
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _headers,
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 6));

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

  void _applyAuthResponse(Map<String, dynamic> data) {
    _authToken = data['token'];
    _userName = data['user']?['name'] ?? '';
    _userEmail = data['user']?['email'] ?? '';
    _isDemoMode = false;
    _persistSession();
    _loadInitialData();
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
    try {
      await http.post(Uri.parse('$_baseUrl/auth/logout'), headers: _headers)
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Backend logout failed (token cleared locally). Error: $e');
    }
    _authToken = null;
    _userName = '';
    _userEmail = '';
    _isDemoMode = false;
    _isOnboarded = false;
    _currentRequest = null;
    _pendingMessages = 0;
    _activeTab = 'home';
    _initializeChat();
    await _persistSession();
    notifyListeners();
  }

  // Load backend data on startup
  Future<void> _loadInitialData() async {
    await fetchServices();
    await fetchDependents();
    await fetchAddresses();
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
      final response = await http.get(Uri.parse('$_baseUrl/services'), headers: _headers).timeout(const Duration(seconds: 4));
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
      final response = await http.get(Uri.parse('$_baseUrl/dependents'), headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _dependents.clear();
        _dependents.addAll(data.map((d) => Dependent.fromJson(d)).toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchDependents failed, using local memory. Error: $e');
    }
  }

  Future<void> fetchAddresses() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/addresses'), headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _addresses.clear();
        _addresses.addAll(data.map((a) => SavedAddress.fromJson(a)).toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchAddresses failed, using local memory. Error: $e');
    }
  }

  Future<void> fetchActiveRequest() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/bookings/active'), headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body.isNotEmpty && response.body != 'null') {
        final Map<String, dynamic> data = json.decode(response.body);
        _currentRequest = ServiceRequest.fromJson(data);
        await fetchChatMessages(_currentRequest!.id);
      } else {
        _currentRequest = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Backend fetchActiveRequest failed. Error: $e');
    }
  }

  Future<void> fetchChatMessages(String requestId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/bookings/$requestId/chat'), headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _chatMessages.clear();
        _chatMessages.addAll(data.map((m) => ChatMessage.fromJson(m)).toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchChatMessages failed. Error: $e');
    }
  }

  Future<void> fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/history'), headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _pastServices.clear();
        _pastServices.addAll(data.map((p) => PastService.fromJson(p)).toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend fetchHistory failed. Error: $e');
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
    notifyListeners();

    // 2. Sync with backend
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/dependents'),
        headers: _headers,
        body: json.encode(dep.toJson()),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 201) {
        await fetchDependents();
      }
    } catch (e) {
      debugPrint('Backend addDependent failed, kept in local memory. Error: $e');
    }
  }

  Future<void> deleteDependent(String id) async {
    // 1. Local update
    _dependents.removeWhere((d) => d.id == id);
    notifyListeners();

    // 2. Sync with backend
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/dependents/$id'), headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        await fetchDependents();
      }
    } catch (e) {
      debugPrint('Backend deleteDependent failed. Error: $e');
    }
  }

  Future<void> addAddress(SavedAddress addr) async {
    // 1. Local update
    _addresses.add(addr);
    notifyListeners();

    // 2. Sync with backend
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/addresses'),
        headers: _headers,
        body: json.encode(addr.toJson()),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 201) {
        await fetchAddresses();
      }
    } catch (e) {
      debugPrint('Backend addAddress failed, kept in local memory. Error: $e');
    }
  }

  void addPaymentMethod(SavedPaymentMethod pay) {
    // Kept in local memory as simulated method
    _paymentMethods.add(pay);
    notifyListeners();
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
      final response = await http.post(
        Uri.parse('$_baseUrl/bookings'),
        headers: _headers,
        body: json.encode({
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
        }),
      ).timeout(const Duration(seconds: 4));

      _isSearchingDoctor = false;

      if (response.statusCode == 201) {
        _selectedService = null;
        _activeTab = 'home';
        _pendingMessages = 1;
        await fetchActiveRequest();
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend confirmRequest failed, falling back to local simulation. Error: $e');
      // LOCAL FALLBACK SIMULATION:
      Timer(const Duration(milliseconds: 2800), () {
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

        notifyListeners();
      });
    }
  }

  // Advance simulation step
  Future<void> simulateNextStep() async {
    if (_currentRequest == null) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/${_currentRequest!.id}/simulate-step'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _currentRequest = ServiceRequest.fromJson(data);
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
      }

      notifyListeners();
    }
  }

  Future<void> cancelRequest() async {
    if (_currentRequest == null) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/${_currentRequest!.id}/cancel'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _currentRequest = ServiceRequest.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend cancelRequest failed. Error: $e');
      _currentRequest = _currentRequest!.copyWith(
        status: RequestStatus.cancelled,
        currentStep: 0,
      );
      notifyListeners();
    }
  }

  void completeSimulation() {
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
      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/${_currentRequest!.id}/chat'),
        headers: _headers,
        body: json.encode({'text': text}),
      ).timeout(const Duration(seconds: 4));

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

      _isChatTyping = true;
      notifyListeners();

      Timer(const Duration(seconds: 2), () {
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

        notifyListeners();
      });
    }
  }
}
