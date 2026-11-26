import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:steal_here/main.dart';
import 'package:steal_here/core/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets(
    'Steal Here app loads successfully',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StealHereApp());

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(
        find.text('Luxury Deals. Powerful Experience.'),
        findsOneWidget,
      );
      expect(find.text('A smarter way to shop.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Dispose the app before the splash navigation timer completes.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}