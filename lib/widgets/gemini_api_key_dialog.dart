import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/gemini_assistant_provider.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

class GeminiApiKeyDialog {
  /// Opens a guided sheet for the teacher to set their AI API key.
  /// Supports any provider (Google Gemini, Groq, OpenAI, Anthropic Claude, OpenRouter, DeepSeek).
  /// Auto-detects the provider from the key format and saves it locally and privately.
  static Future<bool> show(BuildContext context) async {
    final gemini = context.read<GeminiAssistantProvider>();
    final keyCtrl = TextEditingController(text: gemini.apiKey ?? '');
    bool isSubmitting = false;
    bool obscureText = true;
    String? localError;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            final currentKey = keyCtrl.text.trim();
            final detected = currentKey.isNotEmpty
                ? GeminiService.detectProvider(currentKey)
                : (gemini.hasKey
                    ? gemini.detectedProvider
                    : AiProvider.unknown);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx2).size.height * 0.92,
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

                      // Header - Lodix AI Universal Engine
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
                                  'Lodix AI Configuration',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Universal AI Engine • Gemini, Groq, OpenAI & Claude',
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
                      const SizedBox(height: 16),

                      // Free API Key Guide Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.stars_rounded,
                                    size: 16, color: AppTheme.primary),
                                SizedBox(width: 6),
                                Text(
                                  'Recommended Free AI Providers',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'You can paste any API key below. Lodix automatically identifies your provider and configures the optimal model:',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildProviderPill(
                                  title: 'Google AI Studio (Free)',
                                  subtitle: 'AIza... (Gemini 2.0 Flash)',
                                  url: 'https://aistudio.google.com/app/apikey',
                                  color: const Color(0xFF1A73E8),
                                  isRecommended: true,
                                ),
                                _buildProviderPill(
                                  title: 'Groq (Free & Ultra Fast)',
                                  subtitle: 'gsk_... (Llama 3.3)',
                                  url: 'https://console.groq.com/keys',
                                  color: const Color(0xFFF55036),
                                  isRecommended: true,
                                ),
                                _buildProviderPill(
                                  title: 'OpenAI Platform',
                                  subtitle: 'sk-... (ChatGPT)',
                                  url: 'https://platform.openai.com/api-keys',
                                  color: const Color(0xFF10A37F),
                                  isRecommended: false,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Field
                      TextField(
                        controller: keyCtrl,
                        obscureText: obscureText,
                        onChanged: (_) => setModalState(() {}),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste any API key (AIza..., gsk_..., sk-...)',
                          labelText: 'Lodix AI API Key',
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
                                tooltip: obscureText ? 'Show key' : 'Hide key',
                                onPressed: () {
                                  setModalState(() => obscureText = !obscureText);
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
                      const SizedBox(height: 8),

                      // Real-time Provider Detection Badge
                      _buildDetectionBanner(detected, currentKey),

                      const SizedBox(height: 12),

                      // Privacy Note
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.15)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 16, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Private to your device. Your API key is stored safely on this phone only and never shared with other users or students.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (localError != null || gemini.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.statusMissing.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 16, color: AppTheme.statusMissing),
                              SizedBox(width: 8),
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

                                    try {
                                      final success = await gemini
                                          .setApiKey(entered)
                                          .timeout(
                                        const Duration(seconds: 7),
                                        onTimeout: () async {
                                          // Safety fallback: save locally if validation times out
                                          final prefs =
                                              await SharedPreferences.getInstance();
                                          await prefs.setString(
                                              'teacher_gemini_api_key', entered);
                                          return true;
                                        },
                                      );

                                      setModalState(() => isSubmitting = false);

                                      if (success && sheetCtx.mounted) {
                                        final provider =
                                            GeminiService.detectProvider(entered);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.white,
                                                    size: 18),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Lodix AI activated (${provider.displayName})!',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: AppTheme.statusGraded,
                                          ),
                                        );
                                        Navigator.pop(sheetCtx, true);
                                      } else {
                                        setModalState(() {
                                          localError = gemini.errorMessage ??
                                              'Failed to connect to AI provider. Please check your key.';
                                        });
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        isSubmitting = false;
                                        localError = 'Error saving key: $e';
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

  static Widget _buildDetectionBanner(AiProvider provider, String key) {
    if (key.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 14, color: AppTheme.textMuted),
            SizedBox(width: 6),
            Text(
              'Supports Google Gemini, Groq, OpenAI, Claude, DeepSeek & more',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Color color;
    IconData icon;
    String label;

    switch (provider) {
      case AiProvider.gemini:
        color = const Color(0xFF1A73E8);
        icon = Icons.check_circle_rounded;
        label = 'Auto-detected: Google Gemini (Gemini 2.0 Flash)';
        break;
      case AiProvider.groq:
        color = const Color(0xFFF55036);
        icon = Icons.bolt_rounded;
        label = 'Auto-detected: Groq (Llama 3.3 70B • Ultra Fast)';
        break;
      case AiProvider.openai:
        color = const Color(0xFF10A37F);
        icon = Icons.check_circle_rounded;
        label = 'Auto-detected: OpenAI (ChatGPT gpt-4o-mini)';
        break;
      case AiProvider.anthropic:
        color = const Color(0xFFD97706);
        icon = Icons.psychology_rounded;
        label = 'Auto-detected: Anthropic Claude (Claude 3.5 Haiku)';
        break;
      case AiProvider.openrouter:
        color = const Color(0xFF6366F1);
        icon = Icons.language_rounded;
        label = 'Auto-detected: OpenRouter (Multi-model)';
        break;
      case AiProvider.unknown:
        color = AppTheme.primary;
        icon = Icons.key_rounded;
        label = 'Universal AI Key: Will route to active endpoint';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildProviderPill({
    required String title,
    required String subtitle,
    required String url,
    required Color color,
    required bool isRecommended,
  }) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        try {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!launched) await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.open_in_new_rounded, size: 10, color: AppTheme.textMuted),
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
