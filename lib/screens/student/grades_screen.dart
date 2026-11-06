import 'package:flutter/material.dart';
import '../../models/activity.dart';
import '../../models/submission.dart';
import '../../theme/app_theme.dart';

class GradesScreen extends StatelessWidget {
  final List<Activity> activities;
  final List<Submission> mySubmissions;

  const GradesScreen({
    super.key,
    required this.activities,
    required this.mySubmissions,
  });

  @override
  Widget build(BuildContext context) {
    final gradedSubs = mySubmissions.where((s) => s.grade != null).toList();
    final totalEarned = gradedSubs.fold(0.0, (sum, s) => sum + (s.grade ?? 0));
    final totalPossible = activities.fold(0.0, (sum, a) => sum + a.totalPoints);
    final pct = totalPossible > 0 ? totalEarned / totalPossible : 0.0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Grades & Standing',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Overall academic performance & activity breakdown',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Main Performance Blue Gradient Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: AppTheme.floatingShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'CURRENT TOTAL GRADE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _gradeLabel(pct),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            totalEarned.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 4),
                            child: Text(
                              '/ ${totalPossible.toInt()} pts',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Rounded Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Grid of 2-column rounded cards for category scores
                const Text(
                  'Category Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ActivityType.values.map((type) {
                    final typeActs = activities.where((a) => a.type == type).toList();
                    if (typeActs.isEmpty) return const SizedBox.shrink();
                    final typePossible = typeActs.fold(0.0, (sum, a) => sum + a.totalPoints);
                    final typeEarned = typeActs.fold(0.0, (sum, a) {
                      final sub = mySubmissions
                          .where((s) => s.activityId == a.id && s.grade != null)
                          .firstOrNull;
                      return sum + (sub?.grade ?? 0);
                    });

                    final width = (MediaQuery.of(context).size.width - 50) / 2;

                    return Container(
                      width: width,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppTheme.cardShadow,
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _typeColor(type).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_typeIcon(type), size: 16, color: _typeColor(type)),
                              ),
                              const Spacer(),
                              Text(
                                '${typeActs.length} items',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            type.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${typeEarned.toInt()} / ${typePossible.toInt()} pts',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Itemized Activity Scores',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Activity list
        if (activities.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No activities yet.')),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final act = activities[idx];
                Submission? sub;
                try {
                  sub = mySubmissions.firstWhere((s) => s.activityId == act.id);
                } catch (_) {}

                final hasGrade = sub?.grade != null;
                final subPct = hasGrade ? sub!.grade! / act.totalPoints : null;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.7)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: act.typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_typeIcon(act.type), color: act.typeColor, size: 20),
                    ),
                    title: Text(
                      act.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textMain),
                    ),
                    subtitle: Text(
                      act.typeLabel,
                      style: TextStyle(fontSize: 11, color: act.typeColor, fontWeight: FontWeight.w700),
                    ),
                    trailing: hasGrade
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${sub!.grade!.toInt()} / ${act.totalPoints.toInt()} pts',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textMain),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _gradeColor(subPct!).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${(subPct * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: _gradeColor(subPct),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            sub?.statusLabel ?? 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sub?.statusColor ?? AppTheme.statusPending,
                            ),
                          ),
                  ),
                );
              },
              childCount: activities.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Color _gradeColor(double pct) {
    if (pct >= 0.9) return AppTheme.statusGraded;
    if (pct >= 0.75) return AppTheme.primary;
    if (pct >= 0.6) return AppTheme.statusPending;
    return AppTheme.statusMissing;
  }

  String _gradeLabel(double pct) {
    if (pct >= 0.9) return 'EXCELLENT';
    if (pct >= 0.75) return 'GOOD STANDING';
    if (pct >= 0.6) return 'SATISFACTORY';
    if (pct > 0) return 'NEEDS REVIEW';
    return 'NO GRADES';
  }

  Color _typeColor(ActivityType type) {
    switch (type) {
      case ActivityType.module:
        return Colors.teal;
      case ActivityType.assignment:
        return AppTheme.primary;
      case ActivityType.quiz:
        return AppTheme.statusPending;
      case ActivityType.project:
        return Colors.purple;
      case ActivityType.exam:
        return AppTheme.statusMissing;
      case ActivityType.seatwork:
        return AppTheme.statusGraded;
    }
  }

  IconData _typeIcon(ActivityType type) {
    switch (type) {
      case ActivityType.module:
        return Icons.menu_book_rounded;
      case ActivityType.assignment:
        return Icons.assignment_rounded;
      case ActivityType.quiz:
        return Icons.help_outline_rounded;
      case ActivityType.project:
        return Icons.science_rounded;
      case ActivityType.exam:
        return Icons.description_rounded;
      case ActivityType.seatwork:
        return Icons.task_alt_rounded;
    }
  }
}
