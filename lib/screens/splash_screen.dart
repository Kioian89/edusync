import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/activity_provider.dart';
import 'auth/landing_screen.dart';
import 'teacher/teacher_home.dart';
import 'student/student_home.dart';
import '../models/user.dart';
import '../services/shorebird_update_service.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
    _init();
  }

  Future<void> _init() async {
    // Check Shorebird over-the-air patches in background
    ShorebirdUpdateService.downloadUpdateIfAvailable();

    final auth = context.read<AuthProvider>();
    final activity = context.read<ActivityProvider>();
    await auth.init();
    await activity.init();

    // Seed demo activities if teacher is logged in or if there are classes
    if (auth.classes.isNotEmpty) {
      final cls = auth.classes.first;
      final students = auth.studentsInClass(cls.id);
      await activity.seedDemoActivities(
        classId: cls.id,
        teacherId: cls.teacherId,
        studentIds: students.map((s) => s.id).toList(),
        studentNames: students.map((s) => s.name).toList(),
      );
    }

    // Start Firestore real-time sync if already logged in from a previous session
    if (auth.isLoggedIn && auth.currentUser != null) {
      auth.startListeningToClasses();
      final classIds = auth.classes.map((c) => c.id).toList();
      if (classIds.isNotEmpty) {
        activity.syncWithFirestore(
          userId: auth.currentUser!.id,
          isTeacher: auth.isTeacher,
          classIds: classIds,
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    if (auth.isLoggedIn) {
      _navigateByRole(auth.currentUser!);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LandingScreen()),
      );
    }
  }

  void _navigateByRole(User user) {
    Widget screen = user.role == UserRole.teacher
        ? const TeacherHome()
        : const StudentHome();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.heroCardGradient,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'EduSync',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digital Classroom & Seamless Grading',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

