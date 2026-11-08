import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../auth/landing_screen.dart';
import '../common/privacy_policy_screen.dart';

class AppGuideOnboardingScreen extends StatefulWidget {
  final bool isFirstLaunch;
  const AppGuideOnboardingScreen({super.key, this.isFirstLaunch = true});

  @override
  State<AppGuideOnboardingScreen> createState() => _AppGuideOnboardingScreenState();
}

class _AppGuideOnboardingScreenState extends State<AppGuideOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _hasAgreed = false;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _guideSteps = [
    {
      'step': 'STEP 1 OF 5',
      'title': 'Universal Class Management & QR Joining',
      'subtitle': 'Connect teachers and students across multiple sections instantly.',
      'icon': Icons.qr_code_2_rounded,
      'gradient': AppTheme.primaryGradient,
      'teacherBullets': [
        'Create and organize subjects and sections with 1-tap.',
        'Display live Class QR codes for instant student enrollment.',
        'Edit section details or delete old classes safely.',
      ],
      'studentBullets': [
        'Scan your teacher’s QR code to enroll in seconds.',
        'Enroll in multiple subjects simultaneously.',
      ],
    },
    {
      'step': 'STEP 2 OF 5',
      'title': 'Offline-First Activities & Submissions',
      'subtitle': 'Seamless classroom workflow that works with or without internet.',
      'icon': Icons.assignment_turned_in_rounded,
      'gradient': AppTheme.heroCardGradient,
      'teacherBullets': [
        'Post assignments, quizzes, and tasks with rubrics & deadlines.',
        'Auto-populate student submissions upon enrollment.',
      ],
      'studentBullets': [
        'Submit answers, files, and links directly inside the app.',
        'Drafts auto-save locally and auto-sync when back online.',
      ],
    },
    {
      'step': 'STEP 3 OF 5',
      'title': 'Digital Student Pass & Scanner',
      'subtitle': 'Rapid in-person verification with built-in camera scanning.',
      'icon': Icons.badge_rounded,
      'gradient': AppTheme.cyanGradient,
      'teacherBullets': [
        'Scan student passes in class to rapidly enroll or verify identity.',
        'Non-blocking scanner with automatic debouncing and retry.',
      ],
      'studentBullets': [
        'Instant personal QR Student Pass stored securely on device.',
        'No paper cards needed for classroom checks.',
      ],
    },
    {
      'step': 'STEP 4 OF 5',
      'title': 'AI Teaching Copilot (Google Gemini)',
      'subtitle': 'Accelerate lesson prep and assessment with Google AI.',
      'icon': Icons.auto_awesome_rounded,
      'gradient': AppTheme.orbitGradient,
      'teacherBullets': [
        'Generate 5-question quizzes, rubrics, and lesson plans instantly.',
        'Multi-model failover with Gemini 2.0 / Flash latest for high reliability.',
        'Central school AI key sharing via Firebase Cloud Firestore.',
      ],
      'studentBullets': [
        'Receive constructive, objective AI-assisted feedback from teachers.',
      ],
    },
    {
      'step': 'STEP 5 OF 5',
      'title': 'Real-Time Gradebook & Analytics',
      'subtitle': 'Comprehensive grade computation and one-click reporting.',
      'icon': Icons.analytics_rounded,
      'gradient': AppTheme.primaryGradient,
      'teacherBullets': [
        'Color-coded submission matrix (Graded, Pending, Missing).',
        'Automatic weighted percentage calculations.',
        'Export full class gradebook to CSV with 1 tap.',
      ],
      'studentBullets': [
        'Transparent breakdown of scores, feedback, and completion rate.',
      ],
    },
  ];

  Future<void> _completeOnboarding() async {
    if (widget.isFirstLaunch && !_hasAgreed) return;

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_terms', true);

    if (!mounted) return;
    if (widget.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LandingScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isFirstLaunch ? 'Welcome to EduSync' : 'EduSync Feature Guide',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        actions: [
          if (widget.isFirstLaunch)
            TextButton(
              onPressed: () {
                _pageController.animateToPage(
                  _guideSteps.length - 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Skip to Agreement', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: List.generate(
                  _guideSteps.length,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? AppTheme.primary
                            : (_currentIndex > index
                                ? AppTheme.primary.withValues(alpha: 0.35)
                                : AppTheme.borderLight),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _guideSteps.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (ctx, idx) {
                  final step = _guideSteps[idx];
                  final isLast = idx == _guideSteps.length - 1;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Visual Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: step['gradient'] as LinearGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: AppTheme.floatingShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  step['step'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(step['icon'] as IconData, color: Colors.white, size: 30),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      step['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                step['subtitle'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Teacher Highlights
                        _buildRoleSection(
                          roleTitle: 'FOR TEACHERS',
                          icon: Icons.school_rounded,
                          bullets: List<String>.from(step['teacherBullets']),
                        ),

                        const SizedBox(height: 14),

                        // Student Highlights
                        _buildRoleSection(
                          roleTitle: 'FOR STUDENTS',
                          icon: Icons.person_rounded,
                          bullets: List<String>.from(step['studentBullets']),
                        ),

                        // If last slide and first launch: Show Agreement Box
                        if (isLast && widget.isFirstLaunch) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: AppTheme.cardShadow,
                              border: Border.all(
                                color: _hasAgreed
                                    ? AppTheme.primary.withValues(alpha: 0.4)
                                    : AppTheme.borderLight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.privacy_tip_rounded, color: AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Privacy Policy & Agreement',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const PrivacyPolicyScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Read Full Policy',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'By continuing, you agree to EduSync\'s Terms of Service and Privacy Disclosures. '
                                  'Camera access is requested solely for QR scanning. Your educational records remain confidential.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                                ),
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: () => setState(() => _hasAgreed = !_hasAgreed),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _hasAgreed,
                                          activeColor: AppTheme.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) => setState(() => _hasAgreed = val ?? false),
                                        ),
                                        const Expanded(
                                          child: Text(
                                            'I have read and agree to the Terms of Service & Privacy Policy',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textMain,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Controls
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  Expanded(
                    child: _currentIndex < _guideSteps.length - 1
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Next Step', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: (widget.isFirstLaunch && !_hasAgreed)
                                  ? AppTheme.textMuted
                                  : AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: (widget.isFirstLaunch && !_hasAgreed) || _isSaving
                                ? null
                                : _completeOnboarding,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    widget.isFirstLaunch ? 'Accept & Get Started' : 'Done',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSection({
    required String roleTitle,
    required IconData icon,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                roleTitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentEmerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMain,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
