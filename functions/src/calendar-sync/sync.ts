import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { https } from "firebase-functions/v1";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { getGoogleCalendarConfig } from "./config";
import {
  GoogleCalendarEvent,
  googleEventToInternal,
} from "./mapper";

const db = admin.firestore();

function accountRef(uid: string) {
  return db.collection("users").doc(uid).collection("external_accounts").doc("google");
}

function credentialsRef(uid: string) {
  return db.collection("users").doc(uid).collection("external_credentials").doc("google");
}

function eventsCol(uid: string) {
  return db.collection("users").doc(uid).collection("calendar_events");
}

function mapCol(uid: string) {
  return db.collection("users").doc(uid).collection("external_event_map");
}

function mapDocId(externalEventId: string): string {
  return `google_${Buffer.from(externalEventId, "utf8").toString("base64url")}`;
}

function removeUndefinedFields<T extends Record<string, unknown>>(obj: T): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(obj).filter(([, value]) => value !== undefined),
  );
}

type RefreshResponse = {
  access_token: string;
  expires_in: number;
  scope?: string;
  token_type?: string;
};

async function refreshGoogleAccessToken(uid: string): Promise<string> {
  const googleCalendarConfig = getGoogleCalendarConfig();

  const credsDoc = await credentialsRef(uid).get();

  if (!credsDoc.exists) {
    throw new https.HttpsError("failed-precondition", "Google Calendar is not connected.");
  }

  const data = credsDoc.data() as {
    accessToken?: string;
    refreshToken?: string;
    expiresAt?: Timestamp;
  };

  const currentAccessToken = data.accessToken;
  const refreshToken = data.refreshToken;
  const expiresAtMillis = data.expiresAt?.toMillis() ?? 0;

  if (currentAccessToken && expiresAtMillis > Date.now() + 5 * 60 * 1000) {
    return currentAccessToken;
  }

  if (!refreshToken) {
    throw new https.HttpsError("unauthenticated", "Missing refresh token. Reconnect Google Calendar.");
  }

  const refreshResp = await fetch(googleCalendarConfig.tokenUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      client_id: googleCalendarConfig.clientId,
      client_secret: googleCalendarConfig.clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });

  if (!refreshResp.ok) {
    const text = await refreshResp.text();
    logger.error("Google token refresh failed", text);
    throw new https.HttpsError("unauthenticated", "Failed to refresh Google token.");
  }

  const json = await refreshResp.json() as RefreshResponse;

  await credentialsRef(uid).set({
    accessToken: json.access_token,
    tokenType: json.token_type ?? "Bearer",
    scope: json.scope ?? googleCalendarConfig.scope,
    expiresAt: Timestamp.fromMillis(
      Date.now() + (json.expires_in ?? 3600) * 1000,
    ),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return json.access_token;
}

async function fetchGoogleEvents(
  accessToken: string,
  timeMin: string,
  timeMax: string,
): Promise<GoogleCalendarEvent[]> {
  const googleCalendarConfig = getGoogleCalendarConfig();

  const allEvents: GoogleCalendarEvent[] = [];
  let nextPageToken: string | undefined;

  do {
    const url = new URL(
      `${googleCalendarConfig.calendarBaseUrl}/calendars/primary/events`,
    );

    url.searchParams.set("singleEvents", "true");
    url.searchParams.set("showDeleted", "true");
    url.searchParams.set("maxResults", "250");
    url.searchParams.set("timeMin", timeMin);
    url.searchParams.set("timeMax", timeMax);

    if (nextPageToken) {
      url.searchParams.set("pageToken", nextPageToken);
    }

    const resp = await fetch(url.toString(), {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!resp.ok) {
      const text = await resp.text();
      logger.error("Google Calendar fetch failed", text);
      throw new https.HttpsError("internal", "Failed to fetch Google Calendar events.");
    }

    const json = await resp.json() as {
      items?: GoogleCalendarEvent[];
      nextPageToken?: string;
    };

    allEvents.push(...(json.items ?? []));
    nextPageToken = json.nextPageToken;
  } while (nextPageToken);

  return allEvents;
}

export const syncGoogleCalendar = https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new https.HttpsError("unauthenticated", "Sign in first.");
  }

  const uid = context.auth.uid;

  const now = new Date();
  const timeMin = typeof data?.timeMin === "string"
    ? data.timeMin
    : new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

  const timeMax = typeof data?.timeMax === "string"
    ? data.timeMax
    : new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000).toISOString();

  const accessToken = await refreshGoogleAccessToken(uid);
  const externalEvents = await fetchGoogleEvents(accessToken, timeMin, timeMax);

  let created = 0;
  let updated = 0;
  let deleted = 0;

  for (const externalEvent of externalEvents) {
    if (!externalEvent.id) continue;

    const mappingRef = mapCol(uid).doc(mapDocId(externalEvent.id));

    if (externalEvent.status === "cancelled") {
      const existingMap = await mappingRef.get();

      if (existingMap.exists) {
        const internalEventId = existingMap.data()?.internalEventId as string | undefined;

        if (internalEventId) {
          await eventsCol(uid).doc(internalEventId).delete().catch(() => undefined);
        }

        await mappingRef.delete().catch(() => undefined);
        deleted++;
      }

      continue;
    }

    const internalData = googleEventToInternal(externalEvent, uid);
    if (!internalData) continue;

    if (!externalEvent.id) continue;

    const existingMap = await mappingRef.get();

    if (!existingMap.exists) {
      const newEventRef = eventsCol(uid).doc();

      const eventDoc = removeUndefinedFields({
        ...internalData,
        externalEventId: externalEvent.id,
        syncProvider: "google",
      });

      await newEventRef.set(eventDoc);

      await mappingRef.set({
        provider: "google",
        externalEventId: externalEvent.id,
        internalEventId: newEventRef.id,
        lastSyncedAt: FieldValue.serverTimestamp(),
      });

      created++;
    } else {
      const internalEventId = existingMap.data()?.internalEventId as string | undefined;

      if (internalEventId) {
        const eventDoc = removeUndefinedFields({
          ...internalData,
          externalEventId: externalEvent.id,
          syncProvider: "google",
        });

        await eventsCol(uid).doc(internalEventId).set(eventDoc, { merge: true });

        await mappingRef.set({
          lastSyncedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        updated++;
      }
    }
  }

  await accountRef(uid).set({
    lastSyncAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    created,
    updated,
    deleted,
    totalFetched: externalEvents.length,
  };
});