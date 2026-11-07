# EduSync

EduSync is a Flutter application for managing classroom activities and grades. It provides separate workflows for teachers and students, with Firebase-backed accounts and classroom data.

## Features

- Teacher and student accounts
- Class management, including QR-based class enrollment
- Activity creation, student submissions, and grade management
- Class announcements and student grade views
- Optional Gemini-powered teaching assistance
- Firebase Cloud Messaging notifications

## Built with

- Flutter and Dart
- Firebase Authentication, Cloud Firestore, Cloud Storage, and Cloud Messaging
- Provider for app state management
- Firebase AI Logic and Google Gemini for AI-assisted features

## Getting started

### Requirements

- Flutter SDK compatible with the Dart constraint in [`pubspec.yaml`](./pubspec.yaml)
- A configured Firebase project for the platforms you want to run

### Setup

1. Clone the repository and enter the project directory.
2. Configure Firebase for your target platform using the [FlutterFire setup guide](https://firebase.google.com/docs/flutter/setup).
3. Install dependencies:

   ```sh
   flutter pub get
   ```

4. Start the app on a connected device or emulator:

   ```sh
   flutter run
   ```

Firebase-dependent features require valid Firebase configuration and appropriate Firebase security rules. Gemini features also require the AI configuration used by the app. Do not commit credentials, private API keys, or service-account files.

## Development

Run the test suite and static analysis before submitting changes:

```sh
flutter test
flutter analyze
```

See [COMMUNITY_STANDARDS.md](./COMMUNITY_STANDARDS.md) for expectations for contributors and community members.
