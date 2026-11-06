import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/activity.dart';
import '../../models/submission.dart';
import '../../widgets/status_badge.dart';
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
        .where((ss) =>
            ss.submission?.status == SubmissionStatus.submitted ||
            ss.submission?.status == SubmissionStatus.graded)
        .length;
    final graded =
        studentSubs.where((ss) => ss.submission?.status == SubmissionStatus.graded).length;
    final missing =
        studentSubs.where((ss) => ss.submission?.status == SubmissionStatus.missing).length;
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
                    Text('Delete Activity', style: TextStyle(color: Colors.red)),
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
                        'This will delete the activity and all submissions. This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<ActivityProvider>().deleteActivity(activity.id);
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
                  padding: const EdgeInsets.all(20),
                  color: activity.typeColor.withOpacity(0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: activity.typeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(activity.typeLabel,
                            style: TextStyle(
                                color: activity.typeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                      const SizedBox(height: 10),
                      Text(activity.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold)),
                      if (activity.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(activity.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16,
                              color: activity.isPastDeadline
                                  ? Colors.red
                                  : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Due ${DateFormat('MMM d, yyyy • h:mm a').format(activity.deadline)}',
                            style: TextStyle(
                                fontSize: 13,
                                color: activity.isPastDeadline
                                    ? Colors.red
                                    : theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.star_border, size: 16,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text('${activity.totalPoints.toInt()} pts',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (activity.teacherAnswerKey != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.key, size: 16, color: Colors.amber),
                                  SizedBox(width: 6),
                                  Text(
                                    'Teacher Answer Key & Scoring Guide (AI Generated):',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activity.teacherAnswerKey!,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (activity.attachments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Attached Documents / Exam Materials:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: activity.attachments.map((file) {
                            return ActionChip(
                              avatar: const Icon(Icons.download, size: 16),
                              label: Text(file, style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Downloading $file...')),
                                );
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
                  child: Text('Students (${studentSubs.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final ss = studentSubs[idx];
                final sub = ss.submission;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                      child: Text(
                        ss.student.name.isNotEmpty
                            ? ss.student.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color:
                                theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(ss.student.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: sub?.submittedAt != null
                        ? Text(
                            'Submitted ${DateFormat('MMM d, h:mm a').format(sub!.submittedAt!)}',
                            style:
                                const TextStyle(fontSize: 12))
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
                                fontSize: 14),
                          ),
                      ],
                    ),
                    onTap: sub?.status == SubmissionStatus.submitted ||
                            sub?.status == SubmissionStatus.graded
                        ? () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => GradeEntryScreen(
                                submission: sub!,
                                activity: activity,
                                studentName: ss.student.name,
                              ),
                            ))
                        : null,
                  ),
                );
              },
              childCount: studentSubs.length,
            ),
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: color)),
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

