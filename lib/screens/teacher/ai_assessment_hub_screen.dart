import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/assessment.dart';
import '../../models/assessment_question.dart';
import '../../models/class_group.dart';
import '../../providers/activity_provider.dart';
import '../../providers/assessment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gemini_assistant_provider.dart';
import '../../services/assessment_ai_service.dart';
import '../../theme/app_theme.dart';
import 'assessment_analytics_screen.dart';
import 'assessment_editor_screen.dart';

class AiAssessmentHubScreen extends StatefulWidget {
  final ClassGroup? preselectedClass;

  const AiAssessmentHubScreen({super.key, this.preselectedClass});

  @override
  State<AiAssessmentHubScreen> createState() => _AiAssessmentHubScreenState();
}

class _AiAssessmentHubScreenState extends State<AiAssessmentHubScreen>
    with SingleTickerProviderStateMixin {
  final _uuid = const Uuid();
  late TabController _tabController;

  // Generator form controllers
  final _contentCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(text: 'Chapter Assessment');
  final _subjectCtrl = TextEditingController(text: 'Science');
  final _gradeCtrl = TextEditingController(text: 'Grade 10');

  int _questionCount = 10;
  String _difficulty = 'Medium';
  String? _uploadedFileName;
  String? _uploadedFileType;

  final Set<QuestionType> _selectedTypes = {
    QuestionType.multipleChoice,
    QuestionType.trueFalse,
    QuestionType.identification,
  };

  AssessmentAiAnalysisResult? _analysisResult;
  bool _isAnalyzing = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contentCtrl.dispose();
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx', 'txt', 'doc'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _uploadedFileName = file.name;
        _uploadedFileType = file.extension?.toLowerCase() ?? 'txt';
      });

      // If text file, read text directly
      if (file.path != null && file.extension?.toLowerCase() == 'txt') {
        try {
          final content = await File(file.path!).readAsString();
          _contentCtrl.text = content;
          _autoTitleFromFile(file.name);
          _runAnalysis();
        } catch (_) {}
      } else {
        _autoTitleFromFile(file.name);
        // Inform user that file name and prompt are set
        if (_contentCtrl.text.isEmpty) {
          _contentCtrl.text =
              'Lesson Material: ${file.name}\n\nKey Topics covered in this module for assessment generation.';
        }
        _runAnalysis();
      }
    }
  }

  void _autoTitleFromFile(String filename) {
    final dot = filename.lastIndexOf('.');
    final base = dot != -1 ? filename.substring(0, dot) : filename;
    _titleCtrl.text =
        '${base.replaceAll('_', ' ').replaceAll('-', ' ')} Quiz';
  }

  void _loadSampleLesson() {
    setState(() {
      _titleCtrl.text = 'Photosynthesis & Cellular Respiration Quiz';
      _subjectCtrl.text = 'Biology';
      _gradeCtrl.text = 'Grade 9';
      _contentCtrl.text = '''
PHOTOSYNTHESIS AND CELLULAR RESPIRATION

1. Introduction to Photosynthesis:
Photosynthesis is the biological process by which autotrophic organisms, such as green plants, algae, and cyanobacteria, convert solar light energy into chemical energy stored in glucose molecules. This essential process occurs primarily within specialized cellular organelles called chloroplasts.

2. The Photosynthesis Chemical Equation:
6CO₂ + 6H₂O + Light Energy → C₆H₁₂O₆ + 6O₂
Carbon dioxide and water react in the presence of sunlight and chlorophyll pigment to produce glucose sugar and oxygen gas as a byproduct.

3. Two Stages of Photosynthesis:
- Light-Dependent Reactions: Take place across the thylakoid membrane inside chloroplasts. Solar photons excite electrons in chlorophyll, splitting water molecules (photolysis) to release oxygen and generate ATP and NADPH energy carriers.
- Light-Independent Reactions (Calvin Cycle): Take place in the stroma fluid of the chloroplast. ATP and NADPH are utilized to fix inorganic CO₂ into organic glucose.

4. Cellular Respiration:
Cellular respiration is the reciprocal metabolic process where eukaryotic cells break down glucose in the presence of oxygen to release usable energy in the form of Adenosine Triphosphate (ATP).
Equation: C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O + 36-38 ATP.
Respiration proceeds through four phases: Glycolysis in the cytoplasm, Pyruvate Oxidation, Krebs Cycle (Citric Acid Cycle) in the mitochondrial matrix, and the Electron Transport Chain (ETC) across the inner mitochondrial membrane.
''';
    });
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAnalyzing = true);
    final geminiKey = context.read<GeminiAssistantProvider>().apiKey;

    final result = await AssessmentAiService.analyzeLessonMaterial(
      lessonContent: text,
      subject: _subjectCtrl.text.trim(),
      gradeLevel: _gradeCtrl.text.trim(),
      apiKey: geminiKey,
    );

    setState(() {
      _analysisResult = result;
      _questionCount = result.recommendedQuestionCount;
      _difficulty = result.detectedDifficulty;
      _isAnalyzing = false;
    });
  }

  Future<void> _generateAssessment() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste or upload lesson material first.')),
      );
      return;
    }

    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 question type.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    final geminiKey = context.read<GeminiAssistantProvider>().apiKey;
    final auth = context.read<AuthProvider>();
    final assessmentProv = context.read<AssessmentProvider>();

    final questions = await AssessmentAiService.generateAssessmentQuestions(
      lessonContent: text,
      title: _titleCtrl.text.trim().isEmpty ? 'Assessment' : _titleCtrl.text.trim(),
      subject: _subjectCtrl.text.trim(),
      gradeLevel: _gradeCtrl.text.trim(),
      questionCount: _questionCount,
      questionTypes: _selectedTypes.toList(),
      difficulty: _difficulty,
      apiKey: geminiKey,
    );

    // Save material to repository
    if (_analysisResult != null) {
      await assessmentProv.saveLearningMaterial(
        teacherId: auth.currentUser?.id ?? 'teacher',
        title: _titleCtrl.text.trim(),
        content: text,
        subject: _subjectCtrl.text.trim(),
        gradeLevel: _gradeCtrl.text.trim(),
        fileName: _uploadedFileName,
        fileType: _uploadedFileType ?? 'pasted',
        summary: _analysisResult?.summary,
        keyConcepts: _analysisResult?.keyConcepts,
        learningObjectives: _analysisResult?.learningObjectives,
        recommendedQuestionCount: _analysisResult?.recommendedQuestionCount ?? 10,
        detectedDifficulty: _analysisResult?.detectedDifficulty ?? 'Medium',
      );
    }

    final newAssessment = Assessment(
      id: _uuid.v4(),
      title: _titleCtrl.text.trim().isEmpty ? 'Assessment' : _titleCtrl.text.trim(),
      instructions: 'Carefully read each item and answer thoroughly.',
      classId: widget.preselectedClass?.id ?? '',
      teacherId: auth.currentUser?.id ?? 'teacher',
      subject: _subjectCtrl.text.trim(),
      gradeLevel: _gradeCtrl.text.trim(),
      difficulty: _difficulty,
      questions: questions,
      lessonMaterial: text,
    );

    setState(() => _isGenerating = false);

    if (!mounted) return;

    // Navigate directly into Google Forms-like editor
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentEditorScreen(
          assessment: newAssessment,
          preselectedClass: widget.preselectedClass,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Assessment Studio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textMain,
                    ),
                  ),
                  Text(
                    'Google Forms-style AI Quiz & Activity Maker',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(text: 'Generate Quiz'),
            Tab(text: 'Lesson Modules'),
            Tab(text: 'Analytics & Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneratorTab(),
          _buildMaterialsTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  // --- TAB 1: AI GENERATOR ---
  Widget _buildGeneratorTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Step 1: Lesson Material Input Card
        _buildSectionCard(
          title: '1. Lesson Material or Module',
          subtitle: 'Upload PDF, DOCX, PPTX, TXT or paste your lesson content',
          icon: Icons.upload_file_rounded,
          action: TextButton.icon(
            onPressed: _loadSampleLesson,
            icon: const Icon(Icons.auto_awesome_rounded, size: 15),
            label: const Text('Load Sample Lesson',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upload buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppTheme.borderLight),
                      ),
                      onPressed: _pickFile,
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(
                        _uploadedFileName ?? 'Upload File (PDF, DOCX, TXT)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Paste from Clipboard',
                    icon: const Icon(Icons.paste_rounded, color: AppTheme.primary),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _contentCtrl.text = data!.text!;
                        _runAnalysis();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content TextField
              TextField(
                controller: _contentCtrl,
                maxLines: 7,
                style: const TextStyle(fontSize: 13, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Paste lesson notes, chapter text, or module concepts here...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                ),
                onChanged: (_) {
                  if (_contentCtrl.text.length % 150 == 0) {
                    _runAnalysis();
                  }
                },
              ),
              const SizedBox(height: 8),

              // Analysis Trigger Button
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isAnalyzing ? null : _runAnalysis,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded, size: 14),
                  label: Text(
                    _isAnalyzing ? 'Analyzing Lesson...' : 'Analyze with AI',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Step 2: AI Lesson Analysis Preview Card
        if (_analysisResult != null) ...[
          _buildAnalysisCard(),
          const SizedBox(height: 14),
        ],

        // Step 3: Assessment Configuration Card
        _buildSectionCard(
          title: '2. Assessment Customization',
          subtitle: 'Configure question count, types, and assessment metadata',
          icon: Icons.tune_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title, Subject, Grade Level
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Assessment Title',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _gradeCtrl,
                      decoration: const InputDecoration(labelText: 'Grade Level', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Question Count Slider (1 to 50)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Number of Questions:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_questionCount Questions',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _questionCount.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                activeColor: AppTheme.primary,
                label: '$_questionCount',
                onChanged: (v) => setState(() => _questionCount = v.round()),
              ),
              // AI Recommendation pill
              if (_analysisResult != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _questionCount = _analysisResult!.recommendedQuestionCount;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tips_and_updates_rounded,
                            size: 14, color: AppTheme.statusPending),
                        const SizedBox(width: 4),
                        Text(
                          'AI Recommended: ${_analysisResult!.recommendedQuestionCount} questions (Tap to apply)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.statusPending,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // Question Types Multi-select
              const Text('Included Question Types:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: QuestionType.values.map((type) {
                  final isSelected = _selectedTypes.contains(type);
                  return FilterChip(
                    label: Text(type.label),
                    avatar: Icon(type.icon,
                        size: 14,
                        color: isSelected ? Colors.white : AppTheme.textSecondary),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppTheme.textMain,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTypes.add(type);
                        } else if (_selectedTypes.length > 1) {
                          _selectedTypes.remove(type);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Difficulty Selector
              Row(
                children: [
                  const Text('Difficulty:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  for (final diff in ['Easy', 'Medium', 'Hard']) ...[
                    ChoiceChip(
                      label: Text(diff),
                      selected: _difficulty == diff,
                      selectedColor: AppTheme.accentOrbit.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _difficulty == diff
                            ? AppTheme.accentOrbit
                            : AppTheme.textSecondary,
                      ),
                      onSelected: (sel) {
                        if (sel) setState(() => _difficulty = diff);
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Generate Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            onPressed: _isGenerating ? null : _generateAssessment,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(
              _isGenerating
                  ? 'Generating Assessment with AI...'
                  : 'Generate Complete Assessment',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildAnalysisCard() {
    final res = _analysisResult!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insights_rounded,
                    size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Lesson Analysis Insights',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.statusGraded.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${res.detectedDifficulty} Difficulty',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.statusGraded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            res.summary,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          const Text('Key Concepts Identified:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: res.keyConcepts.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Text(c,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: LEARNING MATERIALS ---
  Widget _buildMaterialsTab() {
    final assessmentProv = context.watch<AssessmentProvider>();
    final materials = assessmentProv.materials;

    if (materials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded,
                  size: 48, color: AppTheme.primary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              const Text(
                'No Lesson Materials Saved Yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload or paste lessons in the "Generate Quiz" tab, and they will be safely archived here for future use.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: materials.length,
      itemBuilder: (ctx, idx) {
        final m = materials[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description_rounded, color: AppTheme.primary),
            ),
            title: Text(m.title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${m.subject} • ${m.gradeLevel}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                if (m.summary != null) ...[
                  const SizedBox(height: 4),
                  Text(m.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'load') {
                  setState(() {
                    _titleCtrl.text = '${m.title} Quiz';
                    _subjectCtrl.text = m.subject;
                    _gradeCtrl.text = m.gradeLevel;
                    _contentCtrl.text = m.content;
                    _tabController.animateTo(0);
                  });
                  _runAnalysis();
                } else if (action == 'delete') {
                  assessmentProv.deleteLearningMaterial(m.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'load',
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 18, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Generate Quiz from this'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.statusMissing),
                      SizedBox(width: 8),
                      Text('Delete Material'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 3: ASSESSMENTS & ANALYTICS ---
  Widget _buildAnalyticsTab() {
    final activityProv = context.watch<ActivityProvider>();
    final assessmentProv = context.watch<AssessmentProvider>();
    final auth = context.watch<AuthProvider>();

    // Collect all activities with assessment data
    final teacherId = auth.currentUser?.id ?? '';
    final activities = activityProv
        .activitiesForTeacher(teacherId)
        .where((a) => a.isAiAssessment)
        .toList();

    if (activities.isEmpty && assessmentProv.drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_outlined,
                  size: 48, color: AppTheme.primary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              const Text('No Assessments Published Yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'Generate and publish a quiz in the "Generate Quiz" tab to unlock automated checking and class performance analytics.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activities.isNotEmpty) ...[
          const Text('Published Assessments & Performance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final act in activities) ...[
            _buildPublishedAssessmentTile(act),
            const SizedBox(height: 10),
          ],
        ],

        if (assessmentProv.drafts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Draft Assessments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final draft in assessmentProv.drafts) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: AppTheme.statusPending),
                title: Text(draft.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                subtitle: Text('${draft.questions.length} questions • Draft',
                    style: const TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Resume Editing',
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AssessmentEditorScreen(assessment: draft),
                        ));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.statusMissing),
                      onPressed: () => assessmentProv.deleteDraft(draft.id),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _buildPublishedAssessmentTile(dynamic act) {
    Assessment? assessment;
    try {
      if (act.assessmentData != null) {
        assessment = Assessment.fromJson(act.assessmentData!);
      }
    } catch (_) {}

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (assessment != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssessmentAnalyticsScreen(
                  assessment: assessment!,
                  activityId: act.id,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.statusGraded.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.quiz_rounded,
                        color: AppTheme.statusGraded, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          act.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textMain),
                        ),
                        Text(
                          '${assessment?.questions.length ?? 0} Questions • ${act.totalPoints.toStringAsFixed(0)} Points',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppTheme.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Auto-Graded Active',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.statusGraded)),
                    Text('View Analytics & Submissions →',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textMain)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
