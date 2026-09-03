import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obos_admin/core/app_theme.dart';

void main() {
  testWidgets('tema admin terpasang', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('Obos Admin')),
      ),
    );
    expect(find.text('Obos Admin'), findsOneWidget);
  });
}
