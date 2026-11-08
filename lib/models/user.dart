import 'package:flutter/material.dart';

enum UserRole { teacher, student }

class User {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String? classId; // primary or active class
  final List<String> enrolledClassIds; // all enrolled classes for universal student logic
  final String? photoUrl; // profile photo URL (network URL or base64 data URI)

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password = '',
    required this.role,
    this.classId,
    List<String>? enrolledClassIds,
    this.photoUrl,
  }) : enrolledClassIds = enrolledClassIds ?? (classId != null ? [classId] : []);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
        'classId': classId,
        'enrolledClassIds': enrolledClassIds,
        'photoUrl': photoUrl,
      };

  factory User.fromMap(Map<String, dynamic> map) {
    final primaryClassId = map['classId'] as String?;
    final list = map['enrolledClassIds'];
    final enrolled = list != null
        ? List<String>.from(list)
        : (primaryClassId != null ? [primaryClassId] : <String>[]);

    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.student,
      ),
      classId: primaryClassId,
      enrolledClassIds: enrolled,
      photoUrl: map['photoUrl'] as String?,
    );
  }

  /// Returns a copy of this [User] with the given fields replaced.
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    String? classId,
    List<String>? enrolledClassIds,
    String? photoUrl,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      classId: classId ?? this.classId,
      enrolledClassIds: enrolledClassIds ?? List<String>.from(this.enrolledClassIds),
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  String get roleLabel => role == UserRole.teacher ? 'Teacher' : 'Student';

  Color get roleColor =>
      role == UserRole.teacher ? Colors.indigo : Colors.teal;
}
