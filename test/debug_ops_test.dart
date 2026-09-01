import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/state/app_state.dart';
import 'package:aura/theme/app_theme.dart';
import 'package:aura/screens/operations_dashboard.dart';

void main() {
  testWidgets('Debug OperationsDashboard error', (tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      print('FLUTTER ERROR: ${details.exceptionAsString()}');
      print(details.stack);
    };

    final state = AppState();
    state.enterDemoMode();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: OperationsDashboard(state: state),
        ),
      ),
    );
  });
}
