import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/activity_provider.dart';
import 'landing_screen.dart';
import 'teacher/teacher_home.dart';
import 'student/student_home.dart';
import '../models/user.dart';
import '../services/shorebird_update_service.dart';

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
      backgroundColor: theme.colorScheme.primary,
      body: Center(
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
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Activity & Grade Management',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

