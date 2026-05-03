export interface FaqChunk {
  title_type: string;
  doc_type: string;
  source_key: string;
  content: string;
  indexes: string[];
}

export const faqChunks: FaqChunk[] = [
  // ── DOMAINS ──────────────────────────────────────────────────────────────
  {
    title_type: "domain_create",
    doc_type: "faq",
    source_key: "domain_management",
    content:
      "How do I create a new domain? Tap the + button on the Home Dashboard, " +
      "enter a name, pick an icon and color, then tap Save. Domains are " +
      "personal workspaces that group your tasks and notes (e.g. \"University\", " +
      "\"Part-time Job\", \"Personal\").",
    indexes: ["domain", "create", "add", "workspace", "new", "how"],
  },
  {
    title_type: "domain_edit",
    doc_type: "faq",
    source_key: "domain_management",
    content:
      "How do I edit or rename a domain? Long-press the domain card on the " +
      "Dashboard, then tap Edit. You can change the name, icon, color, and " +
      "description. Team mirror domains cannot be edited directly.",
    indexes: ["domain", "edit", "rename", "update", "change", "how"],
  },
  {
    title_type: "domain_delete",
    doc_type: "faq",
    source_key: "domain_management",
    content:
      "How do I delete a domain? Long-press the domain card, tap Delete, and " +
      "confirm. Deleting a domain removes all tasks and notes inside it. " +
      "Team mirror domains are removed automatically when you leave the team.",
    indexes: ["domain", "delete", "remove", "how"],
  },
  {
    title_type: "domain_team_mirror",
    doc_type: "faq",
    source_key: "domain_management",
    content:
      "What is a team mirror domain? When you join or create a team, " +
      "LifeStable automatically creates a domain named after the team so " +
      "team tasks and calendar events appear in your personal view. " +
      "This mirror domain syncs with the team board in real time.",
    indexes: ["domain", "team", "mirror", "sync", "what"],
  },

  // ── TASKS ─────────────────────────────────────────────────────────────────
  {
    title_type: "task_create",
    doc_type: "faq",
    source_key: "task_creation",
    content:
      "How do I create a task? Open a domain, tap the + button, fill in the " +
      "title, optional description, priority (low/medium/high), and due date, " +
      "then tap Save. You can also ask the AI assistant \"Add task [title] by " +
      "[date]\" and it will create it for you.",
    indexes: ["task", "create", "add", "new", "how"],
  },
  {
    title_type: "task_priority",
    doc_type: "faq",
    source_key: "task_creation",
    content:
      "How do I set task priority? When creating or editing a task, tap the " +
      "Priority field and choose Low, Medium, or High. High-priority tasks " +
      "appear highlighted in the Kanban board.",
    indexes: ["task", "priority", "high", "medium", "low", "set", "how"],
  },
  {
    title_type: "task_due_date",
    doc_type: "faq",
    source_key: "task_creation",
    content:
      "How do I set a due date on a task? Tap the Due Date field in the task " +
      "form and pick a date from the calendar picker. Tasks with due dates " +
      "appear in your Calendar view and in the Dashboard Close Deadlines card.",
    indexes: ["task", "due", "date", "deadline", "set", "how"],
  },
  {
    title_type: "task_kanban",
    doc_type: "faq",
    source_key: "task_creation",
    content:
      "How do I move a task between Kanban columns? Open the Kanban board for " +
      "a domain and drag the task card from To Do to In Progress or Done. " +
      "For team tasks the board updates in real time for all members.",
    indexes: ["task", "kanban", "move", "status", "column", "drag", "how"],
  },
  {
    title_type: "task_assign",
    doc_type: "faq",
    source_key: "task_creation",
    content:
      "How do I assign a task to a team member? On a team Kanban board, open " +
      "a task, tap Assign, and choose a member from the list. The assigned " +
      "member receives a push notification.",
    indexes: ["task", "assign", "team", "member", "how"],
  },
  {
    title_type: "task_edit_delete",
    doc_type: "faq",
    source_key: "task_creation",
    content:
      "How do I edit or delete a task? Tap a task card to open its details, " +
      "then tap Edit. To delete, tap the trash icon and confirm. The AI " +
      "assistant can also delete tasks: say \"Delete task [title]\".",
    indexes: ["task", "edit", "delete", "update", "remove", "how"],
  },

  // ── HABITS ───────────────────────────────────────────────────────────────
  {
    title_type: "habit_create",
    doc_type: "faq",
    source_key: "habit_tracker",
    content:
      "How do I create a habit? Go to the Habit Tracker tab, tap +, enter a " +
      "habit name, set the frequency (daily/weekly), and optionally set a " +
      "reminder time. Tap Save to start tracking.",
    indexes: ["habit", "create", "add", "new", "tracker", "how"],
  },
  {
    title_type: "habit_streak",
    doc_type: "faq",
    source_key: "habit_tracker_streak",
    content:
      "How does the habit streak work? Each consecutive day you mark a habit " +
      "complete, your streak counter increases by one. Missing a day resets " +
      "the streak to zero. Your longest streak earns you XP points.",
    indexes: ["habit", "streak", "consecutive", "days", "how", "what"],
  },
  {
    title_type: "habit_complete",
    doc_type: "faq",
    source_key: "habit_tracker",
    content:
      "How do I mark a habit as complete? In the Habit Tracker, tap the circle " +
      "next to the habit name for today. It will turn filled to show completion. " +
      "You can only mark a habit complete once per day.",
    indexes: ["habit", "complete", "mark", "check", "done", "how"],
  },
  {
    title_type: "habit_pause",
    doc_type: "faq",
    source_key: "habit_tracker",
    content:
      "How do I pause or resume a habit? Swipe left on a habit card and tap " +
      "Pause. While paused the habit does not appear in your daily checklist " +
      "and missing days do not break your streak. Tap Resume to reactivate it.",
    indexes: ["habit", "pause", "resume", "stop", "skip", "how"],
  },
  {
    title_type: "habit_health_guardrail",
    doc_type: "faq",
    source_key: "habit_tracker",
    content:
      "What are habit health guardrails? LifeStable monitors how many habits " +
      "you have active. If you add too many at once the app suggests focusing " +
      "on fewer to avoid burnout.",
    indexes: ["habit", "health", "guardrail", "limit", "burnout", "what"],
  },

  // ── TEAMS ────────────────────────────────────────────────────────────────
  {
    title_type: "team_create",
    doc_type: "faq",
    source_key: "team_management",
    content:
      "How do I create a team? Go to Teams, tap Create Team, enter a team " +
      "name, objective, and color. You become the team Owner. A unique invite " +
      "code is generated automatically for sharing.",
    indexes: ["team", "create", "new", "start", "how"],
  },
  {
    title_type: "team_join",
    doc_type: "faq",
    source_key: "team_management",
    content:
      "How do I join a team? Go to Teams and tap Join with Code. Enter the " +
      "6-character invite code shared by the team owner. Once joined, the " +
      "team Kanban board and shared tasks become visible in your workspace.",
    indexes: ["team", "join", "invite", "code", "how"],
  },
  {
    title_type: "team_roles",
    doc_type: "faq",
    source_key: "team_management",
    content:
      "What are team roles? There are three roles: Owner (full control), " +
      "Admin (can manage members and regenerate invite codes), and Member " +
      "(can create and update tasks). The Owner can promote any member to Admin.",
    indexes: ["team", "role", "owner", "admin", "member", "what"],
  },
  {
    title_type: "team_leave",
    doc_type: "faq",
    source_key: "team_management",
    content:
      "How do I leave a team? Go to Team Detail and tap Leave Team. If you " +
      "are the only owner, you must promote another member to Owner first. " +
      "Leaving removes the team mirror domain from your workspace.",
    indexes: ["team", "leave", "exit", "how"],
  },
  {
    title_type: "team_kanban",
    doc_type: "faq",
    source_key: "team_management",
    content:
      "How does the team Kanban board work? It shows all shared tasks in " +
      "To Do, In Progress, and Done columns. Any member can move tasks and " +
      "all members receive push notifications when tasks change.",
    indexes: ["team", "kanban", "board", "shared", "how", "what"],
  },

  // ── AI ASSISTANT ─────────────────────────────────────────────────────────
  {
    title_type: "ai_what_can_do",
    doc_type: "faq",
    source_key: "ai_assistant",
    content:
      "What can the AI assistant do? It can create, edit, and delete tasks " +
      "and calendar events using natural language. It can find free time gaps " +
      "in your schedule and understands both English and Turkish commands.",
    indexes: ["ai", "assistant", "can", "do", "what", "help"],
  },
  {
    title_type: "ai_voice_input",
    doc_type: "faq",
    source_key: "ai_assistant",
    content:
      "How do I use voice input with the AI? Tap the microphone icon in the " +
      "assistant chat, speak your command, and the app converts it to text " +
      "automatically. Grant microphone permission when prompted.",
    indexes: ["ai", "voice", "microphone", "speak", "how"],
  },
  {
    title_type: "ai_create_task",
    doc_type: "faq",
    source_key: "ai_assistant",
    content:
      "How do I create a task using the AI? Say or type \"Create task [title] " +
      "in [domain] by [date] with [priority] priority\". The AI creates the " +
      "task and navigates to the correct domain board.",
    indexes: ["ai", "create", "task", "how"],
  },
  {
    title_type: "ai_find_gap",
    doc_type: "faq",
    source_key: "ai_assistant",
    content:
      "How do I find free time in my schedule? Ask the AI \"Find me a free " +
      "slot this week for 2 hours of studying\". The assistant scans your " +
      "calendar events and suggests available time gaps.",
    indexes: ["ai", "free", "time", "gap", "schedule", "find", "how"],
  },

  // ── CALENDAR ─────────────────────────────────────────────────────────────
  {
    title_type: "calendar_create_event",
    doc_type: "faq",
    source_key: "calendar",
    content:
      "How do I manually create a calendar event? Open the Calendar tab, tap " +
      "a date, then tap +. Fill in the title, start and end time, and event " +
      "type (personal, class, or team). Tap Save.",
    indexes: ["calendar", "event", "create", "add", "how"],
  },
  {
    title_type: "calendar_google_sync",
    doc_type: "faq",
    source_key: "calendar",
    content:
      "How do I sync with Google Calendar? Go to Settings → Connected Accounts " +
      "→ Google Calendar and tap Connect. After authorizing, your Google Calendar " +
      "events appear in LifeStable and updates sync both ways.",
    indexes: ["calendar", "google", "sync", "connect", "import", "how"],
  },
  {
    title_type: "calendar_ocr_import",
    doc_type: "faq",
    source_key: "calendar",
    content:
      "How do I import a class schedule using a photo? In the Calendar tab tap " +
      "the camera icon and take or choose a photo of your timetable. The app " +
      "reads the text with OCR and shows a preview before adding events.",
    indexes: ["calendar", "ocr", "import", "photo", "class", "schedule", "how"],
  },

  // ── LOCATION REMINDERS ───────────────────────────────────────────────────
  {
    title_type: "location_create_alert",
    doc_type: "faq",
    source_key: "location_alerts",
    content:
      "How do I create a location reminder? Open the Alerts tab, tap +, search " +
      "for or pin a location on the map, write your reminder message, and choose " +
      "Arrival, Departure, or both as the trigger. Tap Save.",
    indexes: ["location", "alert", "reminder", "geofence", "create", "how"],
  },
  {
    title_type: "location_permissions",
    doc_type: "faq",
    source_key: "location_alerts",
    content:
      "Why do location reminders need Always On permission? Geofencing must " +
      "detect your location even when the app is closed. On iOS go to Settings " +
      "→ LifeStable → Location → Always. On Android grant Allow all the time.",
    indexes: ["location", "permission", "always", "background", "why"],
  },

  // ── DASHBOARD ────────────────────────────────────────────────────────────
  {
    title_type: "dashboard_overview",
    doc_type: "faq",
    source_key: "dashboard",
    content:
      "What does the Dashboard show? The Dashboard displays all your domains " +
      "as cards. Tapping a domain opens its Kanban board. The top area shows " +
      "a quick summary of today's tasks and upcoming deadlines.",
    indexes: ["dashboard", "home", "overview", "what", "show"],
  },
  {
    title_type: "dashboard_deadlines",
    doc_type: "faq",
    source_key: "dashboard",
    content:
      "What is the Close Deadlines card? It highlights tasks due within the " +
      "next 72 hours across all domains. Tap any item to jump directly to that " +
      "task's detail page.",
    indexes: ["dashboard", "deadline", "close", "upcoming", "what"],
  },

  // ── NOTIFICATIONS ────────────────────────────────────────────────────────
  {
    title_type: "notifications_manage",
    doc_type: "faq",
    source_key: "notifications",
    content:
      "How do I manage notification preferences? Go to Settings → Notifications " +
      "to toggle push notifications for task reminders, habit reminders, team " +
      "updates, and location alerts independently.",
    indexes: ["notification", "manage", "settings", "preference", "how"],
  },

  // ── OFFLINE MODE ─────────────────────────────────────────────────────────
  {
    title_type: "offline_behavior",
    doc_type: "faq",
    source_key: "offline_mode",
    content:
      "How does LifeStable work offline? Tasks and domains are cached locally " +
      "so you can view and create them without internet. Changes sync " +
      "automatically when the connection is restored.",
    indexes: ["offline", "no", "internet", "connection", "cache", "how", "what"],
  },

  // ── ONBOARDING ───────────────────────────────────────────────────────────
  {
    title_type: "onboarding_first_steps",
    doc_type: "onboarding",
    source_key: "onboarding",
    content:
      "Getting started with LifeStable: After signing up, create your first " +
      "domain for a life area like University or Work, then add tasks inside it. " +
      "Use the AI assistant to add tasks quickly with voice or text.",
    indexes: ["start", "begin", "first", "setup", "onboarding", "how"],
  },
  {
    title_type: "onboarding_points_levels",
    doc_type: "onboarding",
    source_key: "onboarding",
    content:
      "How do points and levels work? You earn XP points by completing tasks, " +
      "maintaining habit streaks, and achieving milestones. Accumulate enough " +
      "points to level up. Your level and streak are shown on your profile.",
    indexes: ["points", "level", "xp", "earn", "how", "what"],
  },
];
