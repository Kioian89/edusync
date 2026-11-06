import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_provider.dart';
import '../../models/submission.dart';
import '../../models/activity.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/sync_badge.dart';
import '../../widgets/student_qr_dialog.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import 'submit_activity_screen.dart';
import 'grades_screen.dart';
import 'student_announcements_screen.dart';
import '../community_standards_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final actProvider = context.watch<ActivityProvider>();

    final cls = auth.studentClass();
    final activities = cls != null
        ? actProvider.activitiesForClass(cls.id)
        : <Activity>[];
    final mySubmissions =
        actProvider.submissionsForStudent(auth.currentUser!.id);

    final pages = [
      _StudentActivitiesView(
        activities: activities,
        mySubmissions: mySubmissions,
        actProvider: actProvider,
        auth: auth,
        cls: cls,
      ),
      GradesScreen(
        activities: activities,
        mySubmissions: mySubmissions,
      ),
      _StudentProfileView(auth: auth),
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
            label: 'Tasks',
          ),
          CustomNavItem(
            icon: Icons.pie_chart_outline_rounded,
            selectedIcon: Icons.pie_chart_rounded,
            label: 'Grades',
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

class _StudentActivitiesView extends StatefulWidget {
  final List<Activity> activities;
  final List<Submission> mySubmissions;
  final ActivityProvider actProvider;
  final AuthProvider auth;
  final dynamic cls;

  const _StudentActivitiesView({
    required this.activities,
    required this.mySubmissions,
    required this.actProvider,
    required this.auth,
    required this.cls,
  });

  @override
  State<_StudentActivitiesView> createState() => _StudentActivitiesViewState();
}

class _StudentActivitiesViewState extends State<_StudentActivitiesView> {
  int _selectedFilterIndex = 0;
  String _searchQuery = '';
  static const _filters = ['All', 'Pending', 'Submitted', 'Graded', 'Missing'];

  List<Activity> _filtered() {
    final status = [
      null,
      SubmissionStatus.pending,
      SubmissionStatus.submitted,
      SubmissionStatus.graded,
      SubmissionStatus.missing,
    ][_selectedFilterIndex];

    return widget.activities.where((act) {
      if (_searchQuery.isNotEmpty &&
          !act.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedFilterIndex == 0) return true;
      Submission? sub;
      try {
        sub = widget.mySubmissions.firstWhere((s) => s.activityId == act.id);
      } catch (_) {}
      final subStatus = sub?.status ?? SubmissionStatus.pending;
      return subStatus == status;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser!;
    final now = DateTime.now();

    final dueTodayCount = widget.activities.where((a) {
      final sub = widget.mySubmissions.where((s) => s.activityId == a.id).firstOrNull;
      final notDone = sub == null ||
          (sub.status != SubmissionStatus.submitted && sub.status != SubmissionStatus.graded);
      return notDone &&
          a.deadline.year == now.year &&
          a.deadline.month == now.month &&
          a.deadline.day == now.day;
    }).length;

    final pendingCount = widget.mySubmissions.where((s) => s.status == SubmissionStatus.pending).length;
    final completedCount = widget.mySubmissions.where((s) => s.status == SubmissionStatus.graded || s.status == SubmissionStatus.submitted).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header like reference image (User circle + Title + action icons)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                            boxShadow: AppTheme.subtlePillShadow,
                          ),
                          child: Center(
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${user.name.split(" ").first}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'My Activities',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textMain,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SyncBadge(),
                        const SizedBox(width: 8),
                        if (widget.cls != null) ...[
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                              builder: (_) => StudentAnnouncementsScreen(
                                  classId: widget.cls!.id),
                            )),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppTheme.cardShadow,
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: const Icon(Icons.campaign_rounded,
                                  size: 20, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppTheme.cardShadow,
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Text(
                              widget.cls!.section,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Hero Blue Metric Banner (Direct inspiration from reference image top widget)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroCardGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppTheme.floatingShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pendingCount Pending Tasks',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dueTodayCount > 0 
                                  ? '⚠️ $dueTodayCount requirement(s) due today!'
                                  : '$completedCount completed requirements so far',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
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
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Horizontal Filter Capsules (like reference UI "All / Living Room / Kitchen")
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_filters.length, (i) {
                      final isSel = _selectedFilterIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilterIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.textMain : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: AppTheme.cardShadow,
                            border: Border.all(
                              color: isSel ? AppTheme.textMain : AppTheme.borderLight,
                            ),
                          ),
                          child: Text(
                            _filters[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              color: isSel ? Colors.white : AppTheme.textMain,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filtered Activities
        Builder(
          builder: (context) {
            final list = _filtered();
            if (list.isEmpty) {
              return SliverFillRemaining(
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
                        child: const Icon(Icons.done_all_rounded, size: 36, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No ${_filters[_selectedFilterIndex]} Activities',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textMain),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You are all caught up for this category!',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, idx) {
                  final act = list[idx];
                  Submission? sub;
                  try {
                    sub = widget.mySubmissions.firstWhere((s) => s.activityId == act.id);
                  } catch (_) {}
                  return ActivityCard(
                    activity: act,
                    submission: sub,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SubmitActivityScreen(
                        activity: act,
                        submission: sub,
                      ),
                    )),
                  );
                },
                childCount: list.length,
              ),
            );
          },
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
      ],
    );
  }
}

class _StudentProfileView extends StatelessWidget {
  final AuthProvider auth;
  const _StudentProfileView({required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser!;
    final cls = auth.studentClass();

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
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
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
                    'Student Account',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.email,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 18),

                // Digital Student Pass Button (Show QR Code)
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => StudentQrDialog(student: user),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.floatingShadow,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Show My QR Code Pass',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      _ProfileRow(
                        icon: Icons.class_rounded,
                        label: 'Enrolled Class',
                        value: cls != null ? cls.displayName : 'Not assigned',
                      ),
                      const Divider(height: 24),
                      const _ProfileRow(
                        icon: Icons.school_rounded,
                        label: 'Academic Year',
                        value: '2026 - 2027',
                      ),
                      const Divider(height: 24),
                      const _ProfileRow(
                        icon: Icons.verified_rounded,
                        label: 'System Sync',
                        value: 'Connected',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

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

                InkWell(
                  onTap: () async {
                    await auth.logout();
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
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textMain),
        ),
      ],
    );
  }
}
