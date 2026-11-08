import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../teacher/teacher_home.dart';
import '../student/student_home.dart';
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

    final connectivity = context.read<ConnectivityProvider>();
    if (!connectivity.isOnline) {
      setState(() {
        _error = 'No internet connection. Please connect to Wi-Fi or mobile data to sign in.';
      });
      return;
    }

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

    // Start Firestore real-time sync after successful login
    if (auth.currentUser != null) {
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

  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController(text: _emailCtrl.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address and Firebase will send you a password reset link.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final email = resetCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final err = await auth.sendPasswordReset(email);
              if (!mounted) return;
              if (err == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset email sent! Check your inbox.'),
                    backgroundColor: AppTheme.statusGraded,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err),
                    backgroundColor: AppTheme.statusMissing,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
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

              const SizedBox(height: 12),
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
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
