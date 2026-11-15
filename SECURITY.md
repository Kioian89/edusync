# Security Policy

## Supported Versions

The following table lists which versions of EduSync currently receive security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.6.x   | :white_check_mark: |
| 1.5.x   | :white_check_mark: |
| < 1.5.0 | :x:                |

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
- **Teacher AI Keys**: User-provided AI keys are stored in platform secure storage on the teacher's device, scoped to their account, and are not synced to student devices or Firestore. AI requests go directly from the app to the selected provider; use provider-side key restrictions and spending limits.
- **Client Configuration Files**: `google-services.json` contains public client IDs and client-side identifiers for mobile apps. Ensure API key restrictions are applied in Google Cloud Console.
- **Firestore Security Rules**: All database requests must be authenticated and validated against `firestore.rules`. User email addresses and onboarding details are stored in the owner-only `users/{uid}/private/profile` document. Student submissions are readable only by their owner and the teacher who owns the activity; announcement writes require ownership of the associated class. Shared `/config` access requires the `edusync_role: teacher` custom claim. Deploy the updated Firestore rules before using profile onboarding. Firebase claims are synchronized by the Supabase Edge Function in [`supabase/functions/sync-user-claims/`](./supabase/functions/sync-user-claims/); anyone may select Teacher at registration, as intended for this app.
- **Protected Activity Files**: New activity attachments and student submissions use Supabase. Existing Firebase Storage attachments still require the matching deployed Firebase Storage rules; legacy download-token URLs remain downloadable and are not retroactively protected. View-only limits normal app download controls but cannot prevent extraction from a modified client or external capture.
- **Supabase Activity Files**: Activity attachments and student submissions use the private `activity-documents` Supabase bucket. The app uses Firebase ID tokens and only the Supabase URL plus publishable key; never put the Supabase secret/service-role key in the app. The Firebase service account is kept in Supabase server-side secrets (`FIREBASE_SERVICE_ACCOUNT`) and is never placed in the client app. The URL and publishable key have client-safe defaults in the app and can be overridden with Dart defines. Apply [`supabase/storage-policies.sql`](./supabase/storage-policies.sql) once. Firebase claims (`role: authenticated`, `edusync_role: teacher` or `student`, and `class_ids`) are synchronized by the Supabase Edge Function in [`supabase/functions/sync-user-claims/`](./supabase/functions/sync-user-claims/). Upload/download access is enforced by Supabase Storage policies; view-only prevents normal app download controls, not capture or extraction from a modified client.
- **Activity Monitoring Limits**: Android screenshot blocking and app-background event counts are best-effort client controls. They cannot prevent app switching, identify the other app, or detect all exits; unmanaged devices and other platforms may not block screenshots. Activity timers are client-side and are not tamper-proof or enforced by the server.
- **Teacher Answer Keys**: New answer keys are stored in the teacher-only `activities/{activityId}/teacher_private/answer_key` document. Existing root-level answer keys are moved by the teacher app on sync; migrate them before relying on confidentiality for previously created activities.
