import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_provider.dart';
import '../../models/class_group.dart';
import '../../models/activity.dart';
import '../../models/submission.dart';
import '../../models/user.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/sync_badge.dart';
import '../../widgets/class_qr_dialog.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'activity_create_screen.dart';
import 'activity_detail_screen.dart';
import 'announcements_screen.dart';
import 'class_management_screen.dart';
import 'gemini_assistant_screen.dart';
import 'quick_activity_sheet.dart';
import 'ai_assessment_hub_screen.dart';
import '../common/community_standards_screen.dart';
import '../common/privacy_policy_screen.dart';
import '../onboarding/app_guide_onboarding_screen.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  int _selectedIndex = 0;
  ClassGroup? _selectedClass;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      auth.startListeningToClasses();
      final activity = context.read<ActivityProvider>();
      if (auth.teacherClasses.isNotEmpty) {
        setState(() => _selectedClass = auth.teacherClasses.first);
      }
      if (auth.currentUser != null) {
        activity.syncWithFirestore(
          userId: auth.currentUser!.id,
          isTeacher: true,
          classIds: auth.teacherClasses.map((c) => c.id).toList(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final activity = context.watch<ActivityProvider>();

    final activeClass = (_selectedClass != null &&
            auth.teacherClasses.any((c) => c.id == _selectedClass!.id))
        ? auth.teacherClasses.firstWhere((c) => c.id == _selectedClass!.id)
        : (auth.teacherClasses.isNotEmpty ? auth.teacherClasses.first : null);

    final pages = [
      _TeacherActivitiesView(
        selectedClass: activeClass,
        classes: auth.teacherClasses,
        onClassSelected: (c) => setState(() => _selectedClass = c),
        activityProvider: activity,
        authProvider: auth,
      ),
      _TeacherGradebookView(
        selectedClass: activeClass,
        classes: auth.teacherClasses,
        onClassSelected: (c) => setState(() => _selectedClass = c),
        authProvider: auth,
        activityProvider: activity,
      ),
      const GeminiAssistantScreen(),
      _TeacherProfileView(authProvider: auth),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: pages[_selectedIndex],
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          CustomNavItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view_rounded,
            label: 'Home',
          ),
          CustomNavItem(
            icon: Icons.pie_chart_outline_rounded,
            selectedIcon: Icons.pie_chart_rounded,
            label: 'Grades',
          ),
          CustomNavItem(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome_rounded,
            label: 'Gemini',
          ),
          CustomNavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _TeacherActivitiesView extends StatefulWidget {
  final ClassGroup? selectedClass;
  final List<ClassGroup> classes;
  final ValueChanged<ClassGroup> onClassSelected;
  final ActivityProvider activityProvider;
  final AuthProvider authProvider;

  const _TeacherActivitiesView({
    required this.selectedClass,
    required this.classes,
    required this.onClassSelected,
    required this.activityProvider,
    required this.authProvider,
  });

  @override
  State<_TeacherActivitiesView> createState() => _TeacherActivitiesViewState();
}

class _TeacherActivitiesViewState extends State<_TeacherActivitiesView> {
  String _searchQuery = '';
  ActivityType? _selectedTypeFilter;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showCreateClassDialog(BuildContext context) {
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
              final auth = context.read<AuthProvider>();
              final newCls = await auth.createClass(
                subject: subjectCtrl.text.trim(),
                section: sectionCtrl.text.trim(),
              );
              navigator.pop();

              if (newCls != null) {
                widget.onClassSelected(newCls);
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => ClassQrDialog(
                      classGroup: newCls,
                      teacherName: auth.currentUser?.name,
                    ),
                  );
                }
              }
            },
            child: const Text('Create Class', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedClass = widget.selectedClass;
    final classes = widget.classes;
    final onClassSelected = widget.onClassSelected;
    final activityProvider = widget.activityProvider;
    final authProvider = widget.authProvider;

    final user = authProvider.currentUser;
    final allActivities = selectedClass != null
        ? activityProvider.activitiesForClass(selectedClass.id)
        : <Activity>[];
    final activities = allActivities.where((a) {
      final matchesSearch = _searchQuery.isEmpty ||
          a.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedTypeFilter == null || a.type == _selectedTypeFilter;
      return matchesSearch && matchesType;
    }).toList();

    final students = selectedClass != null
        ? authProvider.studentsInClass(selectedClass.id)
        : [];

    final pendingGradingCount = allActivities.fold<int>(0, (sum, a) {
      final subs = activityProvider.submissionsForActivity(a.id);
      return sum + subs.where((s) => s.status == SubmissionStatus.submitted).length;
    });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header avatar & greeting like reference UI
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: AppTheme.subtlePillShadow,
                            ),
                            child: Center(
                              child: Text(
                                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'T',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${_getGreeting()}, ${user?.name.split(" ").first ?? "Teacher"}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const SyncBadge(compact: true),
                                  ],
                                ),
                                const Text(
                                  'Teacher Dashboard',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textMain,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action pill buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selectedClass != null) ...[
                          _CircleIconButton(
                            icon: Icons.qr_code_2_rounded,
                            tooltip: 'Class QR Code',
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => ClassQrDialog(
                                classGroup: selectedClass,
                                teacherName: user?.name,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        _CircleIconButton(
                          icon: Icons.campaign_rounded,
                          tooltip: 'Announcements',
                          onTap: selectedClass == null
                              ? () {}
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AnnouncementsScreen(
                                          classGroup: selectedClass),
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 6),
                        _CircleIconButton(
                          icon: Icons.meeting_room_outlined,
                          tooltip: 'Manage Classes',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ClassManagementScreen()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Horizontal Class Selector Chips (matching reference UI pill filter)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...classes.map((c) {
                        final isSel = selectedClass?.id == c.id;
                        return GestureDetector(
                          onTap: () => onClassSelected(c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppTheme.cardShadow,
                              border: Border.all(
                                color: isSel ? AppTheme.primary : AppTheme.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.class_rounded,
                                  size: 14,
                                  color: isSel ? Colors.white : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  c.displayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    color: isSel ? Colors.white : AppTheme.textMain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      // "+ New Class" chip
                      GestureDetector(
                        onTap: () => _showCreateClassDialog(context),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text(
                                'New Class',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                      hintText: 'Search activities…',
                      hintStyle: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.textSecondary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  size: 18, color: AppTheme.textSecondary),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Activity Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeFilterChip(null, 'All Types', Icons.dashboard_outlined),
                      _buildTypeFilterChip(ActivityType.module, 'Modules', Icons.menu_book_rounded),
                      _buildTypeFilterChip(ActivityType.assignment, 'Assignments', Icons.assignment_rounded),
                      _buildTypeFilterChip(ActivityType.quiz, 'Quizzes', Icons.help_outline_rounded),
                      _buildTypeFilterChip(ActivityType.project, 'Projects', Icons.science_rounded),
                      _buildTypeFilterChip(ActivityType.exam, 'Exams', Icons.description_rounded),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Royal Purple Hero Banner Capsule
                if (selectedClass != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroCardGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: AppTheme.heroShadow,
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
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${selectedClass.subject} • ${selectedClass.section}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${students.length} Enrolled Students • ${allActivities.length} Total Activities',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => ClassQrDialog(
                                  classGroup: selectedClass,
                                  teacherName: user?.name,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'QR Code',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (pendingGradingCount > 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrbit.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.accentOrbit.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.assignment_late_rounded,
                                  color: AppTheme.accentOrbit,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$pendingGradingCount submission(s) pending your review & grading',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 18),

                // AI Assessment Studio Hero Card
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AiAssessmentHubScreen(
                          preselectedClass: selectedClass,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B2D8E), Color(0xFF7E3AF2), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: AppTheme.heroShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'AI Quiz & Assessment Maker',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.auto_awesome_rounded, color: AppTheme.accentAmber, size: 16),
                                ],
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Google Forms-style quiz creator • Real-time auto-checking & item analytics',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppTheme.primary,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // In-Page Action Buttons Row (Quick Upload & New Activity)
                Row(
                  children: [
                    // Quick Upload Button (Cyan-blue gradient)
                    Expanded(
                      child: InkWell(
                        onTap: selectedClass == null
                            ? null
                            : () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) =>
                                      QuickActivitySheet(classGroup: selectedClass),
                                );
                              },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: AppTheme.cyanGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppTheme.subtlePillShadow,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Quick Upload',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // New Activity Button (Primary gradient)
                    Expanded(
                      child: InkWell(
                        onTap: selectedClass == null
                            ? null
                            : () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ActivityCreateScreen(
                                      classGroup: selectedClass),
                                ));
                              },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppTheme.subtlePillShadow,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'New Activity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Class Activities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${activities.length} visible',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Activity List
        if (activities.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
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
                    child: const Icon(Icons.inbox_outlined, size: 36, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No Activities Created Yet',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textMain),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Use Quick Upload or New Activity above to get started.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final act = activities[idx];
                final subs = activityProvider.submissionsForActivity(act.id);
                final submittedCount = subs
                    .where((s) =>
                        s.status == SubmissionStatus.submitted ||
                        s.status == SubmissionStatus.graded)
                    .length;
                return ActivityCard(
                  activity: act,
                  submittedCount: submittedCount,
                  totalStudents: students.length,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ActivityDetailScreen(activity: act),
                  )),
                );
              },
              childCount: activities.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildTypeFilterChip(ActivityType? type, String label, IconData icon) {
    final isSelected = _selectedTypeFilter == type;
    final color = type != null ? _getTypeColor(type) : AppTheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTypeFilter = isSelected ? null : type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(ActivityType type) {
    switch (type) {
      case ActivityType.module:
        return const Color(0xFF0284C7);
      case ActivityType.assignment:
        return const Color(0xFF2563EB);
      case ActivityType.quiz:
        return const Color(0xFFD97706);
      case ActivityType.project:
        return const Color(0xFF7C3AED);
      case ActivityType.exam:
        return const Color(0xFFDC2626);
      case ActivityType.seatwork:
        return const Color(0xFF059669);
    }
  }
}

class _TeacherGradebookView extends StatelessWidget {
  final ClassGroup? selectedClass;
  final List<ClassGroup> classes;
  final ValueChanged<ClassGroup> onClassSelected;
  final AuthProvider authProvider;
  final ActivityProvider activityProvider;

  const _TeacherGradebookView({
    required this.selectedClass,
    required this.classes,
    required this.onClassSelected,
    required this.authProvider,
    required this.activityProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedClass == null) {
      return const Center(child: Text('Please select a class'));
    }
    final students = authProvider.studentsInClass(selectedClass!.id);
    final activities = activityProvider.activitiesForClass(selectedClass!.id);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Class Gradebook',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMain,
                        letterSpacing: -0.4,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (selectedClass == null) return;
                        final typedStudents = students.cast<User>();
                        try {
                          final path =
                              await activityProvider.exportGradebookCsv(
                            classId: selectedClass!.id,
                            students: typedStudents,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'CSV saved:\n${path.split('/').last}'),
                                backgroundColor: AppTheme.statusGraded,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Export failed: $e'),
                                backgroundColor: AppTheme.statusMissing,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.statusGraded.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.statusGraded
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download_rounded,
                                size: 15, color: AppTheme.statusGraded),
                            SizedBox(width: 5),
                            Text('Export CSV',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.statusGraded)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Monitor student submissions and performances',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 18),
                // Horizontal class pills
                if (classes.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: classes.map((c) {
                        final isSel = selectedClass?.id == c.id;
                        return GestureDetector(
                          onTap: () => onClassSelected(c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.textMain : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppTheme.cardShadow,
                              border: Border.all(
                                color: isSel ? AppTheme.textMain : AppTheme.borderLight,
                              ),
                            ),
                            child: Text(
                              c.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? Colors.white : AppTheme.textMain,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (students.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
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
                    child: const Icon(Icons.people_outline_rounded, size: 36, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No Students Enrolled',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textMain),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final student = students[idx];
                final subs = activityProvider.submissionsForStudent(student.id);
                final gradedSubs = subs.where((s) => s.grade != null).toList();
                final totalEarned = gradedSubs.fold(0.0, (sum, s) => sum + (s.grade ?? 0));
                final totalPossible = activities.fold(0.0, (sum, a) => sum + a.totalPoints);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.6)),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textMain),
                    ),
                    subtitle: Text(
                      totalPossible > 0
                          ? '${totalEarned.toInt()} / ${totalPossible.toInt()} Points Total'
                          : 'No points posted',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: totalPossible > 0
                        ? _GradeBadge(earned: totalEarned, total: totalPossible)
                        : null,
                    children: activities.map((act) {
                      Submission? sub;
                      try {
                        sub = subs.firstWhere((s) => s.activityId == act.id);
                      } catch (_) {}
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        title: Text(
                          act.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                        ),
                        subtitle: Text(
                          act.typeLabel,
                          style: TextStyle(fontSize: 11, color: act.typeColor, fontWeight: FontWeight.w700),
                        ),
                        trailing: sub?.grade != null
                            ? Text(
                                '${sub!.grade!.toInt()} / ${act.totalPoints.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.statusGraded,
                                ),
                              )
                            : Text(
                                sub?.statusLabel ?? 'Pending',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sub?.statusColor ?? AppTheme.textMuted,
                                ),
                              ),
                      );
                    }).toList(),
                  ),
                );
              },
              childCount: students.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final double earned;
  final double total;
  const _GradeBadge({required this.earned, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (earned / total) : 0.0;
    final color = pct >= 0.9
        ? AppTheme.statusGraded
        : pct >= 0.75
            ? AppTheme.primary
            : pct >= 0.6
                ? AppTheme.statusPending
                : AppTheme.statusMissing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(pct * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TeacherProfileView extends StatelessWidget {
  final AuthProvider authProvider;
  const _TeacherProfileView({required this.authProvider});

  @override
  Widget build(BuildContext context) {
    final user = authProvider.currentUser!;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: AppTheme.floatingShadow,
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'T',
                        style: const TextStyle(
                          fontSize: 38,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textMain),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Instructor / Teacher',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.email,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // Quick stats box
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statColumn('Active Classes', '${authProvider.teacherClasses.length}', Icons.class_rounded),
                      Container(height: 40, width: 1, color: AppTheme.borderLight),
                      _statColumn('Role Status', 'Verified', Icons.verified_user_rounded),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // App Guide & Walkthrough Card
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppGuideOnboardingScreen(isFirstLaunch: false),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_stories_rounded, color: AppTheme.primary, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How to Use EduSync (App Guide)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Step-by-step feature steps, QR scanning & grading',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Privacy Policy & Terms Link Card
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.security_rounded, color: AppTheme.primary, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Privacy Policy & Terms of Service',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Data protection, camera permissions & disclosures',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Community Standards Link Card
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CommunityStandardsScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.gavel_rounded, color: AppTheme.primary, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Community Standards & Code of Conduct',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Academic integrity, respectful communication & safety',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sign out card button
                InkWell(
                  onTap: () async {
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.statusMissing.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.statusMissing.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: AppTheme.statusMissing, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Sign Out Account',
                          style: TextStyle(
                            color: AppTheme.statusMissing,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.textMain, size: 19),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onTap,
      ),
    );
  }
}
