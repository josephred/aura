import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/state/app_state.dart';
import 'package:aura/theme/app_theme.dart';
import 'package:aura/models/clinical_service.dart';
import 'package:aura/models/service_request.dart';
import 'package:aura/models/appointment.dart';
import 'package:aura/models/professional.dart';
import 'package:aura/models/dependent.dart';
import 'package:aura/models/saved_address.dart';

import 'package:aura/screens/auth_screen.dart';
import 'package:aura/screens/onboarding_screen.dart';
import 'package:aura/screens/home_screen.dart';
import 'package:aura/screens/service_form_screen.dart';
import 'package:aura/screens/payment_pending_screen.dart';
import 'package:aura/screens/active_tracking_screen.dart';
import 'package:aura/screens/chat_screen.dart';
import 'package:aura/screens/appointments_screen.dart';
import 'package:aura/screens/book_appointment_screen.dart';
import 'package:aura/screens/history_screen.dart';
import 'package:aura/screens/lab_results_screen.dart';
import 'package:aura/screens/preventive_health_screen.dart';
import 'package:aura/screens/subscription_plans_screen.dart';
import 'package:aura/screens/doctor_profile_screen.dart';
import 'package:aura/screens/video_call_screen.dart';
import 'package:aura/screens/profile_screen.dart';
import 'package:aura/screens/staff_dashboard.dart';
import 'package:aura/screens/operations_dashboard.dart';

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    HttpOverrides.global = TestHttpOverrides();

    final matFile = File(r'C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf');
    if (matFile.existsSync()) {
      final matLoader = FontLoader('MaterialIcons');
      matLoader.addFont(Future.value(ByteData.view(matFile.readAsBytesSync().buffer)));
      await matLoader.load();
    }

    final robotoRegular = File(r'C:\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf');
    if (robotoRegular.existsSync()) {
      for (final fontName in ['Roboto', 'Ahem', 'packages/flutter/Ahem', '']) {
        final loader = FontLoader(fontName);
        loader.addFont(Future.value(ByteData.view(robotoRegular.readAsBytesSync().buffer)));
        await loader.load();
      }
    }

    final outDir = Directory(r'c:\github\aura\screenshots');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
  });

  testWidgets('Generate all 18 Aura screenshots with real readable fonts', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final mockChannels = [
      'flutter.baseflow.com/geolocator',
      'flutter.baseflow.com/geolocator_android',
      'plugins.it_nomads.com/flutter_secure_storage',
      'plugins.flutter.io/path_provider',
      'dev.fluttercommunity.plus/connectivity',
      'com.tekartik.sqflite',
    ];

    for (final ch in mockChannels) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(ch),
        (MethodCall methodCall) async {
          if (methodCall.method == 'checkConnectivity') return ['wifi'];
          if (methodCall.method.contains('Directory') || methodCall.method.contains('Path')) {
            return Directory.systemTemp.path;
          }
          return null;
        },
      );
    }

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Method'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'createVideoRenderer') return {'textureId': 1};
        if (methodCall.method == 'initialize') return true;
        return null;
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Event'),
      (MethodCall methodCall) async => null,
    );

    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.runAsync(() async {
      final state = AppState();
      state.enterDemoMode();

      Future<void> capture(String filename, Widget child, {ThemeData? theme}) async {
        final boundaryKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: (theme ?? AppTheme.dark).copyWith(
              textTheme: (theme ?? AppTheme.dark).textTheme.apply(fontFamily: 'Roboto'),
            ),
            debugShowCheckedModeBanner: false,
            home: DefaultTextStyle(
              style: const TextStyle(fontFamily: 'Roboto'),
              child: SizedBox(
                width: 393,
                height: 852,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(393, 852),
                      padding: EdgeInsets.only(top: 44, bottom: 34),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        final file = File('c:\\github\\aura\\screenshots\\$filename');
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
        print('CAPTURE OK: $filename (${file.lengthSync()} bytes)');
      }

      print('1. Capturing 01_login_auth.png...');
      await capture('01_login_auth.png', AuthScreen(state: state));

      print('2. Capturing 02_onboarding_bienvenida.png...');
      await capture('02_onboarding_bienvenida.png', OnboardingScreen(state: state, onStart: () {}));

      print('3. Capturing 03_inicio_catalogo_servicios.png...');
      await capture('03_inicio_catalogo_servicios.png', HomeScreen(state: state, onSelectService: (_) {}));

      print('4. Capturing 04_formulario_solicitud_medica.png...');
      final service = state.services.first;
      await capture(
        '04_formulario_solicitud_medica.png',
        ServiceFormScreen(
          state: state,
          service: service,
          dependents: state.dependents,
          addresses: state.addresses,
          onAddDependentRedirect: () {},
          onConfirmRequest: ({
            required patientType,
            dependentId,
            required addressText,
            originAddress,
            destinationAddress,
            ambulanceType,
            patientLat,
            patientLng,
            destinationLat,
            destinationLng,
            symptomsDescription,
            symptomAudioPath,
            prescriptionName,
            prescriptionPreview,
            required finalPrice,
            required etaMinutes,
          }) {},
          onBack: () {},
          commissionRate: 0.15,
        ),
      );

      print('5. Capturing 05_confirmacion_pago_resumen.png...');
      final payReq = ServiceRequest(
        id: 'req_demo_pay',
        serviceId: 'medico',
        status: RequestStatus.pendingPayment,
        patientType: 'self',
        addressText: 'Calle Los Alerces 1420, Providencia',
        finalPrice: 40000,
        startTime: '14:30',
        etaMinutes: 35,
        currentStep: 1,
        paymentMethod: 'mercadopago',
      );
      await capture('05_confirmacion_pago_resumen.png', PaymentPendingScreen(state: state, request: payReq));

      print('6. Capturing 06_seguimiento_en_vivo_mapa.png...');
      final trackReq = ServiceRequest(
        id: 'req_demo_track',
        serviceId: 'medico',
        status: RequestStatus.enCamino,
        patientType: 'dependent',
        dependentId: 'dep_1',
        addressText: 'Calle Los Alerces 1420, Providencia',
        finalPrice: 40000,
        startTime: '14:15',
        etaMinutes: 18,
        currentStep: 2,
        paymentMethod: 'mercadopago',
        professionalName: 'Dra. Camila Rivera',
        professionalSpecialty: 'Medicina Interna',
        professionalPhone: '+56 9 8765 4321',
        professionalLat: -33.4250,
        professionalLng: -70.6150,
        patientLat: -33.4280,
        patientLng: -70.6120,
      );
      await capture(
        '06_seguimiento_en_vivo_mapa.png',
        ActiveTrackingScreen(
          state: state,
          request: trackReq,
          onNavigateToChat: () {},
        ),
      );

      print('7. Capturing 07_chat_medico_paciente.png...');
      await capture('07_chat_medico_paciente.png', ChatScreen(state: state, onBack: () {}));

      print('8. Capturing 08_mis_atenciones_agenda.png...');
      await capture('08_mis_atenciones_agenda.png', AppointmentsScreen(state: state));

      print('9. Capturing 09_agendar_especialista.png...');
      await capture('09_agendar_especialista.png', BookAppointmentScreen(state: state));

      print('10. Capturing 10_historial_clinico.png...');
      await capture('10_historial_clinico.png', HistoryScreen(state: state, onRepeatService: (_) {}));

      print('11. Capturing 11_examenes_laboratorio.png...');
      await capture('11_examenes_laboratorio.png', LabResultsScreen(state: state));

      print('12. Capturing 12_salud_preventiva_vacunas.png...');
      await capture('12_salud_preventiva_vacunas.png', PreventiveHealthScreen(state: state));

      print('13. Capturing 13_planes_suscripcion.png...');
      await capture('13_planes_suscripcion.png', SubscriptionPlansScreen(state: state));

      print('14. Capturing 14_perfil_profesional_medico.png...');
      final doc = Professional(
        id: 'prof_camila',
        name: 'Dra. Camila Rivera N.',
        specialty: 'Médico Internista',
        consultationPrice: 40000,
        consultationDurationMinutes: 45,
        registrationNumber: 'SIS-784129',
        yearsOfExperience: 9,
        bio: 'Especialista en medicina interna y atención domiciliaria geriátrica y de urgencia ambulatoria.',
        ratingAvg: 4.9,
        ratingCount: 42,
      );
      await capture('14_perfil_profesional_medico.png', DoctorProfileScreen(professional: doc, phone: '+56 9 8765 4321'));

      print('15. Capturing 15_telemedicina_videollamada.png...');
      final apt = Appointment(
        id: 'apt_demo_vid',
        professionalId: 'prof_ignacio',
        professionalName: 'Dr. Ignacio Morales',
        specialty: 'Medicina General',
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
        durationMinutes: 30,
        reason: 'Control médico general',
        status: AppointmentStatus.confirmed,
        price: 25000,
        type: 'video',
      );
      await capture('15_telemedicina_videollamada.png', VideoCallScreen(state: state, appointment: apt, iceServers: const []));

      print('16. Capturing 16_perfil_usuario_familiares.png...');
      await capture('16_perfil_usuario_familiares.png', ProfileScreen(state: state));

      print('17. Capturing 17_panel_medico_staff.png...');
      await capture('17_panel_medico_staff.png', StaffDashboard(state: state));

      print('18. Capturing 18_panel_operaciones_admin.png...');
      await capture('18_panel_operaciones_admin.png', OperationsDashboard(state: state));

      print('SUCCESS: ALL 18 SCREENSHOTS CAPTURED WITH READABLE FONTS!');
    });
  });
}
