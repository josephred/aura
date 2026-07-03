import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/service_form_screen.dart';
import 'screens/active_tracking_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/custom_bottom_nav.dart';
import 'state/app_state.dart';
import 'models/service_request.dart';
import 'data/mock_data.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura Salud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488), // brand-primary (teal-600)
          primary: const Color(0xFF0D9488),
          secondary: const Color(0xFF115E59), // teal-800
          surface: Colors.white,
          background: const Color(0xFFF8FAFC), // slate-50
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(fontFamily: 'Inter', color: Color(0xFF0F172A)),
          bodyMedium: TextStyle(fontFamily: 'Inter', color: Color(0xFF334155)),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // While restoring a saved session, show a lightweight splash
    if (_appState.isRestoringSession) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'AURA Salud',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF0D9488),
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If user has not onboarded, show Onboarding Screen
    if (!_appState.isOnboarded && !_appState.isAuthenticated) {
      return OnboardingScreen(onStart: () => _appState.setOnboarded(true));
    }

    // Require login (or demo mode) before entering the app
    if (!_appState.isAuthenticated) {
      return AuthScreen(state: _appState);
    }

    final activeTab = _appState.activeTab;
    final selectedService = _appState.selectedService;
    final currentRequest = _appState.currentRequest;

    Widget body;
    bool hideBottomNav = false;

    // Route logic
    if (selectedService != null) {
      hideBottomNav = true;
      body = ServiceFormScreen(
        service: selectedService,
        dependents: _appState.dependents,
        addresses: _appState.addresses,
        onAddDependentRedirect: () {
          _appState.selectService(null);
          _appState.setTab('profile');
        },
        onBack: () => _appState.selectService(null),
        onConfirmRequest:
            ({
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
            }) {
              _appState.confirmRequest(
                patientType: patientType,
                dependentId: dependentId,
                addressText: addressText,
                originAddress: originAddress,
                destinationAddress: destinationAddress,
                ambulanceType: ambulanceType,
                symptomsDescription: symptomsDescription,
                prescriptionName: prescriptionName,
                prescriptionPreview: prescriptionPreview,
                finalPrice: finalPrice,
                etaMinutes: etaMinutes,
              );
            },
      );
    } else {
      switch (activeTab) {
        case 'home':
          body = HomeScreen(
            state: _appState,
            onSelectService: (service) => _appState.selectService(service),
          );
          break;
        case 'appointments':
          if (currentRequest != null) {
            final dep = currentRequest.patientType == 'dependent'
                ? _appState.dependents.firstWhere(
                    (d) => d.id == currentRequest.dependentId,
                    orElse: () => _appState.dependents.first,
                  )
                : null;

            body = ActiveTrackingScreen(
              state: _appState,
              request: currentRequest,
              dependent: dep,
              onNavigateToChat: () => _appState.setTab('messages'),
            );
          } else {
            body = HistoryScreen(
              state: _appState,
              onRepeatService: (serviceId) {
                final service = clinicalServices.firstWhere(
                  (s) => s.id == serviceId,
                );
                _appState.selectService(service);
              },
            );
          }
          break;
        case 'messages':
          body = ChatScreen(
            state: _appState,
            onBack: () => _appState.setTab('home'),
          );
          break;
        case 'profile':
          body = ProfileScreen(state: _appState);
          break;
        default:
          body = HomeScreen(
            state: _appState,
            onSelectService: (service) => _appState.selectService(service),
          );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: SafeArea(bottom: false, child: body)),
              if (!hideBottomNav)
                CustomBottomNav(
                  activeTab: activeTab,
                  onTabChange: (tab) => _appState.setTab(tab),
                  pendingMessagesCount: _appState.pendingMessages,
                  activeAppointmentsCount:
                      (currentRequest != null &&
                          currentRequest.status != RequestStatus.completed &&
                          currentRequest.status != RequestStatus.cancelled)
                      ? 1
                      : 0,
                ),
            ],
          ),
          // Searching Doctor full-screen overlay matching web
          if (_appState.isSearchingDoctor)
            _SearchingOverlay(serviceTitle: selectedService?.title ?? 'Médico'),
        ],
      ),
    );
  }
}

class _SearchingOverlay extends StatefulWidget {
  final String serviceTitle;

  const _SearchingOverlay({required this.serviceTitle});

  @override
  State<_SearchingOverlay> createState() => _SearchingOverlayState();
}

class _SearchingOverlayState extends State<_SearchingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(
        0xFF0F172A,
      ).withValues(alpha: 0.95), // brand-dark / 95% opacity
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing heart pulse spinner mockup
              ScaleTransition(
                scale: _pulseAnimation,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      height: 90,
                      width: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(
                      height: 76,
                      width: 76,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2DD4BF),
                        ),
                        strokeWidth: 4,
                      ),
                    ),
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFF2DD4BF),
                      size: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Conectando Guardia Aura',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ASIGNANDO PROFESIONAL CLÍNICO...',
                style: TextStyle(
                  color: Color(0xFF2DD4BF),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 32),
              // Logs checklist
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LogCheckRow(text: 'Orden Médica validada'),
                    SizedBox(height: 8),
                    _LogCheckRow(text: 'Buscando radio de 5km geo-asistido'),
                    SizedBox(height: 8),
                    _LogCheckRow(text: 'Notificando enfermero calificado...'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogCheckRow extends StatelessWidget {
  final String text;

  const _LogCheckRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check, color: Color(0xFF2DD4BF), size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFCCFBF1),
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
