import 'package:flutter/material.dart';

enum QuestionType {
  multipleChoice,
  trueFalse,
  identification,
  fillInTheBlanks,
  matching,
  enumeration,
  shortAnswer,
  essay,
  situational,
  problemSolving;

  String get label {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True or False';
      case QuestionType.identification:
        return 'Identification';
      case QuestionType.fillInTheBlanks:
        return 'Fill in the Blanks';
      case QuestionType.matching:
        return 'Matching Type';
      case QuestionType.enumeration:
        return 'Enumeration';
      case QuestionType.shortAnswer:
        return 'Short Answer';
      case QuestionType.essay:
        return 'Essay';
      case QuestionType.situational:
        return 'Situational';
      case QuestionType.problemSolving:
        return 'Problem Solving';
    }
  }

  IconData get icon {
    switch (this) {
      case QuestionType.multipleChoice:
        return Icons.radio_button_checked_rounded;
      case QuestionType.trueFalse:
        return Icons.check_circle_outline_rounded;
      case QuestionType.identification:
        return Icons.badge_outlined;
      case QuestionType.fillInTheBlanks:
        return Icons.horizontal_rule_rounded;
      case QuestionType.matching:
        return Icons.sync_alt_rounded;
      case QuestionType.enumeration:
        return Icons.format_list_numbered_rounded;
      case QuestionType.shortAnswer:
        return Icons.short_text_rounded;
      case QuestionType.essay:
        return Icons.article_rounded;
      case QuestionType.situational:
        return Icons.psychology_rounded;
      case QuestionType.problemSolving:
        return Icons.calculate_rounded;
    }
  }

  bool get isObjective {
    return this == QuestionType.multipleChoice ||
        this == QuestionType.trueFalse ||
        this == QuestionType.identification ||
        this == QuestionType.fillInTheBlanks ||
        this == QuestionType.matching;
  }
}

class AssessmentQuestion {
  String id;
  QuestionType type;
  String question;
  List<String> options; // For multiple choice & matching responses
  Map<String, String> matchingPairs; // For matching type: premise -> response
  dynamic correctAnswer; // String for MC/TF/Ident/Fill; List<String> for Enum
  double points;
  String? explanation;
  String? caseScenario; // For situational & problem solving

  AssessmentQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.options = const [],
    this.matchingPairs = const {},
    required this.correctAnswer,
    this.points = 1.0,
    this.explanation,
    this.caseScenario,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'question': question,
        'options': options,
        'matchingPairs': matchingPairs,
        'correctAnswer': correctAnswer,
        'points': points,
        'explanation': explanation,
        'caseScenario': caseScenario,
      };

  factory AssessmentQuestion.fromMap(Map<String, dynamic> map) {
    QuestionType resolvedType;
    try {
      resolvedType = QuestionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => QuestionType.multipleChoice,
      );
    } catch (_) {
      resolvedType = QuestionType.multipleChoice;
    }

    return AssessmentQuestion(
      id: map['id']?.toString() ?? '',
      type: resolvedType,
      question: map['question']?.toString() ?? '',
      options: (map['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      matchingPairs: (map['matchingPairs'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          {},
      correctAnswer: map['correctAnswer'] ?? '',
      points: (map['points'] as num?)?.toDouble() ?? 1.0,
      explanation: map['explanation']?.toString(),
      caseScenario: map['caseScenario']?.toString(),
    );
  }

  AssessmentQuestion copyWith({
    String? id,
    QuestionType? type,
    String? question,
    List<String>? options,
    Map<String, String>? matchingPairs,
    dynamic correctAnswer,
    double? points,
    String? explanation,
    String? caseScenario,
  }) {
    return AssessmentQuestion(
      id: id ?? this.id,
      type: type ?? this.type,
      question: question ?? this.question,
      options: options ?? List.from(this.options),
      matchingPairs: matchingPairs ?? Map.from(this.matchingPairs),
      correctAnswer: correctAnswer ?? this.correctAnswer,
      points: points ?? this.points,
      explanation: explanation ?? this.explanation,
      caseScenario: caseScenario ?? this.caseScenario,
    );
  }
}
