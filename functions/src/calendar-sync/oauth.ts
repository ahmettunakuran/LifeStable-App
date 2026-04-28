import { randomBytes } from "crypto";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { https } from "firebase-functions/v1";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { getGoogleCalendarConfig } from "./config";

const db = admin.firestore();

function accountRef(uid: string) {
  return db.collection("users").doc(uid).collection("external_accounts").doc("google");
}

function credentialsRef(uid: string) {
  return db.collection("users").doc(uid).collection("external_credentials").doc("google");
}

function oauthStateRef(uid: string) {
  return db.collection("users").doc(uid).collection("oauth_states").doc("google");
}

function encodeState(payload: { uid: string; nonce: string }): string {
  return Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
}

function decodeState(raw: string): { uid: string; nonce: string } | null {
  try {
    const json = Buffer.from(raw, "base64url").toString("utf8");
    return JSON.parse(json) as { uid: string; nonce: string };
  } catch (_) {
    return null;
  }
}

function successHtml(email: string): string {
  return `
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>LifeStable</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            background: #111;
            color: #f5f5f5;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
          }
          .card {
            width: 92%;
            max-width: 460px;
            padding: 28px;
            border-radius: 16px;
            background: #1c1c1c;
            border: 1px solid #333;
            text-align: center;
          }
          h1 { margin-top: 0; color: #d4af37; }
          p { color: #ddd; line-height: 1.5; }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>Google Calendar connected</h1>
          <p><strong>${email}</strong> is now connected to LifeStable.</p>
          <p>You can close this page and return to the app.</p>
        </div>
      </body>
    </html>
  `;
}

function errorHtml(message: string): string {
  return `
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>LifeStable</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            background: #111;
            color: #f5f5f5;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
          }
          .card {
            width: 92%;
            max-width: 460px;
            padding: 28px;
            border-radius: 16px;
            background: #1c1c1c;
            border: 1px solid #333;
            text-align: center;
          }
          h1 { margin-top: 0; color: #ff6b6b; }
          p { color: #ddd; line-height: 1.5; }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>Connection failed</h1>
          <p>${message}</p>
        </div>
      </body>
    </html>
  `;
}

type TokenResponse = {
  access_token: string;
  expires_in: number;
  refresh_token?: string;
  scope?: string;
  token_type?: string;
};

export const initiateGoogleCalendarAuth = https.onCall(async (_data, context) => {
  const googleCalendarConfig = getGoogleCalendarConfig();

  if (!context.auth) {
    throw new https.HttpsError("unauthenticated", "Sign in first.");
  }

  const uid = context.auth.uid;
  const nonce = randomBytes(24).toString("hex");

  await oauthStateRef(uid).set({
    nonce,
    used: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const state = encodeState({ uid, nonce });

  const url = new URL(googleCalendarConfig.authBaseUrl);
  url.searchParams.set("client_id", googleCalendarConfig.clientId);
  url.searchParams.set("redirect_uri", googleCalendarConfig.redirectUri);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("access_type", "offline");
  url.searchParams.set("include_granted_scopes", "true");
  url.searchParams.set("prompt", "consent");
  url.searchParams.set("scope", googleCalendarConfig.scope);
  url.searchParams.set("state", state);

  return { authUrl: url.toString() };
});

export const googleCalendarOAuthCallback = https.onRequest(async (req, res) => {
  const googleCalendarConfig = getGoogleCalendarConfig();

  try {
    const error = req.query.error as string | undefined;
    if (error) {
      res.status(400).send(errorHtml(`Google returned: ${error}`));
      return;
    }

    const code = req.query.code as string | undefined;
    const stateRaw = req.query.state as string | undefined;

    if (!code || !stateRaw) {
      res.status(400).send(errorHtml("Missing code or state."));
      return;
    }

    const decoded = decodeState(stateRaw);
    if (!decoded) {
      res.status(400).send(errorHtml("Invalid state."));
      return;
    }

    const { uid, nonce } = decoded;

    const stateDoc = await oauthStateRef(uid).get();
    if (!stateDoc.exists) {
      res.status(400).send(errorHtml("OAuth state not found."));
      return;
    }

    const stateData = stateDoc.data() as { nonce?: string; used?: boolean };
    if (stateData.nonce !== nonce || stateData.used === true) {
      res.status(400).send(errorHtml("OAuth state mismatch."));
      return;
    }

    const tokenResponse = await fetch(googleCalendarConfig.tokenUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        client_id: googleCalendarConfig.clientId,
        client_secret: googleCalendarConfig.clientSecret,
        code,
        grant_type: "authorization_code",
        redirect_uri: googleCalendarConfig.redirectUri,
      }),
    });

    if (!tokenResponse.ok) {
      const text = await tokenResponse.text();
      logger.error("Google token exchange failed", text);
      res.status(500).send(errorHtml("Token exchange failed."));
      return;
    }

    const tokenJson = await tokenResponse.json() as TokenResponse;

    const existingCreds = await credentialsRef(uid).get();
    const existingRefreshToken =
      existingCreds.exists ? (existingCreds.data()?.refreshToken as string | undefined) : undefined;

    const accessToken = tokenJson.access_token;
    const refreshToken = tokenJson.refresh_token ?? existingRefreshToken ?? null;

    let providerUserId = "Google account";
    try {
      const userInfoResp = await fetch(googleCalendarConfig.userInfoUrl, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      if (userInfoResp.ok) {
        const userInfo = await userInfoResp.json() as { email?: string };
        providerUserId = userInfo.email ?? providerUserId;
      }
    } catch (_) {
      // keep fallback
    }

    await credentialsRef(uid).set({
      accessToken,
      refreshToken,
      tokenType: tokenJson.token_type ?? "Bearer",
      scope: tokenJson.scope ?? googleCalendarConfig.scope,
      expiresAt: Timestamp.fromMillis(
        Date.now() + (tokenJson.expires_in ?? 3600) * 1000,
      ),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    await accountRef(uid).set({
      provider: "google",
      providerUserId,
      connectedAt: FieldValue.serverTimestamp(),
      lastSyncAt: null,
    }, { merge: true });

    await oauthStateRef(uid).set({
      used: true,
      usedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    res.status(200).send(successHtml(providerUserId));
  } catch (error) {
    logger.error("googleCalendarOAuthCallback failed", error);
    res.status(500).send(errorHtml("Unexpected server error."));
  }
});

export const disconnectGoogleCalendar = https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new https.HttpsError("unauthenticated", "Sign in first.");
  }

  const uid = context.auth.uid;

  const mapSnap = await db
    .collection("users")
    .doc(uid)
    .collection("external_event_map")
    .where("provider", "==", "google")
    .get();

  const batch = db.batch();

  batch.delete(accountRef(uid));
  batch.delete(credentialsRef(uid));
  batch.delete(oauthStateRef(uid));

  for (const doc of mapSnap.docs) {
    batch.delete(doc.ref);
  }

  await batch.commit();

  return { success: true };
});