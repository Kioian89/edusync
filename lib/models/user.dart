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

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password = '',
    required this.role,
    this.classId,
    List<String>? enrolledClassIds,
  }) : enrolledClassIds = enrolledClassIds ?? (classId != null ? [classId] : []);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
        'classId': classId,
        'enrolledClassIds': enrolledClassIds,
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
    );
  }

  String get roleLabel => role == UserRole.teacher ? 'Teacher' : 'Student';

  Color get roleColor =>
      role == UserRole.teacher ? Colors.indigo : Colors.teal;
}

