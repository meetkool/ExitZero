import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exitzero/pages/dashboard_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Dashboard loads correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pumpAndSettle(); // Wait for animations and futures

    // Verify key elements are present
    expect(find.text('Daily Survival'), findsOneWidget);
    expect(find.text('ACCOUNTABILITY ENGINE'), findsOneWidget); // Uppercase in UI
    expect(find.byIcon(Icons.add), findsOneWidget); // FAB
  });
}
