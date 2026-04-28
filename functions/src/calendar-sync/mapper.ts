export interface GoogleCalendarEvent {
  id: string;
  summary?: string;
  description?: string;
  status?: string;
  recurrence?: string[];
  colorId?: string;
  start?: {
    dateTime?: string;
    date?: string;
    timeZone?: string;
  };
  end?: {
    dateTime?: string;
    date?: string;
    timeZone?: string;
  };
}

export interface InternalCalendarEventData {
  userId: string;
  title: string;
  description: string;
  startAt: string;
  endAt: string;
  eventType: string;
  isRecurring: boolean;
  externalEventId?: string;
  syncProvider?: string;
  colorHex?: string;
  assignedMemberIds: string[];
}

function allDayStartIso(date: string): string {
  return new Date(`${date}T00:00:00.000Z`).toISOString();
}

function allDayEndIsoExclusiveToInclusive(date: string): string {
  const endExclusive = new Date(`${date}T00:00:00.000Z`);
  return new Date(endExclusive.getTime() - 1).toISOString();
}

export function googleColorIdToHex(colorId?: string): string | undefined {
  if (!colorId) return undefined;

  const map: Record<string, string> = {
    "1": "#7986CB",
    "2": "#33B679",
    "3": "#8E24AA",
    "4": "#E67C73",
    "5": "#F6BF26",
    "6": "#F4511E",
    "7": "#039BE5",
    "8": "#616161",
    "9": "#3F51B5",
    "10": "#0B8043",
    "11": "#D50000",
  };

  return map[colorId];
}

export function googleEventToInternal(
  event: GoogleCalendarEvent,
  userId: string,
): InternalCalendarEventData | null {
  if (!event.id) return null;
  if (event.status === "cancelled") return null;

  let startAt: string | null = null;
  let endAt: string | null = null;

  if (event.start?.dateTime && event.end?.dateTime) {
    startAt = new Date(event.start.dateTime).toISOString();
    endAt = new Date(event.end.dateTime).toISOString();
  } else if (event.start?.date && event.end?.date) {
    startAt = allDayStartIso(event.start.date);
    endAt = allDayEndIsoExclusiveToInclusive(event.end.date);
  }

  if (!startAt || !endAt) return null;

  return {
    userId,
    title: event.summary ?? "(No Title)",
    description: event.description ?? "",
    startAt,
    endAt,
    eventType: "personal",
    isRecurring: Array.isArray(event.recurrence) && event.recurrence.length > 0,
    externalEventId: event.id,
    syncProvider: "google",
    colorHex: googleColorIdToHex(event.colorId),
    assignedMemberIds: [],
  };
}