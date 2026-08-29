import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/payment_pending_screen.dart';
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
import 'theme/app_theme.dart';
import 'ui/aura.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  // Accept self-signed certs only outside release (e.g. a local SSL proxy).
  // ngrok and production serve valid certificates, so no override is needed
  // there — and it must never weaken TLS in a shipped app.
  if (!kReleaseMode) {
    HttpOverrides.global = MyHttpOverrides();
  }
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState()..addListener(_onStateChange);
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
    return MaterialApp(
      title: 'Aura Salud',
      debugShowCheckedModeBanner: false,
      themeMode: _appState.themeMode,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);

        // El ajuste de la app *multiplica* la preferencia del sistema, no la
        // reemplaza. Antes se pasaba `textScaleFactor` a secas: alguien que
        // había puesto la letra al 200% en los ajustes de accesibilidad de su
        // teléfono abría Aura y veía 1.15, es decir, la app deshacía en
        // silencio una decisión que esa persona sí se había tomado el trabajo
        // de configurar.
        //
        // El techo de 2.0 es lo que exige WCAG 1.4.4 (redimensionar hasta el
        // 200% sin perder contenido) y a la vez el punto donde las tarjetas
        // dejan de soportar más crecimiento sin desbordarse.
        final systemScale = mediaQueryData.textScaler.scale(1.0);
        final combinedScale =
            (systemScale * _appState.textScaleFactor).clamp(0.85, 2.0);

        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: TextScaler.linear(combinedScale),
          ),
          child: child!,
        );
      },
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: MainShell(appState: _appState),
    );
  }
}

class MainShell extends StatefulWidget {
  final AppState appState;
  const MainShell({super.key, required this.appState});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = widget.appState;
    _appState.addListener(_onStateChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.removeListener(_onStateChange);
    super.dispose();
  }

  /// Volver del segundo plano tiene que traer lo que pasó mientras tanto.
  ///
  /// El stream SSE de la reserva no sobrevive a que el sistema congele la app,
  /// y nada lo reabría hasta el siguiente arranque en frío: un mensaje escrito
  /// por el profesional con el teléfono bloqueado se quedaba en el servidor.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appState.handleAppResumed();
    }
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
      final p = context.palette;
      return Scaffold(
        backgroundColor: p.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 88,
                width: 88,
                decoration: BoxDecoration(
                  color: p.accentSurface,
                  borderRadius: AuraRadius.allXl,
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: p.accentText,
                  size: AuraIcon.display,
                ),
              ),
              const SizedBox(height: AuraSpace.lg),
              Text(
                'Aura Salud',
                style: AppType.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: AuraSpace.xxl),
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: p.accent,
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
      return OnboardingScreen(state: _appState, onStart: () => _appState.setOnboarded(true));
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
        state: _appState,
        service: selectedService,
        dependents: _appState.dependents,
        addresses: _appState.addresses,
        commissionRate: _appState.commissionRate,
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
            }) {
              return _appState.confirmRequest(
                patientType: patientType,
                dependentId: dependentId,
                addressText: addressText,
                originAddress: originAddress,
                destinationAddress: destinationAddress,
                ambulanceType: ambulanceType,
                patientLat: patientLat,
                patientLng: patientLng,
                destinationLat: destinationLat,
                destinationLng: destinationLng,
                symptomsDescription: symptomsDescription,
                symptomAudioPath: symptomAudioPath,
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
          if (currentRequest != null &&
              currentRequest.status == RequestStatus.pendingPayment) {
            body = PaymentPendingScreen(
              state: _appState,
              request: currentRequest,
            );
          } else if (currentRequest != null) {
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            const _SearchingOverlay(),
        ],
      ),
    );
  }
}

/// Lo que se ve mientras se busca a un profesional.
///
/// La versión anterior pintaba, sobre un fondo casi negro, una lista de tres
/// tareas **todas marcadas como completadas**, siempre, desde el primer
/// milisegundo: «Orden Médica validada», «Ingresando a la cola de tu zona»,
/// «Notificando a los prestadores en turno del área…», en tipografía monoespaciada
/// como si fuera el registro de un sistema. Nada de eso venía de ningún estado
/// real —la primera línea aparecía incluso en servicios que no piden orden
/// médica— y el conjunto imitaba la estética de una consola para dar sensación
/// de maquinaria trabajando.
///
/// Es teatro, y de un tipo caro: la persona a la que se lo enseñamos acaba de
/// pagar y está esperando a alguien que vaya a su casa. Lo que hay ahora dice lo
/// único que se sabe con certeza —que se está avisando a los profesionales de su
/// zona— con calma y sin fingir progreso.
class _SearchingOverlay extends StatelessWidget {
  const _SearchingOverlay();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      color: p.background.withValues(alpha: 0.97),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.xxl),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 56,
                  width: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: p.accent,
                  ),
                ),
                const SizedBox(height: AuraSpace.xl),
                Text(
                  'Buscando quién te atienda',
                  textAlign: TextAlign.center,
                  style: AppType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: AuraSpace.xs),
                Text(
                  'Estamos avisando a los profesionales de tu zona. '
                  'En cuanto alguien tome tu solicitud te lo decimos aquí.',
                  textAlign: TextAlign.center,
                  style: AppType.bodyMedium.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
