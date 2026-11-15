// Supabase Edge Function: sync-user-claims
// Synchronizes EduSync Firebase custom user claims with Firestore user profiles and class rosters.
//
// Firebase credentials (service account) are retrieved securely from Supabase server-side secrets:
// Deno.env.get("FIREBASE_SERVICE_ACCOUNT")
// Never put the service account or private key in the client application.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const VALID_ROLES = new Set(["teacher", "student"]);
const MAX_CUSTOM_CLAIMS_BYTES = 1000;

interface FirebaseServiceAccount {
  type?: string;
  project_id: string;
  private_key_id?: string;
  private_key: string;
  client_email: string;
  client_id?: string;
  auth_uri?: string;
  token_uri?: string;
  auth_provider_x509_cert_url?: string;
  client_x509_cert_url?: string;
}

function getServiceAccount(): FirebaseServiceAccount {
  const raw =
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ||
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY") ||
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ||
    Deno.env.get("FIREBASE_CONFIG");

  if (raw) {
    let trimmed = raw.trim();
    if (!trimmed.startsWith("{") && !trimmed.startsWith("[")) {
      try {
        trimmed = atob(trimmed);
      } catch (_) {
        // use raw if not base64
      }
    }
    try {
      const parsed = JSON.parse(trimmed);
      if (parsed.project_id && parsed.client_email && parsed.private_key) {
        return {
          ...parsed,
          private_key: parsed.private_key.replace(/\\n/g, "\n"),
        };
      }
    } catch (err) {
      throw new Error(`Failed to parse FIREBASE_SERVICE_ACCOUNT secret: ${err}`);
    }
  }

  // Fallback to separate environment variables
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

  if (projectId && clientEmail && privateKey) {
    return {
      project_id: projectId,
      client_email: clientEmail,
      private_key: privateKey.replace(/\\n/g, "\n"),
      token_uri: "https://oauth2.googleapis.com/token",
    };
  }

  throw new Error(
    "Missing Firebase service account secret. Set FIREBASE_SERVICE_ACCOUNT in Supabase secrets."
  );
}

function base64UrlEncode(data: Uint8Array | string): string {
  let bytes: Uint8Array;
  if (typeof data === "string") {
    bytes = new TextEncoder().encode(data);
  } else {
    bytes = data;
  }
  let binary = "";
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function pemToBinary(pem: string): Uint8Array {
  const clean = pem
    .replace(/-----BEGIN [A-Z ]+-----/g, "")
    .replace(/-----END [A-Z ]+-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function signRs256Jwt(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  privateKeyPem: string
): Promise<string> {
  const enc = new TextEncoder();
  const headerB64 = base64UrlEncode(JSON.stringify(header));
  const payloadB64 = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${headerB64}.${payloadB64}`;

  const keyBytes = pemToBinary(privateKeyPem);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    enc.encode(unsignedToken)
  );

  const signatureB64 = base64UrlEncode(new Uint8Array(signature));
  return `${unsignedToken}.${signatureB64}`;
}

let cachedToken: { accessToken: string; expiresAt: number } | null = null;

async function getGoogleAccessToken(sa: FirebaseServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.accessToken;
  }

  const tokenUri = sa.token_uri || "https://oauth2.googleapis.com/token";
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
    scope: [
      "https://www.googleapis.com/auth/identitytoolkit",
      "https://www.googleapis.com/auth/datastore",
      "https://www.googleapis.com/auth/cloud-platform",
    ].join(" "),
  };

  const jwt = await signRs256Jwt(header, payload, sa.private_key);

  const res = await fetch(tokenUri, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(
      `Google OAuth2 token exchange failed (${res.status}): ${errorText}`
    );
  }

  const tokenData = await res.json();
  const accessToken = tokenData.access_token;
  const expiresIn = tokenData.expires_in || 3600;

  cachedToken = {
    accessToken,
    expiresAt: now + expiresIn,
  };

  return accessToken;
}

// ---------------------------------------------------------------------------
// Firestore REST API
// ---------------------------------------------------------------------------

async function getUserProfile(
  projectId: string,
  token: string,
  uid: string
): Promise<{ role?: string } | null> {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${encodeURIComponent(
    uid
  )}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore getUserProfile failed (${res.status}): ${err}`);
  }
  const data = await res.json();
  return {
    role: data.fields?.role?.stringValue,
  };
}

async function getClassesForTeacher(
  projectId: string,
  token: string,
  uid: string
): Promise<string[]> {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "classes" }],
        where: {
          fieldFilter: {
            field: { fieldPath: "teacherId" },
            op: "EQUAL",
            value: { stringValue: uid },
          },
        },
      },
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(
      `Firestore getClassesForTeacher failed (${res.status}): ${err}`
    );
  }
  const items = await res.json();
  const classIds: string[] = [];
  if (Array.isArray(items)) {
    for (const item of items) {
      if (item.document?.name) {
        const parts = item.document.name.split("/");
        classIds.push(parts[parts.length - 1]);
      }
    }
  }
  return classIds;
}

async function getClassesForStudent(
  projectId: string,
  token: string,
  uid: string
): Promise<string[]> {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "classes" }],
        where: {
          fieldFilter: {
            field: { fieldPath: "studentIds" },
            op: "ARRAY_CONTAINS",
            value: { stringValue: uid },
          },
        },
      },
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(
      `Firestore getClassesForStudent failed (${res.status}): ${err}`
    );
  }
  const items = await res.json();
  const classIds: string[] = [];
  if (Array.isArray(items)) {
    for (const item of items) {
      if (item.document?.name) {
        const parts = item.document.name.split("/");
        classIds.push(parts[parts.length - 1]);
      }
    }
  }
  return classIds;
}

async function getClassMembers(
  projectId: string,
  token: string,
  classId: string
): Promise<string[]> {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/classes/${encodeURIComponent(
    classId
  )}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return [];
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore getClassMembers failed (${res.status}): ${err}`);
  }
  const data = await res.json();
  const fields = data.fields || {};
  const teacherId = fields.teacherId?.stringValue;
  const studentValues = fields.studentIds?.arrayValue?.values || [];
  const studentIds: string[] = studentValues
    .map((v: { stringValue?: string }) => v.stringValue)
    .filter((s: unknown): s is string => typeof s === "string" && s.length > 0);

  const uids = new Set<string>();
  if (teacherId) uids.add(teacherId);
  for (const s of studentIds) uids.add(s);
  return [...uids];
}

// ---------------------------------------------------------------------------
// Firebase Auth (Identity Toolkit) REST API
// ---------------------------------------------------------------------------

async function getFirebaseAuthUser(
  projectId: string,
  token: string,
  uid: string
): Promise<{ localId: string; customAttributes?: string } | null> {
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ localId: [uid] }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(
      `IdentityToolkit accounts:lookup failed (${res.status}): ${err}`
    );
  }
  const data = await res.json();
  if (!data.users || data.users.length === 0) {
    return null;
  }
  return data.users[0];
}

async function setFirebaseAuthCustomClaims(
  projectId: string,
  token: string,
  uid: string,
  claims: Record<string, unknown>
): Promise<void> {
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:update`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      localId: uid,
      customAttributes: JSON.stringify(claims),
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(
      `IdentityToolkit accounts:update failed (${res.status}): ${err}`
    );
  }
}

// ---------------------------------------------------------------------------
// Claim Synchronization Core
// ---------------------------------------------------------------------------

async function syncClaimsForUser(
  projectId: string,
  token: string,
  uid: string
): Promise<{
  uid: string;
  updated: boolean;
  skipped?: boolean;
  reason?: string;
  role?: string | null;
  classIds?: string[];
}> {
  const authUser = await getFirebaseAuthUser(projectId, token, uid);
  if (!authUser) {
    console.warn(`User ${uid} not found in Firebase Auth; skipping.`);
    return { uid, updated: false, skipped: true, reason: "user-not-found" };
  }

  const [profile, taughtClasses, enrolledClasses] = await Promise.all([
    getUserProfile(projectId, token, uid),
    getClassesForTeacher(projectId, token, uid),
    getClassesForStudent(projectId, token, uid),
  ]);

  let existingClaims: Record<string, unknown> = {};
  if (authUser.customAttributes) {
    try {
      existingClaims = JSON.parse(authUser.customAttributes);
    } catch (_) {
      existingClaims = {};
    }
  }

  const nextClaims: Record<string, unknown> = {
    ...existingClaims,
    role: "authenticated",
  };

  const appRole = profile?.role ?? null;

  if (appRole && VALID_ROLES.has(appRole)) {
    const classIdSet = new Set<string>();
    const matchingClasses =
      appRole === "teacher" ? taughtClasses : enrolledClasses;
    for (const cid of matchingClasses) {
      classIdSet.add(cid);
    }

    nextClaims.edusync_role = appRole;
    nextClaims.class_ids = [...classIdSet].sort();
  } else {
    delete nextClaims.edusync_role;
    delete nextClaims.class_ids;
  }

  const claimsJson = JSON.stringify(nextClaims);
  const claimsBytes = new TextEncoder().encode(claimsJson).length;
  if (claimsBytes > MAX_CUSTOM_CLAIMS_BYTES) {
    throw new Error(
      `Custom claims for Firebase user ${uid} exceed the ${MAX_CUSTOM_CLAIMS_BYTES}-byte limit (${claimsBytes} bytes).`
    );
  }

  const existingJson = JSON.stringify(existingClaims);
  const changed = existingJson !== claimsJson;

  if (changed) {
    await setFirebaseAuthCustomClaims(projectId, token, uid, nextClaims);
    console.log("Synchronized EduSync Firebase claims", {
      uid,
      role: nextClaims.edusync_role || null,
      classCount: Array.isArray(nextClaims.class_ids)
        ? nextClaims.class_ids.length
        : 0,
    });
  }

  return {
    uid,
    updated: changed,
    role: (nextClaims.edusync_role as string) || null,
    classIds: (nextClaims.class_ids as string[]) || [],
  };
}

function getUidFromAuthHeader(req: Request): string | null {
  const authHeader =
    req.headers.get("authorization") || req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.substring(7).trim();
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payloadStr = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"));
    const payload = JSON.parse(payloadStr);
    return payload.user_id || payload.sub || payload.uid || null;
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// HTTP Server / Entry Point
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const sa = getServiceAccount();
    const googleToken = await getGoogleAccessToken(sa);
    const projectId = sa.project_id;

    let body: {
      userId?: string;
      userIds?: string[];
      classId?: string;
    } = {};

    if (req.method === "POST") {
      try {
        body = await req.json();
      } catch (_) {
        body = {};
      }
    }

    const targetUids = new Set<string>();

    if (body.userId && typeof body.userId === "string") {
      targetUids.add(body.userId.trim());
    }
    if (Array.isArray(body.userIds)) {
      for (const id of body.userIds) {
        if (typeof id === "string" && id.trim()) {
          targetUids.add(id.trim());
        }
      }
    }
    if (body.classId && typeof body.classId === "string") {
      const classMembers = await getClassMembers(
        projectId,
        googleToken,
        body.classId.trim()
      );
      for (const id of classMembers) {
        targetUids.add(id);
      }
    }

    // Fallback to caller UID from Authorization token if no explicit UIDs provided
    if (targetUids.size === 0) {
      const callerUid = getUidFromAuthHeader(req);
      if (callerUid) {
        targetUids.add(callerUid);
      }
    }

    if (targetUids.size === 0) {
      return new Response(
        JSON.stringify({
          error:
            "No user specified. Provide userId, userIds, classId, or an Authorization header.",
        }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    const results = await Promise.all(
      [...targetUids].map((uid) =>
        syncClaimsForUser(projectId, googleToken, uid)
      )
    );

    return new Response(
      JSON.stringify({
        success: true,
        count: results.length,
        results,
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    console.error("sync-user-claims error:", error);
    return new Response(
      JSON.stringify({ error: error?.message || String(error) }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }
});
