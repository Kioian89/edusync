class ClassGroup {
  final String id;
  final String name;
  final String subject;
  final String section;
  final String teacherId;
  final List<String> studentIds;

  ClassGroup({
    required this.id,
    required this.name,
    required this.subject,
    required this.section,
    required this.teacherId,
    required this.studentIds,
  });

  String get displayName => '$subject - $section';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subject': subject,
        'section': section,
        'teacherId': teacherId,
        'studentIds': studentIds,
      };

  factory ClassGroup.fromMap(Map<String, dynamic> map) => ClassGroup(
        id: map['id'],
        name: map['name'],
        subject: map['subject'],
        section: map['section'],
        teacherId: map['teacherId'],
        studentIds: List<String>.from(map['studentIds'] ?? []),
      );
}

