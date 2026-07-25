// Smoke tests for the Nestora login flow.

import 'package:flutter_test/flutter_test.dart';

import 'package:nestora/main.dart';

void main() {
  testWidgets('Role selection screen lists all four login roles',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NestoraApp());

    expect(find.text('Society Admin'), findsOneWidget);
    expect(find.text('Security Guard'), findsOneWidget);
    expect(find.text('Resident'), findsOneWidget);
    expect(find.text('Maintenance Staff'), findsOneWidget);
  });

  testWidgets('Tapping a role opens its login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NestoraApp());

    await tester.tap(find.text('Resident'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in as Resident'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
