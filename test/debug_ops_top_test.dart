import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/state/app_state.dart';
import 'package:aura/theme/app_theme.dart';
import 'package:aura/screens/operations_dashboard.dart';

void main() {
  testWidgets('Debug OperationsDashboard error top', (tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      File(r'c:\github\aura\screenshots\error.txt').writeAsStringSync(details.exceptionAsString());
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
