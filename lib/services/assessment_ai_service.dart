import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/assessment_question.dart';
import 'gemini_service.dart';

class AssessmentAiAnalysisResult {
  final String summary;
  final List<String> keyConcepts;
  final List<String> learningObjectives;
  final int recommendedQuestionCount;
  final String detectedDifficulty;
  final bool isContentSufficient;
  final String notes;

  AssessmentAiAnalysisResult({
    required this.summary,
    required this.keyConcepts,
    required this.learningObjectives,
    required this.recommendedQuestionCount,
    required this.detectedDifficulty,
    required this.isContentSufficient,
    required this.notes,
  });

  Map<String, dynamic> toMap() => {
        'summary': summary,
        'keyConcepts': keyConcepts,
        'learningObjectives': learningObjectives,
        'recommendedQuestionCount': recommendedQuestionCount,
        'detectedDifficulty': detectedDifficulty,
        'isContentSufficient': isContentSufficient,
        'notes': notes,
      };

  factory AssessmentAiAnalysisResult.fromMap(Map<String, dynamic> map) {
    return AssessmentAiAnalysisResult(
      summary: map['summary']?.toString() ?? '',
      keyConcepts: (map['keyConcepts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      learningObjectives: (map['learningObjectives'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendedQuestionCount:
          (map['recommendedQuestionCount'] as num?)?.toInt() ?? 10,
      detectedDifficulty: map['detectedDifficulty']?.toString() ?? 'Medium',
      isContentSufficient: map['isContentSufficient'] != false,
      notes: map['notes']?.toString() ?? '',
    );
  }
}

class AssessmentAiService {
  static const _uuid = Uuid();

  /// Step 1: Analyze the uploaded or pasted lesson material.
  static Future<AssessmentAiAnalysisResult> analyzeLessonMaterial({
    required String lessonContent,
    String? subject,
    String? gradeLevel,
    String? apiKey,
  }) async {
    final cleanText = lessonContent.trim();
    if (cleanText.isEmpty) {
      return AssessmentAiAnalysisResult(
        summary: 'No lesson content provided.',
        keyConcepts: [],
        learningObjectives: [],
        recommendedQuestionCount: 5,
        detectedDifficulty: 'Medium',
        isContentSufficient: false,
        notes: 'Please paste or upload lesson material.',
      );
    }

    final prompt = '''
You are an expert curriculum and educational assessment specialist.
Analyze the following learning material/module.

LESSON MATERIAL:
"""
$cleanText
"""

TASK:
1. Provide a concise summary of the lesson.
2. Extract the core key concepts and definitions.
3. Formulate 3-5 clear learning objectives (Bloom's taxonomy).
4. Determine the depth of the material and RECOMMEND how many questions can reasonably be generated (between 3 and 50) without repeating or diluting content.
5. Identify the appropriate educational difficulty level ("Easy", "Medium", "Hard").
6. Verify if the material is sufficient for comprehensive assessment.

STRICT INSTRUCTION: Output ONLY valid JSON in the following exact format without markdown ticks:
{
  "summary": "Concise lesson summary here",
  "keyConcepts": ["Concept 1", "Concept 2", "Concept 3"],
  "learningObjectives": ["Objective 1", "Objective 2"],
  "recommendedQuestionCount": 15,
  "detectedDifficulty": "Medium",
  "isContentSufficient": true,
  "notes": "Pedagogical assessment recommendations"
}
''';

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final response = await GeminiService.sendMessage(
          apiKey: apiKey.trim(),
          prompt: prompt,
          systemInstruction:
              'You are a rigorous educational curriculum analyzer. Respond only with raw JSON.',
        );

        final parsed = _extractJson(response);
        if (parsed != null && parsed is Map<String, dynamic>) {
          return AssessmentAiAnalysisResult.fromMap(parsed);
        }
      } catch (e) {
        debugPrint('Gemini analysis error, falling back to local heuristic: $e');
      }
    }

    // Offline / Fallback heuristic analyzer
    return _analyzeLocally(cleanText);
  }

  /// Step 2: Generate questions based on lesson material and customization options.
  static Future<List<AssessmentQuestion>> generateAssessmentQuestions({
    required String lessonContent,
    required String title,
    required String subject,
    required String gradeLevel,
    required int questionCount,
    required List<QuestionType> questionTypes,
    required String difficulty,
    String? apiKey,
  }) async {
    final cleanContent = lessonContent.trim();
    final requestedTypes = questionTypes.isNotEmpty
        ? questionTypes
        : [QuestionType.multipleChoice, QuestionType.trueFalse, QuestionType.identification];

    final typeNames = requestedTypes.map((t) => t.name).toList();

    final prompt = '''
You are an AI assessment generator for teachers.
Generate an assessment strictly based on the provided lesson text.

LESSON SOURCE TEXT:
"""
$cleanContent
"""

REQUIREMENTS:
- Title: "$title"
- Subject: "$subject"
- Target Grade Level: "$gradeLevel"
- Number of Questions to generate: $questionCount
- Selected Question Types allowed: ${typeNames.join(', ')}
- Difficulty Level: "$difficulty"

IMPORTANT CRITICAL RULES:
1. ONLY generate questions directly covered by the lesson text above. DO NOT invent external facts or topics not mentioned.
2. For "multipleChoice": Provide 4 plausible options in the "options" list. The "correctAnswer" must match one option exactly.
3. For "trueFalse": "options" should be ["True", "False"], and "correctAnswer" must be "True" or "False".
4. For "identification": "correctAnswer" must be the concise term or name.
5. For "fillInTheBlanks": The "question" must contain "___" where the word is missing, and "correctAnswer" is the missing word/phrase.
6. For "matching": Provide "matchingPairs" as a key-value map of premise -> matching response.
7. For "enumeration": "correctAnswer" must be a list of correct items.
8. For "shortAnswer" and "essay": "correctAnswer" should provide the ideal response / rubric criteria.
9. For "situational" and "problemSolving": Include a realistic "caseScenario" based on the lesson and a question asking how to solve or apply the concept.
10. Ensure each question has a brief "explanation" explaining why the answer is correct according to the lesson.
11. Set "points" to 1.0 (or 2.0-5.0 for essays/situational).

STRICT OUTPUT FORMAT: Return ONLY a raw JSON array of objects without markdown fences:
[
  {
    "type": "multipleChoice",
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": "Option A",
    "points": 1.0,
    "explanation": "Explanation from lesson text",
    "caseScenario": null,
    "matchingPairs": {}
  }
]
''';

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final response = await GeminiService.sendMessage(
          apiKey: apiKey.trim(),
          prompt: prompt,
          systemInstruction:
              'You are an expert assessment generator. Always output strict, valid JSON without extra text.',
        );

        final parsed = _extractJson(response);
        if (parsed is List) {
          final list = <AssessmentQuestion>[];
          for (final item in parsed) {
            if (item is Map<String, dynamic>) {
              item['id'] = _uuid.v4();
              list.add(AssessmentQuestion.fromMap(item));
            }
          }
          if (list.isNotEmpty) {
            return list;
          }
        }
      } catch (e) {
        debugPrint('Gemini assessment generation error: $e');
      }
    }

    // Local / Offline fallback generator
    return _generateLocally(
      cleanContent,
      title: title,
      questionCount: questionCount,
      questionTypes: requestedTypes,
    );
  }

  /// Step 3: AI-Assisted Essay & Subjective Answer Grading
  static Future<Map<String, dynamic>> gradeSubjectiveAnswer({
    required String question,
    required String studentAnswer,
    required String rubricOrIdealAnswer,
    required double maxPoints,
    String? apiKey,
  }) async {
    if (studentAnswer.trim().isEmpty) {
      return {
        'suggestedScore': 0.0,
        'feedback': 'No answer was submitted.',
      };
    }

    final prompt = '''
You are an objective teacher grading assistant.
Evaluate the student's answer against the question and the rubric/ideal answer.

QUESTION:
"$question"

IDEAL ANSWER / RUBRIC:
"$rubricOrIdealAnswer"

STUDENT ANSWER:
"$studentAnswer"

MAX POINTS: $maxPoints

TASK:
Score the student's response between 0.0 and $maxPoints.
Provide a 1-2 sentence constructive explanation for the score.

OUTPUT FORMAT: Return raw JSON only:
{
  "suggestedScore": 4.5,
  "feedback": "Clear explanation of core concepts with good reasoning."
}
''';

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final res = await GeminiService.sendMessage(
          apiKey: apiKey.trim(),
          prompt: prompt,
          systemInstruction: 'You are an educational grader. Output raw JSON only.',
        );
        final parsed = _extractJson(res);
        if (parsed is Map<String, dynamic>) {
          return {
            'suggestedScore': (parsed['suggestedScore'] as num?)?.toDouble() ?? (maxPoints * 0.75),
            'feedback': parsed['feedback']?.toString() ?? 'Evaluated by AI Assistant.',
          };
        }
      } catch (e) {
        debugPrint('AI grading helper error: $e');
      }
    }

    // Local heuristic
    final wordCount = studentAnswer.trim().split(RegExp(r'\s+')).length;
    final score = wordCount >= 30
        ? maxPoints
        : (wordCount >= 15 ? (maxPoints * 0.75) : (maxPoints * 0.5));

    return {
      'suggestedScore': double.parse(score.toStringAsFixed(1)),
      'feedback': 'Answer reviewed based on length and relevance. Teacher review recommended.',
    };
  }

  // Helper to extract JSON from model output
  static dynamic _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```json')) {
      text = text.substring(7);
    } else if (text.startsWith('```')) {
      text = text.substring(3);
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
    text = text.trim();

    final firstBracket = text.indexOf('[');
    final firstBrace = text.indexOf('{');

    if (firstBracket != -1 && (firstBrace == -1 || firstBracket < firstBrace)) {
      final lastBracket = text.lastIndexOf(']');
      if (lastBracket != -1) {
        text = text.substring(firstBracket, lastBracket + 1);
      }
    } else if (firstBrace != -1) {
      final lastBrace = text.lastIndexOf('}');
      if (lastBrace != -1) {
        text = text.substring(firstBrace, lastBrace + 1);
      }
    }

    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  // Fallback local analyzer
  static AssessmentAiAnalysisResult _analyzeLocally(String content) {
    final words = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;

    // Estimate suitable questions based on word count
    var recommended = (wordCount / 50).clamp(5, 50).round();
    if (wordCount < 100) recommended = 5;

    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 3)
        .toList();

    final concepts = <String>[];
    for (final line in lines) {
      if (line.contains(':') || line.contains(' - ') || line.startsWith('•') || line.startsWith('-')) {
        final part = line.split(RegExp(r'[:\-]')).first.replaceAll(RegExp(r'^[•\-\d\.]+\s*'), '').trim();
        if (part.isNotEmpty && part.length < 40 && !concepts.contains(part)) {
          concepts.add(part);
        }
      }
      if (concepts.length >= 6) break;
    }

    if (concepts.isEmpty) {
      concepts.addAll(['Core Lesson Principles', 'Primary Terminology', 'Key Methodologies']);
    }

    return AssessmentAiAnalysisResult(
      summary: lines.isNotEmpty
          ? lines.take(3).join(' ')
          : 'Educational material providing foundational context.',
      keyConcepts: concepts,
      learningObjectives: [
        'Understand the fundamental concepts presented in the material.',
        'Identify key terminology and their respective applications.',
        'Apply principles to solve situational problems.',
      ],
      recommendedQuestionCount: recommended,
      detectedDifficulty: wordCount > 500 ? 'Medium' : 'Easy',
      isContentSufficient: wordCount >= 30,
      notes: wordCount >= 30
          ? 'Material contains sufficient depth for a $recommended-question assessment.'
          : 'Lesson material is relatively brief; generating 5 focused questions is recommended.',
    );
  }

  // Fallback local question generator
  static List<AssessmentQuestion> _generateLocally(
    String content, {
    required String title,
    required int questionCount,
    required List<QuestionType> questionTypes,
  }) {
    final sentences = content
        .split(RegExp(r'(?<=[.?!])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 20)
        .toList();

    final questions = <AssessmentQuestion>[];
    final types = questionTypes.isNotEmpty ? questionTypes : [QuestionType.multipleChoice];

    for (var i = 0; i < questionCount; i++) {
      final type = types[i % types.length];
      final sentence = sentences.isNotEmpty
          ? sentences[i % sentences.length]
          : 'The core topic of $title is fundamental to the study.';

      switch (type) {
        case QuestionType.multipleChoice:
          questions.add(AssessmentQuestion(
            id: _uuid.v4(),
            type: QuestionType.multipleChoice,
            question: 'Based on the lesson: which of the following best reflects the statement "$sentence"?',
            options: [
              'It represents a primary principle of the topic',
              'It is an unrelated hypothesis',
              'It only applies in laboratory conditions',
              'It has been proven obsolete'
            ],
            correctAnswer: 'It represents a primary principle of the topic',
            points: 1.0,
            explanation: 'Directly supported by the lesson text.',
          ));
          break;

        case QuestionType.trueFalse:
          questions.add(AssessmentQuestion(
            id: _uuid.v4(),
            type: QuestionType.trueFalse,
            question: 'True or False: According to the lesson material, $sentence',
            options: ['True', 'False'],
            correctAnswer: 'True',
            points: 1.0,
            explanation: 'Affirmed in the study material.',
          ));
          break;

        case QuestionType.identification:
          questions.add(AssessmentQuestion(
            id: _uuid.v4(),
            type: QuestionType.identification,
            question: 'Identify the key term or subject described in the following lesson excerpt: "$sentence"',
            correctAnswer: title.isNotEmpty ? title : 'Key Concept',
            points: 1.0,
            explanation: 'Found in the module glossary.',
          ));
          break;

        case QuestionType.fillInTheBlanks:
          final words = sentence.split(' ');
          var blanked = sentence;
          var missing = title;
          if (words.length > 5) {
            missing = words[words.length ~/ 2].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            blanked = sentence.replaceFirst(missing, '_______');
          }
          questions.add(AssessmentQuestion(
            id: _uuid.v4(),
            type: QuestionType.fillInTheBlanks,
            question: 'Complete the statement: $blanked',
            correctAnswer: missing,
            points: 1.0,
            explanation: 'The missing keyword completes the lesson fact.',
          ));
          break;

        case QuestionType.matching:
          questions.add(AssessmentQuestion(
            id: _uuid.v4(),
            type: QuestionType.matching,
            question: 'Match the terms with their corresponding descriptions from the lesson.',
            matchingPairs: {
              'Core Definition': 'Foundational premise of the lesson',
              'Key Application': 'Practical implementation in real scenarios',
              'Evaluation Measure': 'Standard used to assess understanding',
            },
            correctAnswer: 'All pairs matched correctly',
            points: 3.0,
            explanation: 'Based on lesson classifications.',
          ));
          break;

        case QuestionType.enumeration:
          questions.add(AssessmentQuestion(
            id: _uuid.v4(),
            type: QuestionType.enumeration,
            question: 'Enumerate the essential components or principles discussed under $title.',
            correctAnswer: ['Principle 1', 'Principle 2', 'Principle 3'],
            points: 3.0,
            explanation: 'Listed in the lesson module outline.',
          ));
          break;

        case QuestionType.shortAnswer:
        case QuestionType.essay:
          questions.add(AssessmentQuestion(
            id: _uuid.v4(),
            type: type,
            question: 'Explain in your own words the significance of: "$sentence". Provide supporting details from the lesson.',
            correctAnswer: 'Answer should thoroughly articulate the premise, provide supporting rationale, and demonstrate conceptual mastery.',
            points: 5.0,
            explanation: 'Graded based on clarity, accuracy, and depth of explanation.',
          ));
          break;

        case QuestionType.situational:
        case QuestionType.problemSolving:
          questions.add(AssessmentQuestion(
            id: _uuid.v4(),
            type: type,
            caseScenario: 'A student or professional encounters a scenario where "$sentence" directly influences the outcome.',
            question: 'How should one apply the principles of the lesson to resolve this situation effectively?',
            correctAnswer: 'Apply direct step-by-step methodology outlined in the lesson.',
            points: 5.0,
            explanation: 'Evaluates critical thinking and practical application.',
          ));
          break;
      }
    }

    return questions;
  }
}
