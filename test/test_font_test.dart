import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/state/app_state.dart';
import 'package:aura/theme/app_theme.dart';
import 'package:aura/screens/home_screen.dart';

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

  testWidgets('Test font render on Home Screen', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;

    final boundaryKey = GlobalKey();
    final state = AppState();
    state.enterDemoMode();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundaryKey,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(393, 852),
              padding: EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: Scaffold(
              body: HomeScreen(
                state: state,
                onSelectService: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    File(r'c:\github\aura\screenshots\test_font_home.png').writeAsBytesSync(
      byteData!.buffer.asUint8List(),
    );

    print('CAPTURED TEST FONT IMAGE!');
  });
}
