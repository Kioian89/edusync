import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gemini_assistant_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gemini_api_key_dialog.dart';

class GeminiAssistantScreen extends StatefulWidget {
  const GeminiAssistantScreen({super.key});

  @override
  State<GeminiAssistantScreen> createState() => _GeminiAssistantScreenState();
}

class _GeminiAssistantScreenState extends State<GeminiAssistantScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = TextEditingControllerScrollHook();

  final List<String> _quickPrompts = [
    'Create 5 quiz questions on Photosynthesis with answer key',
    'Write a rubric for grading science lab experiments',
    'Generate an engaging 45-min lesson plan for High School',
    'Draft a parent update announcement about midterms',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final user = context.read<AuthProvider>().currentUser;
        context.read<GeminiAssistantProvider>().init(userId: user?.id);
      }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showApiKeyDialog(BuildContext context, GeminiAssistantProvider gemini) {
    GeminiApiKeyDialog.show(context);
  }

  void _sendMessage() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();

    final auth = context.read<AuthProvider>();
    final activeClass = auth.teacherClasses.isNotEmpty
        ? auth.teacherClasses.first.displayName
        : null;

    context
        .read<GeminiAssistantProvider>()
        .sendMessage(text, classContext: activeClass);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final activeClass = auth.teacherClasses.isNotEmpty
        ? auth.teacherClasses.first.displayName
        : null;

    final gemini = context.watch<GeminiAssistantProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: Colors.white,
        title: InkWell(
          onTap: () => _showApiKeyDialog(context, gemini),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Hero(
                  tag: 'lodix_ai_avatar',
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.subtlePillShadow,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Lodix Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: gemini.hasKey
                                  ? AppTheme.statusGraded
                                  : AppTheme.statusPending,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              gemini.hasKey
                                  ? 'Connected • ${gemini.providerDisplayName}'
                                  : 'Tap to configure AI Key',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: gemini.hasKey
                                    ? AppTheme.statusGraded
                                    : AppTheme.statusPending,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              gemini.hasKey ? Icons.tune_rounded : Icons.key_rounded,
              size: 20,
              color: gemini.hasKey ? AppTheme.primary : AppTheme.statusPending,
            ),
            tooltip: gemini.hasKey ? 'Lodix AI Settings' : 'Configure AI Key',
            onPressed: () => _showApiKeyDialog(context, gemini),
          ),
          if (gemini.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  size: 20, color: AppTheme.textSecondary),
              tooltip: 'Clear Chat',
              onPressed: () => gemini.clearChat(),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Class context pill if classes exist
          if (activeClass != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppTheme.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  const Icon(Icons.class_rounded, size: 13, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Class context: $activeClass',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),

          // If no API Key is set, show a prominent helper banner
          if (!gemini.hasKey)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppTheme.floatingShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
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
                          'Configure Lodix AI Key',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Paste your free Google Gemini, Groq, or OpenAI key to activate instant AI lesson planning and test generation.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _showApiKeyDialog(context, gemini),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: gemini.messages.isEmpty
                ? _buildEmptyState(gemini)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: gemini.messages.length,
                    itemBuilder: (context, idx) {
                      final msg = gemini.messages[idx];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // Loading indicator
          if (gemini.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Lodix is thinking...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Error alert banner
          if (gemini.errorMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.statusPending.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.statusPending.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.statusPending,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      gemini.errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showApiKeyDialog(context, gemini),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Configure',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Input Field
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: TextField(
                      controller: _textCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ask Lodix anything for your class...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: gemini.isLoading ? null : _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.floatingShadow,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(GeminiAssistantProvider gemini) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.floatingShadow,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Meet Lodix, Your AI Copilot!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ask me to draft exam questions, build lesson plans, create grading rubrics, or summarize topics.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._quickPrompts.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  _textCtrl.text = p;
                  _sendMessage();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(GeminiMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: msg.isUser ? AppTheme.textMain : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 20),
          ),
          boxShadow: AppTheme.cardShadow,
          border: msg.isUser ? null : Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  msg.isUser
                      ? Icons.person_rounded
                      : Icons.auto_awesome_rounded,
                  size: 14,
                  color: msg.isUser ? Colors.white70 : AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  msg.isUser ? 'You' : 'Lodix AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: msg.isUser ? Colors.white70 : AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                color: msg.isUser ? Colors.white : AppTheme.textMain,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Controller helper hook
class TextEditingControllerScrollHook extends ScrollController {}
