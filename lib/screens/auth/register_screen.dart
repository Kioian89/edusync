import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../models/user.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.student;
  String? _selectedClassId;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final connectivity = context.read<ConnectivityProvider>();
    if (!connectivity.isOnline) {
      setState(() {
        _error = 'No internet connection. Please connect to Wi-Fi or mobile data to register.';
      });
      return;
    }

    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthProvider>();
    final error = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: _selectedRole,
      classId: _selectedClassId,
    );

    if (!mounted) return;
    setState(() { _loading = false; });

    if (error != null) {
      setState(() { _error = error; });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created! Please sign in.'),
          backgroundColor: Colors.green),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Join EduSync',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create your account to get started.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                // Role selector
                Text('I am a...',
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                        value: UserRole.student,
                        label: Text('Student'),
                        icon: Icon(Icons.person)),
                    ButtonSegment(
                        value: UserRole.teacher,
                        label: Text('Teacher'),
                        icon: Icon(Icons.school)),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (s) =>
                      setState(() { _selectedRole = s.first; _selectedClassId = null; }),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 6) return 'At least 6 characters required';
                    return null;
                  },
                ),
                if (_selectedRole == UserRole.student) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Initial Class (Optional)',
                      prefixIcon: Icon(Icons.class_outlined),
                      helperText: 'You can also join any class later by scanning a QR code',
                      helperMaxLines: 2,
                    ),
                    hint: const Text('Join later with QR code'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Join later with QR code / Join code'),
                      ),
                      ...auth.classes.map((c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.displayName),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedClassId = v),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ',
                        style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

