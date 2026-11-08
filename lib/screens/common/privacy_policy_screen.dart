import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy & Terms',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppTheme.textMain,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: AppTheme.floatingShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Trust & Privacy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'EduSync Educational Platform Agreement & Privacy Disclosures',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Last Updated: November 2026',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            _buildSection(
              icon: Icons.school_rounded,
              title: '1. Educational Purpose & FERPA Principles',
              content:
                  'EduSync is an academic platform designed exclusively for educators and students. '
                  'We adhere strictly to educational confidentiality standards. '
                  'Student academic records, submissions, grades, and rosters are accessible only by the verified teacher '
                  'and the individual enrolled student. EduSync never sells, rents, or commercializes educational data.',
            ),

            _buildSection(
              icon: Icons.camera_alt_rounded,
              title: '2. Camera Hardware Permissions',
              content:
                  'EduSync requests access to your device camera strictly and exclusively for optical QR code scanning:\n'
                  '• For Students: Scanning teacher Class QR codes to enroll in courses.\n'
                  '• For Teachers: Scanning student Digital Passes for in-person identification.\n\n'
                  'Notice: EduSync never captures photos, records video, or uploads image media from the camera feed. '
                  'The camera stream is processed strictly in temporary device memory for barcode detection only.',
            ),

            _buildSection(
              icon: Icons.cloud_sync_rounded,
              title: '3. Data Storage & Offline-First Architecture',
              content:
                  'EduSync operates using a hybrid offline-first architecture:\n'
                  '• Local Storage: Class groups, drafts, and preferences are saved locally on your device for full offline usability.\n'
                  '• Cloud Sync: When an internet connection is active, data synchronizes with Google Cloud Firestore over encrypted TLS protocols.',
            ),

            _buildSection(
              icon: Icons.auto_awesome_rounded,
              title: '4. Lodix AI Pedagogical Assistant (Google Gemini & Universal Engine)',
              content:
                  'The built-in Lodix AI Assistant is powered by Google Gemini AI, Groq, and supported AI providers to assist teachers with lesson outlines, '
                  'quiz generation, and rubric development. Personal identifiable student data is never sent to AI models. '
                  'AI-generated suggestions should be reviewed by the educator prior to assignment distribution.',
            ),

            _buildSection(
              icon: Icons.rule_rounded,
              title: '5. Academic Integrity & Conduct',
              content:
                  'Users agree to maintain high standards of academic honesty. Submissions, feedback, and bulletins must '
                  'remain respectful and adhere to school district guidelines. Disruptive or fraudulent activities will '
                  'result in immediate account suspension.',
            ),

            _buildSection(
              icon: Icons.delete_forever_rounded,
              title: '6. User Rights & Data Deletion',
              content:
                  'You retain ownership of your educational materials. Teachers may update or delete their classes at any time. '
                  'To request complete account removal and data purging from Firestore servers, contact your school administrator or '
                  'email privacy@edusync.internal.',
            ),

            const SizedBox(height: 16),

            Center(
              child: Text(
                'EduSync © 2026 • Secure & Collaborative Learning',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
