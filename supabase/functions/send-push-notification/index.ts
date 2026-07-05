// send-push-notification — broadcasts a push notification to every device
// with notifications enabled, via Firebase Cloud Messaging (FCM HTTP v1).
//
// Body: { "title": string, "body": string, "data"?: Record<string, string> }
//
// Intended to be called by a scheduled job (pg_cron) or manually, e.g. for
// market fluctuation alerts. Protected by a shared secret header so it can't
// be triggered by anyone (see supabase/README.md for the actual alert logic
// / schedule, which is wired up separately from this generic sender).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleOptions, json } from "../_shared/cors.ts";

const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID")!;
const FCM_SERVICE_ACCOUNT = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!);

function base64url(bytes: ArrayBuffer | string): string {
  const raw = typeof bytes === "string"
    ? bytes
    : String.fromCharCode(...new Uint8Array(bytes));
  return btoa(raw).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

// Self-signed OAuth2 JWT for the service account (standard Google
// server-to-server flow), exchanged for an access token below.
async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: FCM_SERVICE_ACCOUNT.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claim))}`;

  const pem = FCM_SERVICE_ACCOUNT.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tokenData = await res.json();
  if (!tokenData.access_token) {
    throw new Error(`OAuth token exchange failed: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  const expected = Deno.env.get("PUSH_SECRET");
  if (expected && req.headers.get("x-push-secret") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  const { title, body, data } = await req.json().catch(() => ({}));
  if (!title || !body) {
    return json({ error: "title and body are required" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const { data: tokens, error } = await supabase
      .from("device_tokens")
      .select("device_id, fcm_token")
      .eq("notifications_enabled", true);
    if (error) throw error;

    const accessToken = await getAccessToken();
    const staleDeviceIds: string[] = [];
    let sent = 0;

    // ponytail: sequential sends, fine at current device counts. Batch with
    // Promise.all(chunks) if the audience grows large enough to be slow.
    for (const row of tokens ?? []) {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: row.fcm_token,
              notification: { title, body },
              data: data ?? {},
              apns: { payload: { aps: { sound: "default" } } },
            },
          }),
        },
      );

      if (res.ok) {
        sent++;
      } else {
        const errBody = await res.json().catch(() => ({}));
        if (errBody?.error?.status === "UNREGISTERED" || errBody?.error?.status === "NOT_FOUND") {
          staleDeviceIds.push(row.device_id);
        }
      }
    }

    if (staleDeviceIds.length > 0) {
      await supabase.from("device_tokens").delete().in("device_id", staleDeviceIds);
    }

    return json({ sent, total: tokens?.length ?? 0, removed_stale: staleDeviceIds.length });
  } catch (err) {
    console.error("send-push-notification error:", err);
    return json({ error: String(err) }, 500);
  }
});
