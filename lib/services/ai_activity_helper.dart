class AiActivityHelper {
  /// AI generates an Activity task with guide questions and instructions
  static Map<String, String> generateActivityContent({
    required String topic,
    required List<String> fileNames,
  }) {
    final lower = ('$topic ${fileNames.join(" ")}').toLowerCase();

    if (lower.contains('science') || lower.contains('bio') || lower.contains('ecosystem') || lower.contains('cell')) {
      return {
        'title': topic.isNotEmpty ? topic : 'Science Learning Activity & Investigation',
        'description': 'Read and study the attached module carefully.\n\n'
            'PART I: Conceptual Understanding\n'
            '1. Define the main concepts and scientific principles covered in the lesson.\n'
            '2. Explain the process or system and how each component interacts.\n\n'
            'PART II: Analysis & Critical Thinking\n'
            '3. What happens if one factor in the system is altered or removed?\n'
            '4. Provide an everyday example or practical application of this scientific law or process.\n\n'
            'PART III: Reflection & Conclusion\n'
            '5. Write a 3-5 sentence summary highlighting key takeaways from this module.',
        'answerSheetTemplate': 'NAME: [Student Name]\n'
            'DATE: [Date]\n'
            'SUBJECT: Science\n\n'
            '--- PART I: Conceptual Understanding ---\n'
            'Q1 Answer:\n\n'
            'Q2 Answer:\n\n'
            '--- PART II: Analysis & Critical Thinking ---\n'
            'Q3 Answer:\n\n'
            'Q4 Answer:\n\n'
            '--- PART III: Reflection & Conclusion ---\n'
            'Q5 Summary:\n\n',
        'teacherKey': 'Sample Evaluation Criteria:\n'
            '• Part I (15 pts): Accurate scientific terminology and sound definitions.\n'
            '• Part II (20 pts): Logical cause-and-effect reasoning and valid real-world example.\n'
            '• Part III (15 pts): Coherent summary synthesizing main concepts.',
      };
    } else if (lower.contains('math') || lower.contains('algebra') || lower.contains('geometry') || lower.contains('calc')) {
      return {
        'title': topic.isNotEmpty ? topic : 'Mathematics Problem Set & Activity',
        'description': 'Review the formulas and step-by-step solutions in the uploaded module.\n\n'
            'PART I: Direct Computation & Solving\n'
            '1. Solve the fundamental equations provided in Section A of the module.\n'
            '2. Show complete algebraic manipulation and step-by-step simplification.\n\n'
            'PART II: Word Problem & Application\n'
            '3. Read the word problem in the attached module. Identify the given values, the unknown variable, and write the mathematical model.\n'
            '4. Solve the word problem and state the final answer with appropriate units.\n\n'
            'PART III: Mathematical Justification\n'
            '5. Explain in 2-3 sentences why you selected that specific formula or method.',
        'answerSheetTemplate': 'NAME: [Student Name]\n'
            'DATE: [Date]\n'
            'SUBJECT: Mathematics\n\n'
            '--- PART I: Computations ---\n'
            'Item 1 Solution:\n\n'
            'Item 2 Solution:\n\n'
            '--- PART II: Word Problem ---\n'
            'Item 3 Given & Equation:\n\n'
            'Item 4 Step-by-Step Solving & Final Answer:\n\n'
            '--- PART III: Justification ---\n'
            'Item 5 Explanation:\n\n',
        'teacherKey': 'Sample Scoring Guide:\n'
            '• Computations (20 pts): Correct derivation and accurate numerical result.\n'
            '• Word Problem (20 pts): Proper identification of variables and unit correctness.\n'
            '• Justification (10 pts): Clear rationale for method chosen.',
      };
    } else if (lower.contains('history') || lower.contains('social') || lower.contains('ap') || lower.contains('philippine')) {
      return {
        'title': topic.isNotEmpty ? topic : 'Social Studies / History Activity Worksheet',
        'description': 'Carefully read the historical documents and chapter narratives in the attached module.\n\n'
            'PART I: Historical Context\n'
            '1. Identify the key historical figures, dates, and settings central to this event.\n'
            '2. What were the primary social, economic, or political causes that triggered this development?\n\n'
            'PART II: Document & Source Analysis\n'
            '3. Analyze the viewpoints presented in the primary source excerpts in the module.\n'
            '4. How did this event shape the community or nation in subsequent years?\n\n'
            'PART III: Critical Essay Question\n'
            '5. In 1-2 paragraphs, relate the historical lessons of this module to modern civic life.',
        'answerSheetTemplate': 'NAME: [Student Name]\n'
            'DATE: [Date]\n'
            'SUBJECT: Social Studies / History\n\n'
            '--- PART I: Historical Context ---\n'
            'Q1 Figures & Timeline:\n\n'
            'Q2 Root Causes:\n\n'
            '--- PART II: Source Analysis ---\n'
            'Q3 Viewpoints & Arguments:\n\n'
            'Q4 Long-term Impacts:\n\n'
            '--- PART III: Critical Reflection ---\n'
            'Q5 Modern Connection:\n\n',
        'teacherKey': 'Rubric:\n'
            '• Historical Accuracy (20 pts): Proper names, dates, and chronology.\n'
            '• Analytical Depth (20 pts): Strong understanding of historical causation.\n'
            '• Critical Reflection (10 pts): Insightful synthesis connecting to modern context.',
      };
    } else {
      return {
        'title': topic.isNotEmpty ? topic : 'Module Review & Guided Activity Sheet',
        'description': 'Study the attached lesson materials thoroughly.\n\n'
            'PART I: Key Concept Identification\n'
            '1. Enumerate and define the five core concepts introduced in this chapter.\n'
            '2. Why are these concepts important to this subject area?\n\n'
            'PART II: Practical Application & Case Scenario\n'
            '3. Describe a realistic scenario where you would apply what you learned from this module.\n'
            '4. What challenges or limitations might arise, and how can they be overcome?\n\n'
            'PART III: Personal Reflection & Insights\n'
            '5. Summarize what you learned most effectively and any areas that require further study.',
        'answerSheetTemplate': 'NAME: [Student Name]\n'
            'DATE: [Date]\n'
            'SUBJECT: General Subject\n\n'
            '--- PART I: Core Concepts ---\n'
            '1.\n2.\n3.\n4.\n5.\n\n'
            'Significance:\n\n'
            '--- PART II: Practical Application ---\n'
            'Case Scenario:\n\n'
            'Challenges & Solutions:\n\n'
            '--- PART III: Reflection ---\n'
            'Key Insights:\n\n',
        'teacherKey': 'Grading Criteria:\n'
            '• Completeness & Accuracy (25 pts): Addressed all prompts thoroughly.\n'
            '• Practical Application (15 pts): Feasible and well-thought-out case scenario.\n'
            '• Reflection & Effort (10 pts): Genuine critical evaluation.',
      };
    }
  }
}

