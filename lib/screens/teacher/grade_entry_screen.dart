import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/activity_provider.dart';
import '../../models/activity.dart';
import '../../models/submission.dart';
import '../../services/activity_attachment_service.dart';
import '../../widgets/status_badge.dart';
import '../../theme/app_theme.dart';

import 'package:intl/intl.dart';

class GradeEntryScreen extends StatefulWidget {
  final Submission submission;
  final Activity activity;
  final String studentName;

  const GradeEntryScreen({
    super.key,
    required this.submission,
    required this.activity,
    required this.studentName,
  });

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  late final TextEditingController _gradeCtrl;
  late final TextEditingController _feedbackCtrl;
  bool _loading = false;

  Future<void> _openStudentFile(String fileName, int index) async {
    final url = widget.submission.fileUrls.length > index
        ? widget.submission.fileUrls[index]
        : null;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$fileName was submitted before file downloads were supported.',
          ),
        ),
      );
      return;
    }

    try {
      final opened = await ActivityAttachmentService.openDownloadUrl(url);
      if (!opened) throw StateError('No app could open this file link.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $fileName: $error')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _gradeCtrl = TextEditingController(
      text: widget.submission.grade?.toStringAsFixed(0) ?? '',
    );
    _feedbackCtrl = TextEditingController(
      text: widget.submission.feedback ?? '',
    );
  }

  @override
  void dispose() {
    _gradeCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGrade() async {
    final grade = double.tryParse(_gradeCtrl.text);
    if (grade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid grade'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (grade < 0 || grade > widget.activity.totalPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Grade must be between 0 and ${widget.activity.totalPoints.toInt()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    await context.read<ActivityProvider>().gradeSubmission(
      submissionId: widget.submission.id,
      grade: grade,
      feedback: _feedbackCtrl.text.trim().isNotEmpty
          ? _feedbackCtrl.text.trim()
          : null,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Grade saved for ${widget.studentName}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _markMissing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Missing?'),
        content: const Text(
          'This will mark the submission as missing and assign 0 points.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Missing'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<ActivityProvider>().markMissing(widget.submission.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = widget.submission;
    final act = widget.activity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Submission'),
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
            FilledButton(onPressed: _saveGrade, child: const Text('Save')),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      radius: 24,
                      child: Text(
                        widget.studentName.isNotEmpty
                            ? widget.studentName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.studentName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          act.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    StatusBadge(status: sub.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Submission info
            if (sub.submittedAt != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.upload_file, color: Colors.blue),
                title: const Text('Submitted'),
                subtitle: Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(sub.submittedAt!),
                ),
              ),
            if (sub.fileNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Student Files',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (var index = 0; index < sub.fileNames.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(sub.fileNames[index]),
                  trailing: const Icon(
                    Icons.download_rounded,
                    color: AppTheme.primary,
                  ),
                  onTap: () => _openStudentFile(sub.fileNames[index], index),
                ),
            ],
            if (sub.studentAnswerSheet != null &&
                sub.studentAnswerSheet!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.description_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Student Filled In-App Answer Sheet:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Text(
                        sub.studentAnswerSheet!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (act.teacherAnswerKey != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrbit.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accentOrbit.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.key_rounded,
                          size: 16,
                          color: AppTheme.accentOrbit,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'AI Generated Answer Key & Rubric Reference:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.brown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      act.teacherAnswerKey!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 32),
            // Grade input
            Text(
              'Grade',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gradeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Score',
                      prefixIcon: Icon(Icons.grade),
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '/ ${act.totalPoints.toInt()}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Feedback (Optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _feedbackCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Write comments or feedback for the student...',
                prefixIcon: Icon(Icons.comment_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _loading ? null : _saveGrade,
              icon: const Icon(Icons.check),
              label: const Text('Save Grade'),
            ),
            const SizedBox(height: 12),
            if (sub.status != SubmissionStatus.missing)
              OutlinedButton.icon(
                onPressed: _markMissing,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Mark as Missing'),
              ),
          ],
        ),
      ),
    );
  }
}
