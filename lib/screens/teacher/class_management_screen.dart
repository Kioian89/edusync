import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/class_group.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/class_qr_dialog.dart';
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
      builder: (ctx) => AlertDialog(
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
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: sectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Section (e.g. Diamond / Section A)',
                  prefixIcon: Icon(Icons.group_rounded, color: AppTheme.textSecondary),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final auth = context.read<AuthProvider>();
              final newCls = await auth.createClass(
                subject: subjectCtrl.text.trim(),
                section: sectionCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);

              if (newCls != null && mounted) {
                showDialog(
                  context: context,
                  builder: (_) => ClassQrDialog(
                    classGroup: newCls,
                    teacherName: auth.currentUser?.name,
                  ),
                );
              }
            },
            child: const Text('Create Class', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showEditClassDialog(ClassGroup cls) {
    final subjectCtrl = TextEditingController(text: cls.subject);
    final sectionCtrl = TextEditingController(text: cls.section);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Edit Class', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  prefixIcon: Icon(Icons.book_rounded, color: AppTheme.textSecondary),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: sectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  prefixIcon: Icon(Icons.group_rounded, color: AppTheme.textSecondary),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final auth = context.read<AuthProvider>();
              final updated = await auth.updateClass(
                classId: cls.id,
                subject: subjectCtrl.text.trim(),
                section: sectionCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);

              if (mounted && updated != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated "${updated.displayName}" successfully!'),
                    backgroundColor: AppTheme.statusGraded,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClass(ClassGroup cls) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.statusMissing.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppTheme.statusMissing, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Delete Class?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${cls.displayName}"?\n\nThis will remove this class from your active teaching dashboard.',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.statusMissing,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final success = await auth.deleteClass(cls.id);
              if (ctx.mounted) Navigator.pop(ctx);

              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Class "${cls.displayName}" deleted.'),
                    backgroundColor: AppTheme.textMain,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }
            },
            child: const Text('Delete Class', style: TextStyle(fontWeight: FontWeight.w800)),
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
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Class Header Info + Edit/Delete Menu
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.class_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cls.subject,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textMain),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cls.section,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Text(
                              '${cls.studentIds.length} Students',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primary),
                            ),
                          ),
                          // Edit Button
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                            tooltip: 'Edit Class',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => _showEditClassDialog(cls),
                          ),
                          const SizedBox(width: 4),
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.statusMissing),
                            tooltip: 'Delete Class',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDeleteClass(cls),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Action Buttons (QR Code & Scan)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ClassQrDialog(
                                    classGroup: cls,
                                    teacherName: auth.currentUser?.name,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.25)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: AppTheme.primary),
                              label: const Text(
                                'Class QR Code',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ClassQrScannerScreen(classGroup: cls),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                              label: const Text(
                                'Scan Pass',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Enrolled Students list chips (if any)
                      if (students.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        const Text(
                          'Enrolled Students:',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: students.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(s.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
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
