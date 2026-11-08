# 🏫 EduSync Community Standards & Guidelines

Welcome to the **EduSync** community! EduSync is an open-source Android mobile classroom management platform designed for teachers and students in Philippine schools.

These standards define our community values, educational ethics, data privacy commitments, and contribution expectations.

---

## 🎯 1. Community Purpose & Core Values

* **Educator Empowerment:** Reduce teacher paperwork and grading time through automated workflows, QR enrollment, and AI-assisted lesson prep.
* **Student Equity:** Ensure lightweight, offline-capable mobile performance that runs smoothly even on budget Android devices and limited internet connections.
* **Integrity & Respect:** Maintain a supportive, collaborative, and harassment-free environment for all teachers, learners, and open-source contributors.

---

## 🤝 2. Code of Conduct Summary

Everyone participating in EduSync spaces (GitHub issues, pull requests, discussions, code reviews) must abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

### Expected Standards
- Demonstrate kindness, empathy, and constructive communication.
- Gracefully accept and offer actionable feedback.
- Respect diverse backgrounds, technical skill levels, and classroom environments.
- Protect the privacy of students and educators at all times.

### Zero Tolerance
- Harassment, discrimination, or abusive language.
- Sharing private student grades, personal identifiable information (PII), or unauthorized classroom invite codes.
- Committing unauthorized credentials, security backdoors, or malicious code.

---

## 🤖 3. Ethical AI Standards (Lodix AI Engine)

EduSync features **Lodix AI**, a universal AI assistant supporting Google Gemini, Groq, OpenAI, Anthropic Claude, and OpenRouter. When developing or using AI features:

1. **Teacher in the Loop:** AI suggestions (such as quiz questions, rubrics, and lesson summaries) are aids for educators. Teachers maintain final authority and must review all generated materials before distribution.
2. **Student Privacy Protection:** Student personal data, names, and individual assessment responses must **never** be sent to third-party AI APIs without explicit user consent.
3. **Private Key Isolation:** API keys remain strictly on the teacher's physical device (`SharedPreferences`). Keys are never logged, uploaded to shared databases, or broadcast to other users or students.
4. **Academic Honesty:** AI tools are built to facilitate learning, scaffolding, and pedagogical efficiency—not academic shortcutting or plagiarism.

---

## 🛡️ 4. Data Privacy & Child Safety (RA 10173 Compliance)

In accordance with the **Philippine Data Privacy Act of 2012 (RA 10173)** and international child data protection practices:

* **Authentication Required:** All Firestore reads and writes are strictly restricted behind Firebase Authentication (`isAuthenticated()`).
* **Profile Ownership:** Profile photos, names, and settings are editable exclusively by the authenticated account owner (`isOwner(userId)`).
* **No Telemetry Tracking:** Student behavior is not tracked or sold to advertising networks.
* **Cloud Storage Integrity:** Uploaded activity attachments and avatar photos are managed securely via Firebase Storage with access control rules.

---

## 💻 5. Contribution & Quality Gateway

All contributions to EduSync must pass automated quality gates before being merged:

1. **Zero Analysis Warnings:**
   ```bash
   flutter analyze
   ```
   *Must return `No issues found!`*

2. **Full Automated Test Coverage:**
   ```bash
   flutter test
   ```
   *All unit, widget, and multi-class logic tests must pass (12+ tests).*

3. **Android-First Compatibility:**
   * Test changes on Android devices or emulators running API 23 (Android 6.0) through API 35 (Android 15).
   * Ensure offline caching functions gracefully when internet connectivity drops.

4. **Conventional Commits:**
   * Format: `feat(scope): description vX.Y.Z` or `fix(scope): description vX.Y.Z`

---

## 🐛 6. Reporting Issues & Vulnerabilities

* **Bugs:** Open a ticket using the [Bug Report Template](.github/ISSUE_TEMPLATE/bug_report.md).
* **Feature Ideas:** Submit suggestions via the [Feature Request Template](.github/ISSUE_TEMPLATE/feature_request.md).
* **Security Advisories:** **Do NOT** open a public issue for security bugs. Please follow our [Security Policy](SECURITY.md) to report responsibly via private GitHub advisories.

---

## 📄 7. Open Source License

EduSync is distributed under the [MIT License](LICENSE). Contributions submitted to this repository become part of the open-source codebase under the same license terms.

---

<div align="center">

*Mabuhay ang mga Gurong Pilipino!* 🇵🇭  
Thank you for helping build accessible, powerful educational technology for all.

</div>
