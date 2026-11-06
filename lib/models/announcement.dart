class Announcement {
  final String id;
  final String classId;
  final String teacherName;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isPinned;

  Announcement({
    required this.id,
    required this.classId,
    required this.teacherName,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isPinned = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'classId': classId,
        'teacherName': teacherName,
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'isPinned': isPinned,
      };

  factory Announcement.fromMap(Map<String, dynamic> map) => Announcement(
        id: map['id'],
        classId: map['classId'],
        teacherName: map['teacherName'] ?? 'Instructor',
        title: map['title'],
        message: map['message'],
        createdAt: DateTime.parse(map['createdAt']),
        isPinned: map['isPinned'] ?? false,
      );
}

