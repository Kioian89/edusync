import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/activity.dart';
import '../../models/class_group.dart';
import '../../services/ai_activity_helper.dart';
import '../../providers/gemini_assistant_provider.dart';
import '../../theme/app_theme.dart';

class QuickActivitySheet extends StatefulWidget {
  final ClassGroup classGroup;

  const QuickActivitySheet({super.key, required this.classGroup});

  @override
  State<QuickActivitySheet> createState() => _QuickActivitySheetState();
}

class _QuickActivitySheetState extends State<QuickActivitySheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '50');

  ActivityType _type = ActivityType.seatwork;
  DateTime _deadline = DateTime.now().add(const Duration(hours: 3));
  final List<String> _attachmentNames = [];
  bool _useAiAssistant = true;
  String? _answerSheetTemplate;
  String? _teacherAnswerKey;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  String _cleanFileName(String pathOrName) {
    final name = pathOrName.split(Platform.pathSeparator).last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1) {
      final base = name.substring(0, dotIndex);
      return base.replaceAll('_', ' ').replaceAll('-', ' ');
    }
    return name;
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
        'jpg', 'jpeg', 'png', 'txt'
      ],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final f in result.files) {
          if (!_attachmentNames.contains(f.name)) {
            _attachmentNames.add(f.name);
          }
        }
        // Auto-fill title from first file if title is currently empty
        if (_titleCtrl.text.trim().isEmpty && _attachmentNames.isNotEmpty) {
          final first = _attachmentNames.first.toLowerCase();
          if (first.contains('module') || first.contains('lesson') || first.contains('chapter')) {
            _type = ActivityType.module;
          }
          _titleCtrl.text = _cleanFileName(_attachmentNames.first);
        }

        if (_useAiAssistant && _attachmentNames.isNotEmpty) {
          _applyAiActivityGeneration();
        }
      });
    }
  }

  Future<void> _applyAiActivityGeneration() async {
    final geminiKey = context.read<GeminiAssistantProvider>().apiKey;
    final generated = await AiActivityHelper.generateActivityAsync(
      topic: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Module Activity',
      fileNames: _attachmentNames,
      apiKey: geminiKey,
    );
    if (!mounted) return;
    setState(() {
      _descCtrl.text = generated['description'] ?? _descCtrl.text;
      _answerSheetTemplate = generated['answerSheetTemplate'];
      _teacherAnswerKey = generated['teacherKey'];
      _pointsCtrl.text = '50';
    });
  }

  Future<void> _publishQuickActivity() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide an activity title or upload a file.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final points = double.tryParse(_pointsCtrl.text) ?? 50;

    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final activityProvider = context.read<ActivityProvider>();
    final students = auth.studentsInClass(widget.classGroup.id);

    await activityProvider.createActivity(
      title: title,
      description: _descCtrl.text.trim().isNotEmpty
          ? _descCtrl.text.trim()
          : 'Please complete and submit the activity based on the attached document(s).',
      classId: widget.classGroup.id,
      teacherId: auth.currentUser!.id,
      type: _type,
      deadline: _deadline,
      totalPoints: points,
      attachments: _attachmentNames,
      attachmentName: _attachmentNames.isNotEmpty ? _attachmentNames.first : null,
      answerSheetTemplate: _useAiAssistant ? _answerSheetTemplate : null,
      teacherAnswerKey: _useAiAssistant ? _teacherAnswerKey : null,
      studentIds: students.map((s) => s.id).toList(),
    );

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ Quick Activity "$title" posted instantly!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Module or Activity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Upload lesson module/reading + assign activity for students',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Upload Drop Area
            InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload Lesson Modules, Worksheets, or Exam Files',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, Word (.docx), PPT, Images, Excel (Multiple files supported)',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (_attachmentNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Selected Files (${_attachmentNames.length})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _attachmentNames.map((name) {
                  return Chip(
                    avatar: const Icon(Icons.insert_drive_file, size: 16),
                    label: Text(
                      name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () {
                      setState(() {
                        _attachmentNames.remove(name);
                      });
                    },
                    deleteIconColor: Colors.red,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            // Activity Type
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ActivityType>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: ActivityType.values.map((t) {
                      final sample = Activity(
                        id: '',
                        title: '',
                        description: '',
                        classId: '',
                        teacherId: '',
                        type: t,
                        deadline: DateTime.now(),
                        totalPoints: 100,
                        createdAt: DateTime.now(),
                      );
                      return DropdownMenuItem(
                        value: t,
                        child: Text(sample.typeLabel),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _pointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Points',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // AI Activity Generator Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _useAiAssistant
                    ? AppTheme.primarySubtle
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _useAiAssistant
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: _useAiAssistant ? Colors.indigo : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Activity & Answer Sheet Assistant',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _useAiAssistant
                                    ? Colors.indigo[800]
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Auto-generates activity tasks, rubric, and student answer sheet',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useAiAssistant,
                        activeColor: Colors.indigo,
                        onChanged: (val) {
                          setState(() {
                            _useAiAssistant = val;
                            if (val && _attachmentNames.isNotEmpty) {
                              _applyAiActivityGeneration();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_useAiAssistant && _answerSheetTemplate != null) ...[
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                        const SizedBox(width: 6),
                        const Text(
                          'Ready-to-fill student answer sheet & rubric attached',
                          style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _applyAiActivityGeneration()),
                          child: const Text('Regenerate', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Activity Title',
                hintText: 'e.g. Pop Quiz 1 or Seatwork 3',
                prefixIcon: Icon(Icons.title),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Quick Instructions (Optional)',
                hintText: 'Instructions for students...',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            // Due presets
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.timer_outlined, size: 14),
                  label: const Text('Due in 1 hr'),
                  onPressed: () {
                    setState(() {
                      _deadline = DateTime.now().add(const Duration(hours: 1));
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.wb_sunny_outlined, size: 14),
                  label: const Text('End of Class (3 hrs)'),
                  onPressed: () {
                    setState(() {
                      _deadline = DateTime.now().add(const Duration(hours: 3));
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.bedtime_outlined, size: 14),
                  label: const Text('Tonight 11:59 PM'),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() {
                      _deadline = DateTime(now.year, now.month, now.day, 23, 59);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Deadline: ${DateFormat('MMM d, h:mm a').format(_deadline)}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _publishQuickActivity,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rocket_launch),
              label: const Text('Launch Activity to Class'),
            ),
          ],
        ),
      ),
    );
  }
}

