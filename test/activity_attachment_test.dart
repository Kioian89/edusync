import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edusync/models/activity.dart';
import 'package:edusync/models/submission.dart';
import 'package:edusync/providers/activity_provider.dart';
import 'package:edusync/screens/teacher/grade_entry_screen.dart';
import 'package:edusync/widgets/activity_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('Activity attachments', () {
    test('keeps attachment names and download URLs through serialization', () {
      final activity = Activity(
        id: 'activity-1',
        title: 'Review worksheet',
        description: '',
        classId: 'class-1',
        teacherId: 'teacher-1',
        type: ActivityType.assignment,
        deadline: DateTime(2026, 12, 1),
        totalPoints: 10,
        createdAt: DateTime(2026, 11, 1),
        attachments: ['worksheet.pdf'],
        attachmentUrls: ['https://example.com/worksheet.pdf'],
      );

      final restored = Activity.fromMap(activity.toMap());

      expect(restored.attachments, ['worksheet.pdf']);
      expect(restored.attachmentUrlAt(0), 'https://example.com/worksheet.pdf');
    });

    test('supports activities created before download URLs were stored', () {
      final activity = Activity.fromMap({
        'id': 'activity-legacy',
        'title': 'Legacy worksheet',
        'description': '',
        'classId': 'class-1',
        'teacherId': 'teacher-1',
        'type': 'assignment',
        'deadline': '2026-12-01T00:00:00.000',
        'totalPoints': 10,
        'createdAt': '2026-11-01T00:00:00.000',
        'attachments': ['worksheet.pdf'],
      });

      expect(activity.attachments, ['worksheet.pdf']);
      expect(activity.attachmentUrlAt(0), isNull);
    });

    test('keeps student submission file URLs through serialization', () {
      final submission = Submission(
        id: 'submission-1',
        activityId: 'activity-1',
        studentId: 'student-1',
        studentName: 'Student',
        status: SubmissionStatus.submitted,
        fileNames: ['report.pdf'],
        fileUrls: ['https://example.com/report.pdf'],
      );

      final restored = Submission.fromMap(submission.toMap());

      expect(restored.fileNames, ['report.pdf']);
      expect(restored.fileUrls, ['https://example.com/report.pdf']);
    });

    test('supports submissions created before file URLs were stored', () {
      final submission = Submission.fromMap({
        'id': 'submission-legacy',
        'activityId': 'activity-1',
        'studentId': 'student-1',
        'studentName': 'Student',
        'status': 'submitted',
        'fileNames': ['report.pdf'],
      });

      expect(submission.fileNames, ['report.pdf']);
      expect(submission.fileUrls, isEmpty);
    });

    testWidgets('student dashboard attachment tap opens its download URL', (
      tester,
    ) async {
      const urlLauncherChannel = MethodChannel(
        'plugins.flutter.io/url_launcher',
      );
      final launchedUrls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(urlLauncherChannel, (call) async {
            if (call.method == 'launch') {
              launchedUrls.add(
                (call.arguments as Map<Object?, Object?>)['url'] as String,
              );
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(urlLauncherChannel, null),
      );

      var activityCardTapped = false;
      final activity = Activity(
        id: 'activity-1',
        title: 'Review worksheet',
        description: '',
        classId: 'class-1',
        teacherId: 'teacher-1',
        type: ActivityType.assignment,
        deadline: DateTime(2026, 12, 1),
        totalPoints: 10,
        createdAt: DateTime(2026, 11, 1),
        attachments: ['worksheet.pdf'],
        attachmentUrls: ['https://example.com/worksheet.pdf'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ActivityCard(
                  activity: activity,
                  onTap: () => activityCardTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('worksheet.pdf'));
      await tester.pumpAndSettle();

      expect(launchedUrls, ['https://example.com/worksheet.pdf']);
      expect(activityCardTapped, isFalse);
    });

    testWidgets('teacher can open a submitted student document', (
      tester,
    ) async {
      const urlLauncherChannel = MethodChannel(
        'plugins.flutter.io/url_launcher',
      );
      final launchedUrls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(urlLauncherChannel, (call) async {
            if (call.method == 'launch') {
              launchedUrls.add(
                (call.arguments as Map<Object?, Object?>)['url'] as String,
              );
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(urlLauncherChannel, null),
      );

      final activity = Activity(
        id: 'activity-1',
        title: 'Review worksheet',
        description: '',
        classId: 'class-1',
        teacherId: 'teacher-1',
        type: ActivityType.assignment,
        deadline: DateTime(2026, 12, 1),
        totalPoints: 10,
        createdAt: DateTime(2026, 11, 1),
      );
      final submission = Submission(
        id: 'submission-1',
        activityId: activity.id,
        studentId: 'student-1',
        studentName: 'Student',
        status: SubmissionStatus.submitted,
        fileNames: ['report.pdf'],
        fileUrls: ['https://example.com/report.pdf'],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ActivityProvider(),
          child: MaterialApp(
            home: GradeEntryScreen(
              submission: submission,
              activity: activity,
              studentName: 'Student',
            ),
          ),
        ),
      );

      await tester.tap(find.text('report.pdf'));
      await tester.pumpAndSettle();

      expect(launchedUrls, ['https://example.com/report.pdf']);
    });
  });
}
