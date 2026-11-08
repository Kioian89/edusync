import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/gemini_assistant_provider.dart';
import '../theme/app_theme.dart';

class GeminiApiKeyDialog {
  /// Opens a comprehensive, step-by-step guided sheet to configure the Google Gemini API key.
  static Future<bool> show(BuildContext context) async {
    final gemini = context.read<GeminiAssistantProvider>();
    final keyCtrl = TextEditingController(text: gemini.apiKey ?? '');
    bool isSubmitting = false;
    bool syncToFirebase = true;
    bool obscureText = true;
    String? localError;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx2).size.height * 0.9,
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.borderLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppTheme.subtlePillShadow,
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
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
                                  'Google Gemini API Key',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Powers Lesson Analysis & AI Quiz Generation',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Step-by-Step Educational Guide Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.help_outline_rounded,
                                        size: 16, color: AppTheme.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      'How to get your FREE API Key',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.statusGraded
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '100% Free',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.statusGraded,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildGuideStep(
                              stepNum: '1',
                              title: 'Open Google AI Studio in your browser:',
                              action: InkWell(
                                onTap: () {
                                  Clipboard.setData(const ClipboardData(
                                      text: 'https://aistudio.google.com/'));
                                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'URL copied: https://aistudio.google.com/'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.link_rounded,
                                          size: 14, color: AppTheme.primary),
                                      SizedBox(width: 6),
                                      Text(
                                        'aistudio.google.com',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(Icons.copy_rounded,
                                          size: 12, color: AppTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildGuideStep(
                              stepNum: '2',
                              title:
                                  'Sign in with any standard Google or Gmail account.',
                            ),
                            const SizedBox(height: 10),
                            _buildGuideStep(
                              stepNum: '3',
                              title:
                                  'Click the blue "Get API key" button in the top left, then "Create API key in new project".',
                            ),
                            const SizedBox(height: 10),
                            _buildGuideStep(
                              stepNum: '4',
                              title:
                                  'Copy your new API key (starts with "AIzaSy...") and paste it below.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Field
                      TextField(
                        controller: keyCtrl,
                        obscureText: obscureText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'AIzaSy...',
                          labelText: 'Google Gemini API Key',
                          prefixIcon: const Icon(Icons.key_rounded,
                              size: 18, color: AppTheme.primary),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  obscureText
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 18,
                                  color: AppTheme.textMuted,
                                ),
                                tooltip:
                                    obscureText ? 'Show key' : 'Hide key',
                                onPressed: () {
                                  setModalState(
                                      () => obscureText = !obscureText);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.paste_rounded,
                                    size: 18, color: AppTheme.primary),
                                tooltip: 'Paste from clipboard',
                                onPressed: () async {
                                  final data =
                                      await Clipboard.getData('text/plain');
                                  if (data?.text != null) {
                                    keyCtrl.text = data!.text!.trim();
                                    setModalState(() {});
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Firebase School Sync Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: syncToFirebase,
                        activeColor: AppTheme.primary,
                        title: const Text(
                          'Share with Firebase (School AI)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                        ),
                        subtitle: const Text(
                          'Saves key to school database so all teachers in your school get AI access automatically without individual setup.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() => syncToFirebase = val);
                        },
                      ),

                      if (localError != null || gemini.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.statusMissing.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 16, color: AppTheme.statusMissing),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  localError ?? gemini.errorMessage ?? '',
                                  style: const TextStyle(
                                    color: AppTheme.statusMissing,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          if (gemini.hasKey)
                            TextButton(
                              onPressed: () async {
                                await gemini.removeApiKey();
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx, true);
                                }
                              },
                              child: const Text(
                                'Remove Key',
                                style: TextStyle(
                                  color: AppTheme.statusMissing,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(sheetCtx, false),
                            child: const Text('Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final entered = keyCtrl.text.trim();
                                    if (entered.isEmpty) {
                                      setModalState(() => localError =
                                          'Please enter or paste an API key.');
                                      return;
                                    }

                                    setModalState(() {
                                      isSubmitting = true;
                                      localError = null;
                                    });

                                    final success =
                                        await gemini.setApiKey(entered);
                                    if (success && syncToFirebase) {
                                      await gemini
                                          .setFirebaseCentralKey(entered);
                                    }

                                    setModalState(() => isSubmitting = false);

                                    if (success && sheetCtx.mounted) {
                                      Navigator.pop(sheetCtx, true);
                                    } else {
                                      setModalState(() {
                                        localError = gemini.errorMessage ??
                                            'Failed to connect to Google Gemini. Please check your key.';
                                      });
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save & Connect',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return result == true;
  }

  static Widget _buildGuideStep({
    required String stepNum,
    required String title,
    Widget? action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNum,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMain,
                  height: 1.3,
                ),
              ),
              ?action,
            ],
          ),
        ),
      ],
    );
  }
}
