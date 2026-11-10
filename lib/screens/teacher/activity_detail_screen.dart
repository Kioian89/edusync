import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/activity.dart';
import '../../models/submission.dart';
import '../../services/activity_attachment_service.dart';
import '../../widgets/status_badge.dart';
import '../../theme/app_theme.dart';
import 'grade_entry_screen.dart';

class ActivityDetailScreen extends StatelessWidget {
  final Activity activity;
  const ActivityDetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actProvider = context.watch<ActivityProvider>();
    final authProvider = context.read<AuthProvider>();
    final submissions = actProvider.submissionsForActivity(activity.id);
    final students = authProvider.studentsInClass(activity.classId);

    // Merge students with their submissions
    final studentSubs = students.map((s) {
      Submission? sub;
      try {
        sub = submissions.firstWhere((sub) => sub.studentId == s.id);
      } catch (_) {}
      return _StudentSubmission(student: s, submission: sub);
    }).toList();

    final submitted = studentSubs
        .where(
          (ss) =>
              ss.submission?.status == SubmissionStatus.submitted ||
              ss.submission?.status == SubmissionStatus.graded,
        )
        .length;
    final graded = studentSubs
        .where((ss) => ss.submission?.status == SubmissionStatus.graded)
        .length;
    final missing = studentSubs
        .where((ss) => ss.submission?.status == SubmissionStatus.missing)
        .length;
    final pending = studentSubs.length - submitted - missing;

    return Scaffold(
      appBar: AppBar(
        title: Text(activity.typeLabel),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Delete Activity',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (v) async {
              if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Activity?'),
                    content: const Text(
                      'This will delete the activity and all submissions. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<ActivityProvider>().deleteActivity(
                    activity.id,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: activity.typeColor.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: activity.typeColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          activity.typeLabel,
                          style: TextStyle(
                            color: activity.typeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        activity.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMain,
                        ),
                      ),
                      if (activity.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          activity.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: activity.isPastDeadline
                                ? AppTheme.statusMissing
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Due ${DateFormat('MMM d, yyyy • h:mm a').format(activity.deadline)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: activity.isPastDeadline
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: activity.isPastDeadline
                                  ? AppTheme.statusMissing
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${activity.totalPoints.toInt()} pts',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      if (activity.teacherAnswerKey != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrbit.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.accentOrbit.withValues(
                                alpha: 0.3,
                              ),
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
                                  SizedBox(width: 8),
                                  Text(
                                    'Teacher Answer Key & Scoring Guide (AI Generated):',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accentOrbit,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                activity.teacherAnswerKey!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMain,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (activity.attachments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Attached Documents / Exam Materials:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: List.generate(activity.attachments.length, (
                            index,
                          ) {
                            final file = activity.attachments[index];
                            return ActionChip(
                              avatar: const Icon(Icons.download, size: 16),
                              label: Text(
                                file,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final url = activity.attachmentUrlAt(index);
                                if (url == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$file is not available to download.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  final opened =
                                      await ActivityAttachmentService.openDownloadUrl(
                                        url,
                                      );
                                  if (!opened) {
                                    throw StateError(
                                      'No app could open this file link.',
                                    );
                                  }
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not open $file: $error',
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatChip('Submitted', submitted, Colors.blue),
                      const SizedBox(width: 8),
                      _StatChip('Graded', graded, Colors.green),
                      const SizedBox(width: 8),
                      _StatChip('Pending', pending, Colors.orange),
                      const SizedBox(width: 8),
                      _StatChip('Missing', missing, Colors.red),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Students (${studentSubs.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, idx) {
              final ss = studentSubs[idx];
              final sub = ss.submission;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      ss.student.name.isNotEmpty
                          ? ss.student.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    ss.student.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: sub?.submittedAt != null
                      ? Text(
                          'Submitted ${DateFormat('MMM d, h:mm a').format(sub!.submittedAt!)}',
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sub != null) StatusBadge(status: sub.status),
                      const SizedBox(width: 4),
                      if (sub?.status == SubmissionStatus.submitted)
                        IconButton(
                          icon: const Icon(Icons.grade, color: Colors.indigo),
                          tooltip: 'Grade',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GradeEntryScreen(
                                submission: sub!,
                                activity: activity,
                                studentName: ss.student.name,
                              ),
                            ),
                          ),
                        )
                      else if (sub?.status == SubmissionStatus.graded)
                        Text(
                          '${sub!.grade!.toInt()}/${activity.totalPoints.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  onTap:
                      sub?.status == SubmissionStatus.submitted ||
                          sub?.status == SubmissionStatus.graded
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GradeEntryScreen(
                              submission: sub!,
                              activity: activity,
                              studentName: ss.student.name,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }, childCount: studentSubs.length),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _StudentSubmission {
  final dynamic student;
  final Submission? submission;
  _StudentSubmission({required this.student, this.submission});
}
