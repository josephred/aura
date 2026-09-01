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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator_android'),
      (MethodCall methodCall) async => null,
    );

    final matFile = File(r'C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf');
    if (matFile.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(Future.value(ByteData.view(matFile.readAsBytesSync().buffer)));
      await loader.load();
    }

    final robotoRegular = File(r'C:\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf');
    if (robotoRegular.existsSync()) {
      final loader = FontLoader('Roboto');
      loader.addFont(Future.value(ByteData.view(robotoRegular.readAsBytesSync().buffer)));
      await loader.load();
    }
  });

  testWidgets('Capture Home Screen test', (tester) async {
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
              child: Scaffold(
                body: HomeScreen(
                  state: state,
                  onSelectService: (_) {},
                ),
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

    final outDir = Directory(r'c:\github\aura\screenshots');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    File(r'c:\github\aura\screenshots\01_test_home.png').writeAsBytesSync(
      byteData!.buffer.asUint8List(),
    );

    print('SCREENSHOT SAVED: ${File(r'c:\github\aura\screenshots\01_test_home.png').existsSync()}');
  });
}
