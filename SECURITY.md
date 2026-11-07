# Security Policy

## Supported Versions

The following table lists which versions of EduSync currently receive security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.4.x   | :white_check_mark: |
| 1.3.x   | :white_check_mark: |
| < 1.3.0 | :x:                |

---

## Reporting a Vulnerability

The EduSync team is committed to ensuring the safety and privacy of student and teacher data. If you discover a security vulnerability or sensitive data leak:

1. **Do NOT publicly disclose the issue** via public GitHub issues, pull requests, or forums.
2. Email the maintainers directly or use [GitHub Private Vulnerability Reporting](https://github.com/Kioian89/edusync/security/advisories/new).
3. Include detailed steps to reproduce the issue, proof of concept, and the affected software versions.
4. We will acknowledge receipt within 48 hours and provide a timeline for patch resolution.

---

## Secret & Credential Handling Standards

- **API Keys & Secrets**: Private credentials, service accounts, and API keys must never be hardcoded into source code. Always use environment variables (`.env`), CI/CD secrets (`secrets.GEMINI_API_KEY`), or authenticated backend synchronization.
- **Client Configuration Files**: `google-services.json` contains public client IDs and client-side identifiers for mobile apps. Ensure API key restrictions are applied in Google Cloud Console.
- **Firestore Security Rules**: All database requests must be authenticated and validated against `firestore.rules`.
