import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edusync/models/class_group.dart';
import 'package:edusync/providers/auth_provider.dart';
import 'package:edusync/widgets/class_qr_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Teacher Class Creation & Student QR Join Tests', () {
    test('Teacher can create new class/section and student can join', () async {
      final auth = AuthProvider();
      await auth.init();

      // Sign in as teacher
      await auth.login('teacher@edusync.com', 'teacher123');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.isTeacher, isTrue);

      // Create new class
      final newCls = await auth.createClass(
        subject: 'Mathematics 10',
        section: 'Section Emerald',
      );

      expect(newCls, isNotNull);
      expect(newCls!.subject, equals('Mathematics 10'));
      expect(newCls.section, equals('Section Emerald'));
      expect(newCls.displayName, equals('Mathematics 10 - Section Emerald'));
      expect(auth.classes.any((c) => c.id == newCls.id), isTrue);

      // Switch to a student user
      final student = auth.users.firstWhere((u) => u.email == 'juan@edusync.com');
      await auth.login('juan@edusync.com', 'student123');
      expect(auth.isTeacher, isFalse);

      // Student joins the newly created class
      final err = await auth.joinClassByStudent(
        classId: newCls.id,
        studentId: student.id,
      );

      expect(err, isNull);

      // Verify student is now enrolled
      final updatedClass = auth.classes.firstWhere((c) => c.id == newCls.id);
      expect(updatedClass.studentIds.contains(student.id), isTrue);
      expect(auth.currentUser?.classId, equals(newCls.id));

      // Attempting to join again should prevent duplicates
      final duplicateErr = await auth.joinClassByStudent(
        classId: newCls.id,
        studentId: student.id,
      );
      expect(duplicateErr, contains('already enrolled'));
    });

    testWidgets('ClassQrDialog renders QR Code and Class Details', (tester) async {
      final dummyClass = ClassGroup(
        id: 'test-class-uuid-12345',
        name: 'Physics 101 - Newton Section',
        subject: 'Physics 101',
        section: 'Newton Section',
        teacherId: 'teacher-1',
        studentIds: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClassQrDialog(
              classGroup: dummyClass,
              teacherName: 'Prof. Einstein',
            ),
          ),
        ),
      );

      expect(find.text('Class QR Code'), findsOneWidget);
      expect(find.text('Physics 101'), findsOneWidget);
      expect(find.text('Newton Section'), findsOneWidget);
      expect(find.text('Instructor: Prof. Einstein'), findsOneWidget);
      expect(find.text('test-class-uuid-12345'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
