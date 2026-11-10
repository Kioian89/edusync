import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/activity.dart';
import '../../models/class_group.dart';
import '../../services/ai_activity_helper.dart';
import '../../providers/gemini_assistant_provider.dart';
import '../../theme/app_theme.dart';
import 'ai_assessment_hub_screen.dart';

class ActivityCreateScreen extends StatefulWidget {
  final ClassGroup classGroup;
  const ActivityCreateScreen({super.key, required this.classGroup});

  @override
  State<ActivityCreateScreen> createState() => _ActivityCreateScreenState();
}

class _ActivityCreateScreenState extends State<ActivityCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '100');

  ActivityType _type = ActivityType.assignment;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  final List<String> _attachmentNames = [];
  final List<PlatformFile> _attachmentFiles = [];
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

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      withData: true,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'jpg',
        'jpeg',
        'png',
        'txt',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final f in result.files) {
          if (!_attachmentNames.contains(f.name)) {
            _attachmentNames.add(f.name);
            _attachmentFiles.add(f);
          }
        }
        // Auto populate title if empty
        if (_titleCtrl.text.trim().isEmpty && _attachmentNames.isNotEmpty) {
          final first = _attachmentNames.first;
          final dot = first.lastIndexOf('.');
          final base = dot != -1 ? first.substring(0, dot) : first;
          _titleCtrl.text = base.replaceAll('_', ' ').replaceAll('-', ' ');
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
    );
    if (time == null) return;
    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _generateWithAi() async {
    final topic = _titleCtrl.text.isNotEmpty
        ? _titleCtrl.text
        : (_attachmentNames.isNotEmpty
              ? _attachmentNames.first
              : 'Module Lesson');

    setState(() => _loading = true);

    final geminiKey = context.read<GeminiAssistantProvider>().apiKey;

    final content = await AiActivityHelper.generateActivityAsync(
      topic: topic,
      fileNames: _attachmentNames,
      apiKey: geminiKey,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (_titleCtrl.text.isEmpty) {
        _titleCtrl.text = content['title'] ?? topic;
      }
      _descCtrl.text = content['description'] ?? '';
      _answerSheetTemplate = content['answerSheetTemplate'];
      _teacherAnswerKey = content['teacherKey'];
      _pointsCtrl.text = '50';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          geminiKey != null && geminiKey.isNotEmpty
              ? '✨ Lodix AI generated custom activity tasks & rubric!'
              : '✨ AI generated activity tasks & answer sheet template!',
        ),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final activity = context.read<ActivityProvider>();
    final students = auth.studentsInClass(widget.classGroup.id);

    try {
      await activity.createActivity(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        classId: widget.classGroup.id,
        teacherId: auth.currentUser!.id,
        type: _type,
        deadline: _deadline,
        totalPoints: double.tryParse(_pointsCtrl.text) ?? 100,
        attachments: _attachmentNames,
        attachmentFiles: _attachmentFiles,
        attachmentName: _attachmentNames.isNotEmpty
            ? _attachmentNames.first
            : null,
        answerSheetTemplate: _answerSheetTemplate,
        teacherAnswerKey: _teacherAnswerKey,
        studentIds: students.map((s) => s.id).toList(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not post activity: $error'),
          backgroundColor: AppTheme.statusMissing,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Activity'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(onPressed: _submit, child: const Text('Post')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Class chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.class_rounded,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.classGroup.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Type selector
              Text('Activity Type', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ActivityType.values.map((t) {
                  final act = _mockActivity(t);
                  final isSelected = _type == t;
                  return FilterChip(
                    selected: isSelected,
                    label: Text(act.typeLabel),
                    avatar: Icon(Icons.circle, size: 12, color: act.typeColor),
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: act.typeColor.withValues(alpha: 0.2),
                    checkmarkColor: act.typeColor,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // AI Google Forms Quiz Studio Button
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AiAssessmentHubScreen(
                        preselectedClass: widget.classGroup,
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.psychology_rounded, size: 20),
                label: const Text(
                  'Open AI Assessment Studio (Google Forms Quiz)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              // AI Generator Trigger Button
              OutlinedButton.icon(
                onPressed: _generateWithAi,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text(
                  'Auto-Generate Activity & Answer Sheet with AI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_answerSheetTemplate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppTheme.accentEmerald,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Activity questions, student answer sheet & rubric attached!',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentEmerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Activity Title',
                  prefixIcon: Icon(Icons.edit_document),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instructions / Description',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pointsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Points',
                  prefixIcon: Icon(Icons.military_tech_rounded),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter points';
                  if (double.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Deadline picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_rounded),
                title: const Text('Deadline'),
                subtitle: Text(
                  _deadline.toLocal().toString().substring(0, 16),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
              ),
              const SizedBox(height: 16),
              // Attachments
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.attachment_rounded),
                label: Text(
                  _attachmentNames.isEmpty
                      ? 'Attach Documents / Exam Files'
                      : 'Add More Files (${_attachmentNames.length} selected)',
                ),
              ),
              if (_attachmentNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _attachmentNames.map((name) {
                    return Chip(
                      avatar: const Icon(Icons.description_outlined, size: 16),
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() {
                          _attachmentNames.remove(name);
                          _attachmentFiles.removeWhere(
                            (file) => file.name == name,
                          );
                        });
                      },
                      deleteIconColor: Colors.red,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Post Activity'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Activity _mockActivity(ActivityType t) => Activity(
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
}
