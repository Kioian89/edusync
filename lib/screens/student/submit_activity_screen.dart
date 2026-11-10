import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/activity.dart';
import '../../models/assessment.dart';
import '../../models/submission.dart';
import '../../services/activity_attachment_service.dart';
import '../../widgets/status_badge.dart';
import '../../theme/app_theme.dart';
import 'student_assessment_screen.dart';

class SubmitActivityScreen extends StatefulWidget {
  final Activity activity;
  final Submission? submission;

  const SubmitActivityScreen({
    super.key,
    required this.activity,
    this.submission,
  });

  @override
  State<SubmitActivityScreen> createState() => _SubmitActivityScreenState();
}

class _SubmitActivityScreenState extends State<SubmitActivityScreen> {
  final List<String> _pickedFileNames = [];
  final List<PlatformFile> _pickedFiles = [];
  late final TextEditingController _answerSheetCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final existingAnswer = widget.submission?.studentAnswerSheet;
    final template = widget.activity.answerSheetTemplate;
    _answerSheetCtrl = TextEditingController(
      text: existingAnswer ?? (template ?? ''),
    );
  }

  @override
  void dispose() {
    _answerSheetCtrl.dispose();
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
        'zip',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final f in result.files) {
          if (!_pickedFileNames.contains(f.name)) {
            _pickedFileNames.add(f.name);
            _pickedFiles.add(f);
          }
        }
      });
    }
  }

  Future<void> _openTeacherAttachment(String fileName, int index) async {
    final url = widget.activity.attachmentUrlAt(index);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$fileName is not available to download. Ask the teacher to reattach it.',
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

  Future<void> _submit() async {
    final hasTemplate = widget.activity.hasAnswerSheetTemplate;
    final answerText = _answerSheetCtrl.text.trim();

    if (_pickedFileNames.isEmpty && (!hasTemplate || answerText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please attach files or fill in the answer sheet before submitting.',
          ),
          backgroundColor: AppTheme.statusPending,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Confirm Submission',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          hasTemplate && answerText.isNotEmpty
              ? 'You are turning in your in-app answer sheet${_pickedFileNames.isNotEmpty ? " and ${_pickedFileNames.length} file(s)" : ""}.'
              : (_pickedFileNames.length == 1
                    ? 'You are turning in "${_pickedFileNames.first}".'
                    : 'You are turning in ${_pickedFileNames.length} files (${_pickedFileNames.join(", ")}).'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Turn In',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final actProvider = context.read<ActivityProvider>();
    final studentId = auth.currentUser!.id;
    final studentName = auth.currentUser!.name;

    setState(() => _loading = true);

    try {
      await actProvider.submitActivity(
        activityId: widget.activity.id,
        studentId: studentId,
        studentName: studentName,
        fileNames: _pickedFileNames,
        attachmentFiles: _pickedFiles,
        fileName: _pickedFileNames.isNotEmpty ? _pickedFileNames.first : null,
        studentAnswerSheet: hasTemplate && answerText.isNotEmpty
            ? answerText
            : null,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit activity: $error'),
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
        content: Text('Activity turned in successfully! 🎉'),
        backgroundColor: AppTheme.statusGraded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final act = widget.activity;
    final sub = widget.submission;
    final isSubmitted = sub?.status == SubmissionStatus.submitted;
    final isGraded = sub?.status == SubmissionStatus.graded;
    final isMissing = sub?.status == SubmissionStatus.missing;
    final isPending = sub == null || sub.status == SubmissionStatus.pending;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          act.typeLabel,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Activity Detail Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: act.typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          act.typeLabel.toUpperCase(),
                          style: TextStyle(
                            color: act.typeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (sub != null)
                        StatusBadge(status: sub.status, large: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    act.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textMain,
                      height: 1.25,
                    ),
                  ),
                  if (act.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      act.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 16,
                              color: act.isPastDeadline
                                  ? AppTheme.statusMissing
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Due ${DateFormat('MMM d, h:mm a').format(act.deadline)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: act.isPastDeadline
                                    ? AppTheme.statusMissing
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${act.totalPoints.toInt()} pts',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Attached documents
                  if (act.attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Teacher Materials & Handouts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: List.generate(act.attachments.length, (index) {
                        final file = act.attachments[index];
                        return Semantics(
                          button: true,
                          label: 'Download $file',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openTeacherAttachment(file, index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.borderLight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.download_rounded,
                                      size: 16,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      file,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Interactive AI Assessment Card (if assessmentData exists)
            if (act.isAiAssessment) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppTheme.heroShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Interactive AI Assessment',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This assessment is auto-checked in real-time. Answer questions, submit, and see your score instantly.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          try {
                            final assessment = Assessment.fromJson(
                              act.assessmentData!,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StudentAssessmentScreen(
                                  activity: act,
                                  assessment: assessment,
                                  existingSubmission: sub,
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to load assessment: $e'),
                              ),
                            );
                          }
                        },
                        child: Text(
                          sub != null
                              ? 'View My Assessment Results'
                              : 'Take Interactive Assessment Now',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Grade Summary (if graded)
            if (isGraded && sub != null) ...[
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.statusGraded.withValues(alpha: 0.15),
                      AppTheme.statusGraded.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppTheme.statusGraded.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: AppTheme.statusGraded,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Evaluation Result',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppTheme.statusGraded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${sub.grade!.toInt()}',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.statusGraded,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 4),
                          child: Text(
                            '/ ${act.totalPoints.toInt()} pts',
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.statusGraded,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${(sub.grade! / act.totalPoints * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sub.feedback != null && sub.feedback!.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text(
                        'Teacher Feedback:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.feedback!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Submission Info Card (if submitted)
            if ((isSubmitted || isGraded) && sub != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Your Turn-in Record',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (sub.submittedAt != null)
                      Text(
                        'Turned in on ${DateFormat('MMMM d, yyyy • h:mm a').format(sub.submittedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (sub.fileNames.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: sub.fileNames
                            .map(
                              (f) => Chip(
                                label: Text(
                                  f,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: AppTheme.surfaceSoft,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (sub.studentAnswerSheet != null &&
                        sub.studentAnswerSheet!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(
                          sub.studentAnswerSheet!,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Student submission action section (if pending)
            if (isPending && !isMissing) ...[
              if (act.hasAnswerSheetTemplate) ...[
                Container(
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
                      const Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Digital In-App Answer Sheet',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Type your answers directly into the structured template below:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _answerSheetCtrl,
                        maxLines: 8,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your answers here...',
                          fillColor: AppTheme.surfaceSoft,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppTheme.borderLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Attachment upload capsule
              Container(
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
                    const Text(
                      'Attach Files (PDF, Images, Docs)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickFiles,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 32,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _pickedFileNames.isEmpty
                                    ? 'Tap to select submission files'
                                    : '${_pickedFileNames.length} file(s) attached (tap to add more)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_pickedFileNames.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _pickedFileNames.map((name) {
                          return Chip(
                            avatar: const Icon(
                              Icons.insert_drive_file_rounded,
                              size: 14,
                            ),
                            label: Text(
                              name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onDeleted: () {
                              setState(() {
                                _pickedFileNames.remove(name);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Turn in button
              InkWell(
                onTap: _loading ? null : _submit,
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
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Turn In Activity',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
