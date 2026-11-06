import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/activity_provider.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'teacher/teacher_home.dart';
import 'student/student_home.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthProvider>();
    final error = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted) return;
    setState(() { _loading = false; });

    if (error != null) {
      setState(() { _error = error; });
      return;
    }

    final activity = context.read<ActivityProvider>();
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

    if (!mounted) return;
    _navigateByRole(auth.currentUser!);
  }

  void _navigateByRole(User user) {
    Widget screen = user.role == UserRole.teacher
        ? const TeacherHome()
        : const StudentHome();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _fillDemo(String email, String pass) {
    setState(() {
      _emailCtrl.text = email;
      _passwordCtrl.text = pass;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Top circular icon container
              Center(
                child: Container(
                  width: 95,
                  height: 95,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.borderLight),
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
              ),
              const SizedBox(height: 24),
              const Text(
                'EduSync',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Digital Classroom, Seamless Grades',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Demo Switcher Pills
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Quick Demo Login',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Tap to fill',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _fillDemo('teacher@edusync.com', 'teacher123'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSoft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '👩‍🏫 Teacher',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                  ),
                                  SizedBox(height: 2),
                                  Text('teacher@edusync.com', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _fillDemo('juan@edusync.com', 'student123'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSoft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🎓 Student',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                  ),
                                  SizedBox(height: 2),
                                  Text('juan@edusync.com', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMain),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.alternate_email_rounded, color: AppTheme.textSecondary),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter your email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMain),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter your password' : null,
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusMissing.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.statusMissing.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.statusMissing, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.statusMissing, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              // Gradient Login Button
              InkWell(
                onTap: _loading ? null : _login,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.floatingShadow,
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
