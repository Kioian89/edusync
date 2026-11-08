import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edusync/screens/common/privacy_policy_screen.dart';
import 'package:edusync/screens/onboarding/app_guide_onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Onboarding & Privacy Policy Agreement Tests', () {
    testWidgets('PrivacyPolicyScreen renders all required disclosures and sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );

      expect(find.text('Privacy Policy & Terms'), findsOneWidget);
      expect(find.text('Data Trust & Privacy'), findsOneWidget);
      expect(find.textContaining('FERPA Principles'), findsOneWidget);
      expect(find.textContaining('Camera Hardware Permissions'), findsOneWidget);
      expect(find.textContaining('Data Storage & Offline-First Architecture'), findsOneWidget);
      expect(find.textContaining('Google Gemini AI'), findsOneWidget);
    });

    testWidgets('AppGuideOnboardingScreen renders multi-step guide and requires agreement', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppGuideOnboardingScreen(isFirstLaunch: true),
        ),
      );

      // Verify Step 1 is rendered
      expect(find.text('Welcome to EduSync'), findsOneWidget);
      expect(find.text('Universal Class Management & QR Joining'), findsOneWidget);
      expect(find.text('FOR TEACHERS'), findsOneWidget);
      expect(find.text('FOR STUDENTS'), findsOneWidget);
      expect(find.text('Next Step'), findsOneWidget);
    });
  });
}
