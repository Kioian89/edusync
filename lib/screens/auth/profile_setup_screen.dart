import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../student/student_home.dart';
import '../teacher/teacher_home.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _yearLevelCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _employeeIdCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _coursesTaughtCtrl = TextEditingController();
  DateTime? _birthday;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _courseCtrl.dispose();
    _yearLevelCtrl.dispose();
    _sectionCtrl.dispose();
    _employeeIdCtrl.dispose();
    _departmentCtrl.dispose();
    _coursesTaughtCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = _birthday ?? DateTime(today.year - 18, 1, 1);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select your birthday',
    );
    if (selected != null) {
      setState(() {
        _birthday = DateUtils.dateOnly(selected);
      });
      _formKey.currentState?.validate();
    }
  }

  Future<void> _saveProfile(User user) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final error = await auth.completeCurrentUserProfile(
      studentId: user.role == UserRole.student ? _studentIdCtrl.text : null,
      birthday: user.role == UserRole.student ? _birthday : null,
      course: user.role == UserRole.student ? _courseCtrl.text : null,
      yearLevel: user.role == UserRole.student ? _yearLevelCtrl.text : null,
      section: user.role == UserRole.student ? _sectionCtrl.text : null,
      employeeId: user.role == UserRole.teacher ? _employeeIdCtrl.text : null,
      department: user.role == UserRole.teacher ? _departmentCtrl.text : null,
      coursesTaught: user.role == UserRole.teacher
          ? _coursesTaughtCtrl.text
                .split(',')
                .map((course) => course.trim())
                .where((course) => course.isNotEmpty)
                .toSet()
                .toList()
          : null,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final updatedUser = auth.currentUser!;
    final destination = updatedUser.role == UserRole.teacher
        ? const TeacherHome()
        : const StudentHome();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => destination),
      (route) => false,
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helper,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Enter your $label'.toLowerCase()
          : null,
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to continue.')),
      );
    }

    final isStudent = user.role == UserRole.student;
    final age = _birthday == null
        ? null
        : User(
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            birthday: _birthday,
          ).age;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete your profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hi ${user.name}, add these details once to finish setting up your ${isStudent ? 'student' : 'teacher'} account. You can update your profile later.',
                        style: const TextStyle(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle(
                isStudent ? 'Student information' : 'Teaching information',
                isStudent
                    ? 'Use the information assigned by your school.'
                    : 'Add your school and teaching details.',
              ),
              if (isStudent) ...[
                _textField(
                  controller: _studentIdCtrl,
                  label: 'Student ID',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                FormField<DateTime>(
                  validator: (_) =>
                      _birthday == null ? 'Select your birthday' : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _selectBirthday,
                        borderRadius: BorderRadius.circular(18),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Birthday',
                            helperText: 'Used to calculate your age.',
                            prefixIcon: const Icon(Icons.calendar_month),
                            errorText: field.errorText,
                          ),
                          child: Text(
                            _birthday == null
                                ? 'Select your birthday'
                                : DateFormat.yMMMd().format(_birthday!),
                          ),
                        ),
                      ),
                      if (age != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Age: $age',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _textField(
                  controller: _courseCtrl,
                  label: 'Course / Program',
                  icon: Icons.menu_book_outlined,
                ),
                const SizedBox(height: 16),
                _textField(
                  controller: _yearLevelCtrl,
                  label: 'Year level',
                  icon: Icons.school_outlined,
                  helper: 'For example: 1st year or 2nd year',
                ),
                const SizedBox(height: 16),
                _textField(
                  controller: _sectionCtrl,
                  label: 'Assigned section',
                  icon: Icons.groups_outlined,
                  helper: 'Enter the section assigned by your school. Joining a class QR for a different section will be blocked.',
                ),
              ] else ...[
                _textField(
                  controller: _employeeIdCtrl,
                  label: 'Teacher / Employee ID',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                _textField(
                  controller: _departmentCtrl,
                  label: 'Department',
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 16),
                _textField(
                  controller: _coursesTaughtCtrl,
                  label: 'Courses taught',
                  icon: Icons.menu_book_outlined,
                  helper: 'Separate multiple courses with commas.',
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Birthday and identification details are stored in your private profile.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : () => _saveProfile(user),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save and continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
