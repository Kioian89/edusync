import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/activity_provider.dart';
import 'providers/gemini_assistant_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/assessment_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'widgets/connectivity_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase/Notification initialization error: $e');
  }
  runApp(const EduSyncApp());
}

class EduSyncApp extends StatelessWidget {
  const EduSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => GeminiAssistantProvider()),
        ChangeNotifierProvider(create: (_) => AssessmentProvider()..init()),
      ],
      child: MaterialApp(
        title: 'EduSync',
        debugShowCheckedModeBanner: false,
        builder: (context, child) => ConnectivityOverlay(child: child),
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppTheme.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppTheme.primary,
            primary: AppTheme.primary,
            surface: AppTheme.surface,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.plusJakartaSansTextTheme(
            ThemeData.light().textTheme,
          ),
          cardTheme: CardThemeData(
            color: AppTheme.cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppTheme.borderLight, width: 1),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppTheme.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: AppTheme.textMain),
            titleTextStyle: TextStyle(
              color: AppTheme.textMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.borderLight, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.borderLight, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
