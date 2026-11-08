import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/activity.dart';
import '../../models/assessment.dart';
import '../../models/assessment_question.dart';
import '../../models/class_group.dart';
import '../../providers/activity_provider.dart';
import '../../providers/assessment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'assessment_student_preview_screen.dart';

class AssessmentEditorScreen extends StatefulWidget {
  final Assessment assessment;
  final ClassGroup? preselectedClass;

  const AssessmentEditorScreen({
    super.key,
    required this.assessment,
    this.preselectedClass,
  });

  @override
  State<AssessmentEditorScreen> createState() => _AssessmentEditorScreenState();
}

class _AssessmentEditorScreenState extends State<AssessmentEditorScreen> {
  final _uuid = const Uuid();
  late TextEditingController _titleCtrl;
  late TextEditingController _instructionsCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _gradeCtrl;
  late TextEditingController _passingScoreCtrl;
  late TextEditingController _timeLimitCtrl;

  late List<AssessmentQuestion> _questions;
  ClassGroup? _selectedClass;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.assessment;
    _titleCtrl = TextEditingController(text: a.title);
    _instructionsCtrl = TextEditingController(text: a.instructions);
    _subjectCtrl = TextEditingController(text: a.subject);
    _gradeCtrl = TextEditingController(text: a.gradeLevel);
    _passingScoreCtrl =
        TextEditingController(text: a.passingScore.toStringAsFixed(0));
    _timeLimitCtrl = TextEditingController(
        text: a.timeLimitMinutes != null ? a.timeLimitMinutes.toString() : '');

    _questions = a.questions.map((q) => q.copyWith()).toList();
    _selectedClass = widget.preselectedClass;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    _subjectCtrl.dispose();
    _gradeCtrl.dispose();
    _passingScoreCtrl.dispose();
    _timeLimitCtrl.dispose();
    super.dispose();
  }

  double get _totalPoints =>
      _questions.fold(0.0, (sum, q) => sum + q.points);

  void _syncModel() {
    widget.assessment.title = _titleCtrl.text.trim().isEmpty
        ? 'Untitled Assessment'
        : _titleCtrl.text.trim();
    widget.assessment.instructions = _instructionsCtrl.text.trim();
    widget.assessment.subject = _subjectCtrl.text.trim();
    widget.assessment.gradeLevel = _gradeCtrl.text.trim();
    widget.assessment.passingScore =
        double.tryParse(_passingScoreCtrl.text.trim()) ?? 75.0;
    widget.assessment.timeLimitMinutes =
        int.tryParse(_timeLimitCtrl.text.trim());
    widget.assessment.questions = _questions;
    widget.assessment.recalculateTotalPoints();
  }

  void _addQuestion({QuestionType type = QuestionType.multipleChoice}) {
    setState(() {
      _questions.add(AssessmentQuestion(
        id: _uuid.v4(),
        type: type,
        question: 'Untitled Question ${_questions.length + 1}',
        options: type == QuestionType.multipleChoice
            ? ['Option 1', 'Option 2', 'Option 3', 'Option 4']
            : (type == QuestionType.trueFalse ? ['True', 'False'] : []),
        correctAnswer: type == QuestionType.multipleChoice
            ? 'Option 1'
            : (type == QuestionType.trueFalse ? 'True' : ''),
        points: 1.0,
      ));
    });
  }

  void _duplicateQuestion(int index) {
    setState(() {
      final orig = _questions[index];
      _questions.insert(
        index + 1,
        orig.copyWith(
          id: _uuid.v4(),
          question: '${orig.question} (Copy)',
        ),
      );
    });
  }

  void _deleteQuestion(int index) {
    if (_questions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment must have at least 1 question.')),
      );
      return;
    }
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _moveQuestion(int from, int to) {
    if (to < 0 || to >= _questions.length) return;
    setState(() {
      final item = _questions.removeAt(from);
      _questions.insert(to, item);
    });
  }

  Future<void> _saveDraft() async {
    _syncModel();
    setState(() => _isSaving = true);
    await context.read<AssessmentProvider>().saveDraft(widget.assessment);
    setState(() => _isSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assessment saved to Drafts!'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Future<void> _publishAssessment() async {
    _syncModel();

    final auth = context.read<AuthProvider>();
    final teacherClasses = auth.teacherClasses;

    if (_selectedClass == null && teacherClasses.isNotEmpty) {
      // Prompt teacher to select class
      final pickedClass = await showDialog<ClassGroup>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Select Class to Assign',
              style: TextStyle(fontWeight: FontWeight.w800)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          children: teacherClasses
              .map((c) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('${c.subject} - ${c.section}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ))
              .toList(),
        ),
      );
      if (pickedClass == null) return;
      _selectedClass = pickedClass;
    }

    if (!mounted) return;

    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a class first.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    widget.assessment.classId = _selectedClass!.id;
    widget.assessment.teacherId = auth.currentUser?.id ?? 'teacher';
    widget.assessment.isPublished = true;
    widget.assessment.recalculateTotalPoints();

    // 1. Create or update in ActivityProvider so it appears in student tasks & gradebook
    final activity = Activity(
      id: widget.assessment.id,
      title: widget.assessment.title,
      description: widget.assessment.instructions,
      classId: _selectedClass!.id,
      teacherId: auth.currentUser?.id ?? 'teacher',
      type: ActivityType.quiz,
      deadline: widget.assessment.deadline ??
          DateTime.now().add(const Duration(days: 7)),
      totalPoints: widget.assessment.totalPoints,
      createdAt: widget.assessment.createdAt,
      assessmentData: widget.assessment.toJson(),
    );

    final activityProv = context.read<ActivityProvider>();
    final assessmentProv = context.read<AssessmentProvider>();
    final students = auth.studentsInClass(_selectedClass!.id);
    final studentIds = students.map((s) => s.id).toList();

    await activityProv.publishAssessmentActivity(activity, studentIds: studentIds);
    await assessmentProv.deleteDraft(widget.assessment.id);

    setState(() => _isSaving = false);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.statusGraded, size: 28),
            SizedBox(width: 10),
            Text('Published!', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          'Your assessment "${widget.assessment.title}" has been published to ${_selectedClass!.displayName}.\n\n'
          'Students can now take and submit this assessment interactively with automatic checking.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context, true); // Return to dashboard
            },
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  void _previewAssessment() {
    _syncModel();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentStudentPreviewScreen(
          assessment: widget.assessment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100 clean backdrop
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
              child: const Icon(Icons.assignment_turned_in_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Assessment Editor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined, color: AppTheme.primary),
            tooltip: 'Student Preview',
            onPressed: _previewAssessment,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: AppTheme.textSecondary),
            tooltip: 'Save Draft',
            onPressed: _isSaving ? null : _saveDraft,
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: AppTheme.cardShadow,
          border: const Border(top: BorderSide(color: AppTheme.borderLight)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: AppTheme.primary),
                ),
                onPressed: () => _addQuestion(),
                icon: const Icon(Icons.add_rounded, size: 18, color: AppTheme.primary),
                label: const Text('Add Question',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSaving ? null : _publishAssessment,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Publishing...' : 'Publish to Class',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // 1. Google Forms Style Header Card
          _buildHeaderCard(),

          const SizedBox(height: 16),

          // 2. Questions Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Questions (${_questions.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $_totalPoints pts',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Question Cards
          for (var i = 0; i < _questions.length; i++) ...[
            _buildQuestionCard(i),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent color bar (like Google Forms header)
          Container(
            height: 10,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Assessment Title',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppTheme.borderLight),
                const SizedBox(height: 10),

                // Description / Instructions Field
                TextField(
                  controller: _instructionsCtrl,
                  maxLines: 3,
                  minLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Instructions / Description for students...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),

                // Configuration Row (Subject, Grade, Time Limit, Passing Score)
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallField(
                        controller: _subjectCtrl,
                        label: 'Subject',
                        hint: 'Science',
                        icon: Icons.menu_book_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSmallField(
                        controller: _gradeCtrl,
                        label: 'Grade Level',
                        hint: 'Grade 10',
                        icon: Icons.school_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallField(
                        controller: _timeLimitCtrl,
                        label: 'Time Limit (mins)',
                        hint: 'No Limit',
                        icon: Icons.timer_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSmallField(
                        controller: _passingScoreCtrl,
                        label: 'Passing Score (%)',
                        hint: '75',
                        icon: Icons.percent_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted)),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Question number + Type Dropdown + Points
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Type selector dropdown
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<QuestionType>(
                      value: q.type,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: AppTheme.textSecondary),
                      onChanged: (newType) {
                        if (newType == null) return;
                        setState(() {
                          q.type = newType;
                          if (newType == QuestionType.multipleChoice &&
                              q.options.isEmpty) {
                            q.options = ['Option 1', 'Option 2', 'Option 3', 'Option 4'];
                            q.correctAnswer = 'Option 1';
                          } else if (newType == QuestionType.trueFalse) {
                            q.options = ['True', 'False'];
                            q.correctAnswer = 'True';
                          }
                        });
                      },
                      items: QuestionType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t.icon, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text(t.label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMain)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Points field
                Container(
                  width: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: q.points.toStringAsFixed(0),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMain),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          onChanged: (v) {
                            q.points = double.tryParse(v) ?? 1.0;
                            setState(() {});
                          },
                        ),
                      ),
                      const Text('pt',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optional Case Scenario (for situational / problem-solving)
                if (q.type == QuestionType.situational ||
                    q.type == QuestionType.problemSolving) ...[
                  TextFormField(
                    initialValue: q.caseScenario ?? '',
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    decoration: InputDecoration(
                      labelText: 'Case Scenario / Problem Statement',
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => q.caseScenario = v,
                  ),
                  const SizedBox(height: 12),
                ],

                // Question Prompt Input
                TextFormField(
                  initialValue: q.question,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter question text...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                  ),
                  onChanged: (v) => q.question = v,
                ),

                const SizedBox(height: 14),

                // Question Body Based on Type
                _buildQuestionSpecificInputs(q),

                const SizedBox(height: 12),

                // Explanation / Feedback input
                TextFormField(
                  initialValue: q.explanation ?? '',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppTheme.textMuted),
                    hintText: 'Optional answer explanation for students...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                  ),
                  onChanged: (v) => q.explanation = v,
                ),
              ],
            ),
          ),

          // Bottom Actions Row (Reorder, Duplicate, Delete)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  tooltip: 'Move Up',
                  color: index > 0 ? AppTheme.textSecondary : AppTheme.borderLight,
                  onPressed: index > 0 ? () => _moveQuestion(index, index - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  tooltip: 'Move Down',
                  color: index < _questions.length - 1
                      ? AppTheme.textSecondary
                      : AppTheme.borderLight,
                  onPressed: index < _questions.length - 1
                      ? () => _moveQuestion(index, index + 1)
                      : null,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.textSecondary),
                  tooltip: 'Duplicate',
                  onPressed: () => _duplicateQuestion(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppTheme.statusMissing),
                  tooltip: 'Delete Question',
                  onPressed: () => _deleteQuestion(index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSpecificInputs(AssessmentQuestion q) {
    switch (q.type) {
      case QuestionType.multipleChoice:
        return Column(
          children: [
            for (var optIdx = 0; optIdx < q.options.length; optIdx++) ...[
              _buildMultipleChoiceOptionRow(q, optIdx),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    q.options.add('Option ${q.options.length + 1}');
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Option',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        );

      case QuestionType.trueFalse:
        return Row(
          children: ['True', 'False'].map((val) {
            final isCorrect = q.correctAnswer.toString().toLowerCase() == val.toLowerCase();
            return Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => q.correctAnswer = val);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? AppTheme.statusGraded.withValues(alpha: 0.15)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect ? AppTheme.statusGraded : AppTheme.borderLight,
                      width: isCorrect ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: isCorrect ? AppTheme.statusGraded : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        val,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isCorrect ? AppTheme.statusGraded : AppTheme.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );

      case QuestionType.identification:
      case QuestionType.fillInTheBlanks:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.statusGraded.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.statusGraded.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: AppTheme.statusGraded),
                  SizedBox(width: 6),
                  Text('Correct Accepted Answer:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.statusGraded)),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: q.correctAnswer.toString(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain),
                decoration: const InputDecoration(
                  hintText: 'e.g. Photosynthesis',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  fillColor: Colors.white,
                ),
                onChanged: (v) => q.correctAnswer = v.trim(),
              ),
            ],
          ),
        );

      case QuestionType.matching:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Premise and Target Pairs:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final entry in q.matchingPairs.entries) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(entry.key,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppTheme.primary),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.statusGraded.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.statusGraded.withValues(alpha: 0.3)),
                        ),
                        child: Text(entry.value,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.statusGraded)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

      case QuestionType.enumeration:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Accepted Items (newline or comma separated):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: q.correctAnswer is List
                    ? (q.correctAnswer as List).join('\n')
                    : q.correctAnswer.toString(),
                maxLines: 3,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'Item 1\nItem 2\nItem 3',
                  fillColor: Colors.white,
                  isDense: true,
                ),
                onChanged: (v) {
                  q.correctAnswer = v
                      .split(RegExp(r'[\n,]'))
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                },
              ),
            ],
          ),
        );

      case QuestionType.shortAnswer:
      case QuestionType.essay:
      case QuestionType.situational:
      case QuestionType.problemSolving:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.rule_rounded, size: 16, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Text('Teacher Rubric / Expected Answer Criteria:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: q.correctAnswer.toString(),
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText:
                      'Provide key points, definitions, or principles students must mention...',
                  fillColor: Colors.white,
                  isDense: true,
                ),
                onChanged: (v) => q.correctAnswer = v,
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMultipleChoiceOptionRow(AssessmentQuestion q, int optIdx) {
    final optionText = q.options[optIdx];
    final isCorrect =
        q.correctAnswer.toString().trim() == optionText.trim();

    return Row(
      children: [
        // Mark as Correct Answer toggle button
        IconButton(
          icon: Icon(
            isCorrect
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isCorrect ? AppTheme.statusGraded : AppTheme.textMuted,
            size: 20,
          ),
          tooltip: isCorrect ? 'Correct Answer' : 'Mark as Correct Answer',
          onPressed: () {
            setState(() {
              q.correctAnswer = optionText;
            });
          },
        ),
        // Editable Option Text Field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isCorrect
                  ? AppTheme.statusGraded.withValues(alpha: 0.08)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCorrect
                    ? AppTheme.statusGraded.withValues(alpha: 0.4)
                    : AppTheme.borderLight,
              ),
            ),
            child: TextFormField(
              initialValue: optionText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCorrect ? FontWeight.w800 : FontWeight.w600,
                color: isCorrect ? AppTheme.statusGraded : AppTheme.textMain,
              ),
              decoration: InputDecoration(
                hintText: 'Option ${optIdx + 1}',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
                suffixText: isCorrect ? 'CORRECT' : null,
                suffixStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.statusGraded,
                ),
              ),
              onChanged: (v) {
                final oldVal = q.options[optIdx];
                q.options[optIdx] = v;
                if (q.correctAnswer == oldVal) {
                  q.correctAnswer = v;
                }
              },
            ),
          ),
        ),
        // Delete option button
        if (q.options.length > 2)
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 16, color: AppTheme.textMuted),
            tooltip: 'Remove Option',
            onPressed: () {
              setState(() {
                final removed = q.options.removeAt(optIdx);
                if (q.correctAnswer == removed && q.options.isNotEmpty) {
                  q.correctAnswer = q.options.first;
                }
              });
            },
          ),
      ],
    );
  }
}
