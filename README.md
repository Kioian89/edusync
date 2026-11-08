<div align="center">

<img src="assets/images/logo.png" alt="EduSync Logo" width="100" height="100" />

# EduSync

**Smart Classroom Management for Filipino Schools**

[![Release](https://img.shields.io/github/v/release/Kioian89/edusync?color=5B2D8E&label=Latest%20Release)](https://github.com/Kioian89/edusync/releases/latest)
[![Build](https://github.com/Kioian89/edusync/actions/workflows/release.yml/badge.svg)](https://github.com/Kioian89/edusync/actions/workflows/release.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/github/license/Kioian89/edusync?color=5B2D8E)](./LICENSE)

[📲 Download APK](https://github.com/Kioian89/edusync/releases/latest) · [🐛 Report Bug](https://github.com/Kioian89/edusync/issues/new?template=bug_report.md) · [💡 Request Feature](https://github.com/Kioian89/edusync/issues/new?template=feature_request.md)

</div>

---

## 📖 About EduSync

**EduSync** is a free, open-source Android classroom management app built with Flutter and Firebase, designed specifically for teachers and students in Philippine schools.

It streamlines the entire classroom experience — from class enrollment via QR code, to AI-powered quiz generation, to real-time grade tracking — all in one clean, offline-capable mobile app.

> **Built for teachers who want less paperwork and more teaching.**

---

## ✨ Features

### 👩‍🏫 For Teachers
| Feature | Description |
|---|---|
| 📋 **Class Management** | Create multiple class sections with QR codes for instant student enrollment |
| 📝 **Activity Builder** | Create quizzes, assignments, essays, and projects with deadlines and point values |
| 🤖 **AI Quiz Generator** | Generate quiz questions from any topic using Google Gemini AI (free API key) |
| 📊 **Grade Dashboard** | View all student submissions, grade them, and track class progress at a glance |
| 📢 **Announcements** | Post class-wide announcements that students see instantly |
| 📸 **Editable Profile** | Upload a profile photo to personalize your teacher account |

### 🎓 For Students
| Feature | Description |
|---|---|
| 📷 **QR Enrollment** | Scan teacher's QR code to instantly join any class |
| 📚 **Multi-Class View** | Enroll in multiple subjects and see all tasks in one dashboard |
| 📬 **Submit Activities** | Upload answers and files for teacher review and grading |
| 👥 **Classmates Status** | See your classmates' progress and completion status across all subjects |
| 🏆 **Grades View** | Track your own grades and feedback per activity |
| 📸 **Editable Profile** | Add a profile photo to your student account |

### 🔧 Technical Highlights
- 🔥 **Firebase** — Real-time Firestore database, Authentication, Cloud Storage
- 🤖 **Gemini 2.0 Flash** — AI-powered lesson analysis and quiz generation (free tier)
- 📡 **Shorebird** — Over-the-air (OTA) code push for instant updates
- 🔔 **FCM Push Notifications** — Instant alerts for new activities and grades
- 🎨 **Royal Purple Theme** — Clean, modern Material 3 UI
- 📶 **Offline Cache** — Works with limited connectivity using local SharedPreferences cache

---

## 📲 Download & Install

### Latest Release
👉 **[Download edusync.apk](https://github.com/Kioian89/edusync/releases/latest)**

1. Download `edusync.apk` from the latest release
2. On your Android phone: **Settings → Security → Allow unknown sources**
3. Open the downloaded APK and tap **Install**
4. Launch **EduSync** and register as a Teacher or Student

> **Requires Android 6.0 (API 23) or higher**

---

## 🚀 Getting Started (Development)

### Requirements
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (see `pubspec.yaml` for version)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- Android Studio or VS Code
- A Firebase project with Firestore, Auth, Storage, and Messaging enabled

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/Kioian89/edusync.git
cd edusync

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase
# Replace android/app/google-services.json with your own Firebase config

# 4. Run the app
flutter run
```

### Firestore Security Rules
Deploy the included rules to your Firebase project:
```bash
firebase deploy --only firestore:rules
```
Or paste the contents of [`firestore.rules`](./firestore.rules) in the Firebase Console.

### Run Tests
```bash
flutter test          # Run all tests
flutter analyze       # Static analysis (must show 0 issues)
```

---

## 🏗️ Project Structure

```
lib/
├── models/           # Data models (User, ClassGroup, Activity, Submission)
├── providers/        # State management (AuthProvider, ActivityProvider, GeminiAssistantProvider)
├── screens/
│   ├── teacher/      # Teacher-specific screens
│   └── student/      # Student-specific screens
├── services/         # Firebase, Gemini AI, and notification services
├── theme/            # App theme and color constants
└── widgets/          # Shared reusable widgets
```

---

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guide](./CONTRIBUTING.md) and [Code of Conduct](./CODE_OF_CONDUCT.md) before submitting a pull request.

```bash
# Fork → Branch → Code → Test → PR
git checkout -b feat/your-feature-name
flutter test && flutter analyze
git commit -m "feat(scope): description"
```

See [COMMUNITY_STANDARDS.md](./COMMUNITY_STANDARDS.md) for full guidelines.

---

## 🔒 Security

Found a security issue? Please **do not** open a public issue. Read our [Security Policy](./SECURITY.md) for responsible disclosure instructions.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](./LICENSE) file for details.

---

## 👨‍💻 About the Developer

**EduSync** was created to solve a real problem: teachers in the Philippines spending more time on paperwork than on teaching. It's built with love for Filipino educators and students. 🇵🇭

---

<div align="center">

Made with ❤️ using Flutter & Firebase

⭐ **Star this repo if EduSync helps your classroom!** ⭐

</div>
