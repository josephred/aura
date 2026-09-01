import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/state/app_state.dart';
import 'package:aura/theme/app_theme.dart';
import 'package:aura/screens/book_appointment_screen.dart';

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

  testWidgets('Test BookAppointmentScreen capture', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;

    final boundaryKey = GlobalKey();
    final state = AppState();
    state.enterDemoMode();

    await tester.pumpWidget(
      MaterialApp(
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
              child: BookAppointmentScreen(state: state),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    File(r'c:\github\aura\screenshots\09_agendar_especialista.png').writeAsBytesSync(
      byteData!.buffer.asUint8List(),
    );

    print('CAPTURED BOOK APPOINTMENT SCREEN!');
  });
}
