import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'class_qr_scanner_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  void _showCreateClassDialog() {
    final subjectCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Create New Class', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject Name (e.g. Science 10)',
                  prefixIcon: Icon(Icons.book_rounded, color: AppTheme.textSecondary),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: sectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Section (e.g. Diamond / Section A)',
                  prefixIcon: Icon(Icons.group_rounded, color: AppTheme.textSecondary),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final navigator = Navigator.of(context);
              await context.read<AuthProvider>().createClass(
                    subject: subjectCtrl.text.trim(),
                    section: sectionCtrl.text.trim(),
                  );
              navigator.pop();
            },
            child: const Text('Create Class', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classes = auth.teacherClasses;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Manage Classes', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 26, color: AppTheme.primary),
            onPressed: _showCreateClassDialog,
            tooltip: 'Create Class',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: classes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Icon(Icons.class_outlined, size: 36, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  const Text('No classes added yet.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _showCreateClassDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create New Class'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: classes.length,
              itemBuilder: (context, idx) {
                final cls = classes[idx];
                final students = auth.studentsInClass(cls.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.class_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cls.subject,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textMain),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cls.section,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Text(
                              '${students.length} Students',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Scan QR code button to add students
                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClassQrScannerScreen(classGroup: cls),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppTheme.subtlePillShadow,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Scan',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (students.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 6),
                        const Text('Enrolled Students:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: students.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
                              ],
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
