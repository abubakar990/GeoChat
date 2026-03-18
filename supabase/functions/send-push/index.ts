// supabase/functions/send-push/index.ts
// Deploy with: supabase functions deploy send-push
//
// Required env vars (set in Supabase Dashboard → Edge Functions → Secrets):
//   FIREBASE_PROJECT_ID   — your Firebase project ID (e.g. "geochat-12345")
//   FIREBASE_SERVICE_ACCOUNT_JSON — the full service account JSON as a string

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// ─── Google OAuth2 token (service account → access token) ────────────────────
async function getAccessToken(serviceAccountJson: string): Promise<string> {
    const sa = JSON.parse(serviceAccountJson);
    const now = Math.floor(Date.now() / 1000);

    const header = { alg: "RS256", typ: "JWT" };
    const payload = {
        iss: sa.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
    };

    const encode = (obj: object) =>
        btoa(JSON.stringify(obj))
            .replace(/\+/g, "-")
            .replace(/\//g, "_")
            .replace(/=/g, "");

    const unsigned = `${encode(header)}.${encode(payload)}`;

    // Import the private key
    const privateKeyPem = sa.private_key as string;
    const pemBody = privateKeyPem
        .replace("-----BEGIN PRIVATE KEY-----", "")
        .replace("-----END PRIVATE KEY-----", "")
        .replace(/\n/g, "");
    const keyBuffer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

    const key = await crypto.subtle.importKey(
        "pkcs8",
        keyBuffer,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
    );

    const signature = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        new TextEncoder().encode(unsigned)
    );

    const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=/g, "");

    const jwt = `${unsigned}.${sigB64}`;

    // Exchange JWT for access token
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion: jwt,
        }),
    });

    const tokenJson = await tokenRes.json();
    if (!tokenRes.ok) {
        throw new Error(`Token exchange failed: ${JSON.stringify(tokenJson)}`);
    }
    return tokenJson.access_token as string;
}

// ─── Main handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
    // CORS preflight
    if (req.method === "OPTIONS") {
        return new Response(null, {
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "authorization, content-type",
            },
        });
    }

    try {
        const { token, title, body, data } = await req.json();

        if (!token || !title) {
            return new Response(JSON.stringify({ error: "token and title required" }), {
                status: 400,
            });
        }

        const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
        const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");

        if (!projectId || !saJson) {
            return new Response(
                JSON.stringify({ error: "Firebase env vars not set" }),
                { status: 500 }
            );
        }

        const accessToken = await getAccessToken(saJson);

        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

        const message = {
            message: {
                token,
                notification: { title, body: body ?? "" },
                data: data
                    ? Object.fromEntries(
                        Object.entries(data).map(([k, v]) => [k, String(v)])
                    )
                    : {},
                android: {
                    priority: "HIGH",
                    notification: {
                        channel_id: data?.type === "new_message"
                            ? "geochat_messages"
                            : data?.type?.startsWith("friend")
                                ? "geochat_friends"
                                : "geochat_general",
                        sound: "default",
                    },
                },
            },
        };

        const fcmRes = await fetch(fcmUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(message),
        });

        const fcmJson = await fcmRes.json();

        if (!fcmRes.ok) {
            console.error("FCM error:", fcmJson);
            return new Response(JSON.stringify({ error: fcmJson }), { status: 500 });
        }

        return new Response(JSON.stringify({ success: true, result: fcmJson }), {
            headers: { "Content-Type": "application/json" },
        });
    } catch (err) {
        console.error("Edge function error:", err);
        return new Response(JSON.stringify({ error: String(err) }), {
            status: 500,
        });
    }
});
