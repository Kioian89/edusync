import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/class_group.dart';
import '../../models/user.dart';
import '../../models/submission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/editable_avatar.dart';
import 'join_class_qr_screen.dart';

class ClassmatesStatusScreen extends StatefulWidget {
  final String? initialClassId;
  final bool showAppBar;

  const ClassmatesStatusScreen({
    super.key,
    this.initialClassId,
    this.showAppBar = true,
  });

  @override
  State<ClassmatesStatusScreen> createState() => _ClassmatesStatusScreenState();
}

class _ClassmatesStatusScreenState extends State<ClassmatesStatusScreen> {
  String? _selectedClassId;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All'; // All, Complete, In Progress, Pending

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final actProvider = context.watch<ActivityProvider>();
    final studentClasses = auth.studentClasses;
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    // Determine active classes for filtering
    final selectedClass = _selectedClassId != null
        ? studentClasses.where((c) => c.id == _selectedClassId).firstOrNull
        : null;

    final targetClasses = selectedClass != null ? [selectedClass] : studentClasses;

    // Gather unique classmates across target classes
    final Map<String, User> uniqueStudents = {};
    final Map<String, List<ClassGroup>> studentClassesMap = {};

    for (final cls in targetClasses) {
      final enrolled = auth.studentsInClass(cls.id);
      for (final s in enrolled) {
        uniqueStudents[s.id] = s;
        studentClassesMap.putIfAbsent(s.id, () => []).add(cls);
      }
    }

    // Convert to list
    final List<User> allClassmates = uniqueStudents.values.toList();

    final filteredList = allClassmates.where((student) {
      // Search filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = student.name.toLowerCase().contains(q);
        final matchEmail = student.email.toLowerCase().contains(q);
        if (!matchName && !matchEmail) return false;
      }

      // Status filter
      if (_selectedStatusFilter != 'All') {
        final stats = _computeStudentStats(student.id, studentClassesMap[student.id] ?? [], actProvider);
        if (_selectedStatusFilter == 'Complete' && !stats.isComplete) return false;
        if (_selectedStatusFilter == 'In Progress' && !stats.isInProgress) return false;
        if (_selectedStatusFilter == 'Pending' && !stats.isPending) return false;
      }

      return true;
    }).toList();

    // Sort: Current user first, then by completed count desc, then alphabetically
    filteredList.sort((a, b) {
      if (a.id == currentUser.id) return -1;
      if (b.id == currentUser.id) return 1;
      final statsA = _computeStudentStats(a.id, studentClassesMap[a.id] ?? [], actProvider);
      final statsB = _computeStudentStats(b.id, studentClassesMap[b.id] ?? [], actProvider);
      final compDiff = statsB.completedCount.compareTo(statsA.completedCount);
      if (compDiff != 0) return compDiff;
      return a.name.compareTo(b.name);
    });

    // Summary stats
    int totalAssigned = 0;
    int totalCompleted = 0;
    for (final s in allClassmates) {
      final stats = _computeStudentStats(s.id, studentClassesMap[s.id] ?? [], actProvider);
      totalAssigned += stats.totalActivities;
      totalCompleted += stats.completedCount;
    }
    final overallRate = totalAssigned > 0 ? (totalCompleted / totalAssigned) : 0.0;

    final content = CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, widget.showAppBar ? 16 : 48, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Subtitle
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.subtlePillShadow,
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Classmates Status',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'View classmate progress & active tasks across subjects',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Hero Statistics Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            icon: Icons.groups_rounded,
                            label: 'Classmates',
                            value: '${allClassmates.length}',
                          ),
                          Container(
                            height: 36,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          _buildStatItem(
                            icon: Icons.menu_book_rounded,
                            label: 'Subjects',
                            value: '${targetClasses.length}',
                          ),
                          Container(
                            height: 36,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          _buildStatItem(
                            icon: Icons.task_alt_rounded,
                            label: 'Class Rate',
                            value: '${(overallRate * 100).toInt()}%',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: overallRate.clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Subject Selector Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSubjectChip(
                        label: 'All Subjects (${studentClasses.length})',
                        isSelected: _selectedClassId == null,
                        onTap: () => setState(() => _selectedClassId = null),
                      ),
                      ...studentClasses.map((cls) {
                        final isSel = _selectedClassId == cls.id;
                        final count = cls.studentIds.length;
                        return _buildSubjectChip(
                          label: '${cls.displayName} ($count)',
                          isSelected: isSel,
                          onTap: () => setState(() => _selectedClassId = cls.id),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search classmate by name…',
                      hintStyle: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('Complete'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('In Progress'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('Pending'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Classmate Cards List
        if (studentClasses.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyClassesState(context),
          )
        else if (filteredList.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.people_outline_rounded,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No Classmates Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Try clearing your search query or switching subject filter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final student = filteredList[index];
                  final isMe = student.id == currentUser.id;
                  final classes = studentClassesMap[student.id] ?? [];
                  final stats = _computeStudentStats(student.id, classes, actProvider);

                  return _ClassmateCard(
                    student: student,
                    isCurrentUser: isMe,
                    classes: classes,
                    stats: stats,
                    onTap: () => _showClassmateDetails(
                      context: context,
                      student: student,
                      classes: classes,
                      actProvider: actProvider,
                      isCurrentUser: isMe,
                    ),
                  );
                },
                childCount: filteredList.length,
              ),
            ),
          ),
      ],
    );

    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Classmates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
              tooltip: 'Join another class',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JoinClassQrScreen()),
              ),
            ),
          ],
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String label) {
    final isSelected = _selectedStatusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyClassesState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 46,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Classes Enrolled Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Join your subjects by scanning a QR code or entering a Join Code from your teacher to see your classmates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JoinClassQrScreen()),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Join a Class Now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StudentStats _computeStudentStats(
    String studentId,
    List<ClassGroup> classes,
    ActivityProvider actProvider,
  ) {
    int total = 0;
    int completed = 0;
    int pending = 0;

    for (final cls in classes) {
      final acts = actProvider.activitiesForClass(cls.id);
      total += acts.length;
      for (final a in acts) {
        final sub = actProvider.submissionForStudentActivity(studentId, a.id);
        if (sub != null &&
            (sub.status == SubmissionStatus.submitted ||
                sub.status == SubmissionStatus.graded)) {
          completed++;
        } else {
          pending++;
        }
      }
    }

    final rate = total > 0 ? (completed / total) : 0.0;
    return _StudentStats(
      totalActivities: total,
      completedCount: completed,
      pendingCount: pending,
      completionRate: rate,
    );
  }

  void _showClassmateDetails({
    required BuildContext context,
    required User student,
    required List<ClassGroup> classes,
    required ActivityProvider actProvider,
    required bool isCurrentUser,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Student Header
              Row(
                children: [
                  EditableAvatar(
                    name: student.name,
                    photoUrl: student.photoUrl,
                    size: 56,
                    editable: false,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                student.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          student.email.isNotEmpty
                              ? student.email
                              : 'Student ID: ${student.id.length > 8 ? student.id.substring(0, 8) : student.id}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Shared Subjects list
              const Text(
                'Shared Class Subjects',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: classes.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_rounded,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          c.displayName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Activities Breakdown
              const Text(
                'Activity Progress in Shared Subjects',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView(
                  children: classes.expand((cls) {
                    final acts = actProvider.activitiesForClass(cls.id);
                    if (acts.isEmpty) {
                      return [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No activities posted yet for ${cls.displayName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        )
                      ];
                    }
                    return [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          cls.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      ...acts.map((act) {
                        final sub = actProvider.submissionForStudentActivity(
                            student.id, act.id);
                        final isDone = sub != null &&
                            (sub.status == SubmissionStatus.submitted ||
                                sub.status == SubmissionStatus.graded);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.access_time_rounded,
                                size: 16,
                                color: isDone
                                    ? AppTheme.statusGraded
                                    : AppTheme.statusPending,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  act.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textMain,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? AppTheme.statusGraded.withValues(alpha: 0.12)
                                      : AppTheme.statusPending.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isDone ? 'Completed' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDone
                                        ? AppTheme.statusGraded
                                        : AppTheme.statusPending,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ];
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentStats {
  final int totalActivities;
  final int completedCount;
  final int pendingCount;
  final double completionRate;

  _StudentStats({
    required this.totalActivities,
    required this.completedCount,
    required this.pendingCount,
    required this.completionRate,
  });

  bool get isComplete => totalActivities > 0 && completedCount == totalActivities;
  bool get isInProgress => completedCount > 0 && completedCount < totalActivities;
  bool get isPending => totalActivities > 0 && completedCount == 0;
}

class _ClassmateCard extends StatelessWidget {
  final User student;
  final bool isCurrentUser;
  final List<ClassGroup> classes;
  final _StudentStats stats;
  final VoidCallback onTap;

  const _ClassmateCard({
    required this.student,
    required this.isCurrentUser,
    required this.classes,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (stats.totalActivities == 0) {
      badgeColor = AppTheme.primary;
      badgeText = 'Enrolled';
      badgeIcon = Icons.verified_rounded;
    } else if (stats.isComplete) {
      badgeColor = AppTheme.statusGraded;
      badgeText = 'All Caught Up';
      badgeIcon = Icons.check_circle_rounded;
    } else if (stats.isInProgress) {
      badgeColor = AppTheme.statusPending;
      badgeText = 'In Progress';
      badgeIcon = Icons.schedule_rounded;
    } else {
      badgeColor = AppTheme.statusMissing;
      badgeText = 'Pending';
      badgeIcon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primary.withValues(alpha: 0.35)
              : AppTheme.borderLight,
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    EditableAvatar(
                      name: student.name,
                      photoUrl: student.photoUrl,
                      size: 44,
                      editable: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textMain,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            classes.map((c) => c.displayName).join(' • '),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Progress Bar
                if (stats.totalActivities > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completed: ${stats.completedCount} of ${stats.totalActivities} tasks',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${(stats.completionRate * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: stats.completionRate.clamp(0.0, 1.0),
                      backgroundColor: AppTheme.surfaceSoft,
                      valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                      minHeight: 5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
