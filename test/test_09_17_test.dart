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
import 'package:aura/screens/book_appointment_screen.dart';
import 'package:aura/screens/staff_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
  });

  testWidgets('Test 09 and 17 capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;

    final state = AppState();
    state.enterDemoMode();

    Future<void> capture(String filename, Widget child) async {
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.dark.copyWith(
            textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
          ),
          debugShowCheckedModeBanner: false,
          home: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Roboto'),
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
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      File('c:\\github\\aura\\screenshots\\$filename').writeAsBytesSync(
        byteData!.buffer.asUint8List(),
      );
      print('CAPTURE OK: $filename');
    }

    await capture('09_agendar_especialista.png', BookAppointmentScreen(state: state));
    await capture('17_panel_medico_staff.png', StaffDashboard(state: state));
  });
}
