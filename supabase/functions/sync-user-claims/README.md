# EduSync Supabase Claim Synchronization Edge Function

This Supabase Edge Function (`sync-user-claims`) synchronizes Firebase Auth custom claims with EduSync's Firestore user profiles and class rosters:

- Sets `role: "authenticated"` for Supabase RLS and storage authorization.
- Sets `edusync_role` to `"teacher"` or `"student"` from `users/{uid}`.
- Sets `class_ids` to the sorted array of class IDs where the user is a teacher or enrolled student.
- Removes `edusync_role` and `class_ids` if the profile has no valid role.

## Security & Secrets

**Service Account Security**: The Firebase service account key is stored **server-side only** in Supabase project secrets (`FIREBASE_SERVICE_ACCOUNT`). It is **never** embedded in or accessible to the mobile application.

### Setting the Secret in Supabase

Upload the Firebase Service Account JSON to Supabase secrets using the Supabase CLI:

```bash
# Upload service account JSON key:
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat /path/to/serviceAccountKey.json)"
```

Alternatively, set the value in your Supabase Project Dashboard under **Project Settings -> Edge Functions -> Secrets**.

## Deploying the Function

Deploy the function to your Supabase project:

```bash
supabase functions deploy sync-user-claims --no-verify-jwt
```

> **Note**: `--no-verify-jwt` allows the Edge Function to receive requests authenticated with Firebase ID tokens from the EduSync mobile app.

## Invocation

The mobile app calls this function automatically when:
1. A user profile is created or updated (`userId: "<uid>"`).
2. A teacher creates, updates, or deletes a class (`classId: "<classId>"` or `userIds: [...]`).
3. A student is added to or removed from a class roster (`userId: "<studentId>"`, `classId: "<classId>"`).

Payload format:

```json
{
  "userId": "string (optional)",
  "userIds": ["string (optional)"],
  "classId": "string (optional)"
}
```
