# LifeStable — Automated Test Documentation

## Overview

This document describes all **150 automated test cases** (TC01–TC150) for the LifeStable project.
Tests are implemented in Dart using `flutter_test`, `bloc_test`, and `mocktail`.
No Firebase emulator or live connection is required to run the test suite.

**TC01–TC50** form the original baseline suite.  
**TC51–TC150** are the extended suite added in the second phase, covering edge
cases, copyWith mutations, sorting, grouping, Firestore map shape, and security
isolation.

```
flutter test
```

---

## Test Infrastructure

| File | Purpose |
|------|---------|
| `test/helpers/fixtures.dart` | Factory methods for all entity types (TaskEntity, NoteEntity, DomainEntity, CalendarEventEntity, Habit) |
| `test/mocks/mocks.dart` | Mocktail mock classes (MockTaskRepository, MockNoteRepository, MockDomainRepository) + fallback registration |

### Dependencies added to `pubspec.yaml`

```yaml
dev_dependencies:
  bloc_test: ^9.1.7
  mocktail: ^1.0.4
```

---

## Test File Index

### Baseline Suite (TC01–TC50)

| File | Test IDs |
|------|----------|
| `test/features/auth/auth_validation_test.dart` | TC01–TC05 |
| `test/features/domain/domain_cubit_test.dart` | TC06–TC10 |
| `test/features/tasks/tasks_bloc_test.dart` | TC11–TC13, TC19 |
| `test/features/tasks/task_entity_test.dart` | TC14–TC18, TC20 |
| `test/features/notes/notes_cubit_test.dart` | TC21–TC23 |
| `test/features/notes/note_entity_test.dart` | TC24–TC25 |
| `test/features/habits/habit_model_test.dart` | TC26–TC33 |
| `test/features/teams/team_domain_test.dart` | TC34–TC43 |
| `test/features/calendar/calendar_event_test.dart` | TC44–TC48 |
| `test/core/lru_cache_test.dart` | LRU cache (supports TC49) |
| `test/core/offline_task_cache_test.dart` | TC49–TC50 |

### Extended Suite (TC51–TC150)

| File | Test IDs |
|------|----------|
| `test/features/auth/auth_extended_test.dart` | TC51–TC60 |
| `test/features/tasks/task_extended_test.dart` | TC61–TC75 |
| `test/features/notes/note_extended_test.dart` | TC76–TC85 |
| `test/features/habits/habit_extended_test.dart` | TC86–TC95 |
| `test/features/calendar/calendar_extended_test.dart` | TC96–TC105 |
| `test/features/domain/domain_extended_test.dart` | TC106–TC115 |
| `test/features/teams/team_extended_test.dart` | TC116–TC125 |
| `test/core/lru_cache_extended_test.dart` | TC126–TC135 |
| `test/core/security_extended_test.dart` | TC136–TC150 |

---

## Section 1 — Authentication (TC01–TC05)

**File:** `test/features/auth/auth_validation_test.dart`  
**Layer tested:** Validation logic (format rules that mirror Firebase Auth constraints)

> **Note:** Firebase Auth sign-in and sign-up flows require a live Firebase
> connection and are covered by E2E/integration tests run against the emulator.
> These unit tests validate the pure-Dart input-validation layer.

---

### TC01 — Successful registration with valid credentials

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation (pure Dart) |
| **Pre-conditions** | None |
| **Test Steps** | 1. Supply a well-formed email (`alice@example.com`)<br>2. Supply a password of 9 chars (`Secure#99`)<br>3. Run `isValidEmail` and `isValidPassword` |
| **Expected Outcome** | Both validators return `true` |

---

### TC02 — Duplicate email surfaces as exception

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Error propagation |
| **Pre-conditions** | A user is already registered with the given email |
| **Test Steps** | 1. Create an `Exception('email-already-in-use')` simulating Firebase Auth error<br>2. Throw it and catch via `expect(..., throwsA(...))` |
| **Expected Outcome** | Exception message contains `'email-already-in-use'` |

---

### TC03 — onCreateUser Cloud Function default gamification values

| Field | Value |
|-------|-------|
| **Feature** | Authentication / Gamification |
| **Layer** | Data model (Cloud Function output contract) |
| **Pre-conditions** | A new UID is provided |
| **Test Steps** | 1. Build the default user profile map<br>2. Assert field values |
| **Expected Outcome** | `points=0`, `level=1`, `streak=0`, `uid` matches the given UID |

---

### TC04 — Short password fails validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Pre-conditions** | None |
| **Test Steps** | 1. Run `isValidPassword` on `'abc'`, `'1234567'`, and `'12345678'` |
| **Expected Outcome** | Strings shorter than 8 chars → `false`; exactly 8 chars → `true` |

---

### TC05 — Malformed emails fail validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Pre-conditions** | None |
| **Test Steps** | 1. Pass `'not-an-email'`, `'missing@tld'`, `'@nodomain.com'`, and a valid edge case to `isValidEmail` |
| **Expected Outcome** | Malformed strings → `false`; `'user+tag@sub.domain.org'` → `true` |

---

## Section 2 — Domain Management (TC06–TC10)

**File:** `test/features/domain/domain_cubit_test.dart`  
**Layer tested:** `DomainCubit` (business logic) + `DomainEntity` (data model)

---

### TC06 — Create a new Domain

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | BLoC / Cubit |
| **Pre-conditions** | `MockDomainRepository` is configured with `createOrUpdateDomain` stub |
| **Test Steps** | 1. Call `DomainCubit.addDomain` with a new entity<br>2. Verify repository was called once |
| **Expected Outcome** | `MockDomainRepository.createOrUpdateDomain` called exactly once; no error state emitted |

---

### TC07 — Update domain name and color

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | BLoC / Cubit |
| **Pre-conditions** | Domain entity exists in the mock |
| **Test Steps** | 1. Call `DomainCubit.updateDomain` with modified `name` and `colorHex`<br>2. Verify repository interaction |
| **Expected Outcome** | Repository `createOrUpdateDomain` called once with modified entity |

---

### TC08 — Delete a Domain

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | BLoC / Cubit |
| **Pre-conditions** | Domain with `id='domain-1'` exists |
| **Test Steps** | 1. Call `DomainCubit.deleteDomain('domain-1')` |
| **Expected Outcome** | `MockDomainRepository.deleteDomain('domain-1')` called once |

---

### TC09 — Domain reorder via copyWith

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Pre-conditions** | None |
| **Test Steps** | 1. Create a `DomainEntity`<br>2. Call `copyWith(name: 'Fitness', colorHex: '#E91E63')` |
| **Expected Outcome** | `name` and `colorHex` are updated; `id` and `iconCode` are unchanged |

---

### TC10 — Dashboard domain cards reflect correct data

| Field | Value |
|-------|-------|
| **Feature** | Domain Dashboard |
| **Layer** | BLoC / Cubit + State |
| **Pre-conditions** | Mock stream emits two domains (`Health`, `Career`) |
| **Test Steps** | 1. Call `DomainCubit.loadDomains()`<br>2. Await stream emission |
| **Expected Outcome** | State sequence: `DomainLoading` → `DomainLoaded` with both domain names |

---

## Section 3 — Task Management / Kanban (TC11–TC20)

### BLoC tests — `test/features/tasks/tasks_bloc_test.dart`

---

### TC11 — Create a new task

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | TasksBloc |
| **Pre-conditions** | `MockTaskRepository.createOrUpdateTask` is stubbed |
| **Test Steps** | 1. Dispatch `AddTask(task)` to `TasksBloc` |
| **Expected Outcome** | `createOrUpdateTask` called once; no error state emitted |

---

### TC12 — Move task from To-Do to In-Progress

| Field | Value |
|-------|-------|
| **Feature** | Kanban Board |
| **Layer** | TasksBloc |
| **Pre-conditions** | Bloc seeded with `TasksLoaded([task])` where `task.status = todo` |
| **Test Steps** | 1. Dispatch `UpdateTaskStatus(task.id, TaskStatus.inProgress)` |
| **Expected Outcome** | `createOrUpdateTask` called with a task whose `status == TaskStatus.inProgress` |

---

### TC13 — Mark task as Done

| Field | Value |
|-------|-------|
| **Feature** | Kanban Board |
| **Layer** | TasksBloc |
| **Pre-conditions** | Bloc seeded with task in `inProgress` state |
| **Test Steps** | 1. Dispatch `UpdateTaskStatus(task.id, TaskStatus.done)` |
| **Expected Outcome** | `createOrUpdateTask` called with `status == TaskStatus.done` |

---

### TC14 — Filter tasks by priority level

| Field | Value |
|-------|-------|
| **Feature** | Task Filtering |
| **Layer** | Data model (list operations) |
| **Pre-conditions** | List of tasks with mixed priorities |
| **Test Steps** | 1. Filter list by `priority == TaskPriority.high` |
| **Expected Outcome** | Only tasks with `high` priority are returned |

---

### TC15 — Server-side data validation (fromFirestore edge cases)

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model |
| **Pre-conditions** | None |
| **Test Steps** | 1. Call `TaskEntity.fromFirestore` with missing/invalid `status` and `priority` fields<br>2. Call with valid ISO dueDate and null dueDate |
| **Expected Outcome** | Missing/unknown fields default to `TaskStatus.todo` and `TaskPriority.medium`; dates parsed correctly |

---

### TC16 — Reject past due dates

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model |
| **Pre-conditions** | None |
| **Test Steps** | 1. Create tasks with past, future, and null dueDate<br>2. Apply `dueDate.isBefore(DateTime.now())` check |
| **Expected Outcome** | Past date → overdue; future date → not overdue; null → not overdue |

---

### TC17 — Add/edit task notes via description

| Field | Value |
|-------|-------|
| **Feature** | Task Detail |
| **Layer** | Data model (copyWith) |
| **Pre-conditions** | Task with `description = null` |
| **Test Steps** | 1. Call `task.copyWith(description: 'Some note')` |
| **Expected Outcome** | `description` is updated; all other fields unchanged |

---

### TC18 — Filter tasks by Domain

| Field | Value |
|-------|-------|
| **Feature** | Domain-based Kanban |
| **Layer** | Data model |
| **Pre-conditions** | Tasks with mixed `domainId` values |
| **Test Steps** | 1. Filter by `domainId == 'health'` |
| **Expected Outcome** | Only tasks belonging to the `health` domain are returned |

---

### TC19 — Delete task (BLoC + stream)

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | TasksBloc |
| **Pre-conditions** | `MockTaskRepository.deleteTask` is stubbed |
| **Test Steps** | 1. Dispatch `DeleteTask('task-99')`<br>2. Verify repository call<br>3. Confirm deleted task absent from subsequent `TasksLoaded` state |
| **Expected Outcome** | `deleteTask('task-99')` called once; deleted task not present in `TasksLoaded.tasks` |

---

### TC20 — Task search by title

| Field | Value |
|-------|-------|
| **Feature** | Task Search |
| **Layer** | Data model |
| **Pre-conditions** | List of tasks with varied titles |
| **Test Steps** | 1. Apply case-insensitive `.contains(query)` filter |
| **Expected Outcome** | Only tasks whose title contains the query substring are returned; empty query returns all |

---

## Section 4 — Notes Module (TC21–TC25)

### TC21 — Create note bound to a Domain

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | NotesCubit |
| **Pre-conditions** | `MockNoteRepository.updateNote` stubbed |
| **Test Steps** | 1. Call `NotesCubit.updateNote(note)` with a domain-linked note |
| **Expected Outcome** | `repo.updateNote` called once (updateNote has no Firebase Auth check) |

> `createNote` / `deleteNote` require `FirebaseAuth.instance` and are covered by E2E tests.

---

### TC22 — Real-time note sync (watchNotes)

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | NoteRepository stream |
| **Pre-conditions** | Mock stream configured to emit two notes |
| **Test Steps** | 1. Subscribe to `mockRepo.watchNotes('user-1')`<br>2. Collect first emission |
| **Expected Outcome** | Stream emits list of two notes; error stream forwards exceptions |

---

### TC23 — Sort notes by creation date

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model (list sorting) |
| **Pre-conditions** | Three notes with different `createdAt` timestamps |
| **Test Steps** | 1. Sort notes by `b.createdAt.compareTo(a.createdAt)` (descending) |
| **Expected Outcome** | Newest note is first; oldest note is last |

---

### TC24 — In-note content search

| Field | Value |
|-------|-------|
| **Feature** | Notes Search |
| **Layer** | Data model |
| **Pre-conditions** | Notes with varied title/content |
| **Test Steps** | 1. Filter by case-insensitive content substring<br>2. Filter by title substring |
| **Expected Outcome** | Only matching notes returned; no match → empty list |

---

### TC25 — NoteEntity Firestore serialization round-trip

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Pre-conditions** | None |
| **Test Steps** | 1. Create `NoteEntity`<br>2. Call `toFirestore()`<br>3. Reconstruct via `fromFirestore()` |
| **Expected Outcome** | All fields preserved; null fields in Firestore map produce safe empty-string defaults |

---

## Section 5 — Habit Tracker (TC26–TC33)

**File:** `test/features/habits/habit_model_test.dart`

---

### TC26 — Daily habit creation and isCompletedToday

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Pre-conditions** | None |
| **Test Steps** | 1. Create habit with `lastCompleted = DateTime.now()`<br>2. Check `isCompletedToday` |
| **Expected Outcome** | `true` when completed today; `false` for yesterday; `false` for null |

---

### TC27 — Streak increments on completion

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Pre-conditions** | Habit with `streak = 4` |
| **Test Steps** | 1. Build an updated Habit with `streak = habit.streak + 1` |
| **Expected Outcome** | New streak is 5; first-ever completion starts streak at 1 |

---

### TC28 — Pause mode (Health Guardrail)

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker / Guardrails |
| **Layer** | Data model + Firestore map |
| **Pre-conditions** | Habit with `isPaused = true` |
| **Test Steps** | 1. Call `habit.toMap()`<br>2. Check `is_paused` field |
| **Expected Outcome** | `is_paused = true` in Firestore map; `false` after resume |

---

### TC29 — Streak reset after 2+ day gap

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Pre-conditions** | Various `lastCompleted` offsets |
| **Test Steps** | 1. Check `shouldResetStreak` for 3-day gap, 1-day gap, today, null |
| **Expected Outcome** | 3-day gap → `true`; 1-day gap → `false`; today → `false`; null → `false` |

---

### TC30 — Habit point system serialization

| Field | Value |
|-------|-------|
| **Feature** | Gamification / Habits |
| **Layer** | Data model |
| **Pre-conditions** | None |
| **Test Steps** | 1. Call `habit.toMap()`<br>2. Assert all required Firestore fields present |
| **Expected Outcome** | Map contains `name`, `domain_id`, `streak`, `is_paused`, `user_id`, `created_at`, `completed_dates` |

---

### TC31 — Fire icon streak visual indicator

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker UI logic |
| **Layer** | Data model |
| **Pre-conditions** | None |
| **Test Steps** | 1. Check `streak > 0` for streaks 0, 1, 3 |
| **Expected Outcome** | `streak > 0` → fire icon shown; `streak == 0` → no fire icon |

---

### TC32 — Completion log (completedDates sub-collection)

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Pre-conditions** | None |
| **Test Steps** | 1. Create habit with `completedDates = ['2024-06-01', '2024-06-02', '2024-06-03']`<br>2. Check round-trip via `toMap()` |
| **Expected Outcome** | Length is 3; all date strings present; `toMap` list matches |

---

### TC33 — Paused habit streak protection

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker / Guardrails |
| **Layer** | Data model + service layer |
| **Pre-conditions** | Paused habit with 3-day gap |
| **Test Steps** | 1. Check raw `shouldResetStreak`<br>2. Apply service-layer guard: `shouldResetStreak && !isPaused` |
| **Expected Outcome** | Raw model returns `true` (time gap); guarded expression returns `false` (paused) |

---

## Section 6 — Team Collaboration (TC34–TC43)

**File:** `test/features/teams/team_domain_test.dart`

---

### TC34 — 6-digit team invite code format

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Input validation |
| **Test Steps** | 1. Validate `'ABC123'` against `^[A-Z0-9]{6}$`<br>2. Test shorter/longer codes |
| **Expected Outcome** | Valid 6-char code passes; shorter/longer codes fail |

---

### TC35 — Join team creates mirrored Domain

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration / Domain Mirroring |
| **Layer** | Data model |
| **Test Steps** | 1. Create `DomainEntity` with `teamId` set |
| **Expected Outcome** | Entity carries non-null `teamId`; value matches the team id |

---

### TC36 — isTeamMirror flag

| Field | Value |
|-------|-------|
| **Feature** | Domain Mirroring |
| **Layer** | Data model computed property |
| **Test Steps** | 1. Check `isTeamMirror` for domain with and without `teamId` |
| **Expected Outcome** | `teamId != null` → `true`; `teamId == null` → `false` |

---

### TC37 — Assign task to team member

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Data model |
| **Test Steps** | 1. Create task with `assignedTo = 'member-user-42'` and `teamId` set |
| **Expected Outcome** | `assignedTo` field contains member userId; unassigned task has `null` |

---

### TC38 — Identify team vs personal task

| Field | Value |
|-------|-------|
| **Feature** | Team Tasks |
| **Layer** | Data model |
| **Test Steps** | 1. Check `teamId != null` on tasks |
| **Expected Outcome** | `teamId` present → team task; `teamId == null` → personal task |

---

### TC39 — DomainEntity preserves teamId through Firestore round-trip

| Field | Value |
|-------|-------|
| **Feature** | Domain Mirroring |
| **Layer** | Data model |
| **Test Steps** | 1. `toFirestore()` then `fromFirestore()` on domain with `teamId` |
| **Expected Outcome** | `teamId` preserved; `isTeamMirror` still `true` after round-trip |

---

### TC40 — Team task version conflict detection

| Field | Value |
|-------|-------|
| **Feature** | Real-time Team Sync |
| **Layer** | Data model + optimistic locking |
| **Test Steps** | 1. Compare `clientVersion` vs `serverVersion`<br>2. Simulate increment by 1 |
| **Expected Outcome** | Version mismatch → `isConflicted = true`; match → `false`; update increments by 1 |

---

### TC41 — Leave team removes mirrored Domain

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Data model |
| **Test Steps** | 1. Create mirrored domain<br>2. Copy with `teamId = null` |
| **Expected Outcome** | Domain without `teamId` has `isTeamMirror = false` |

---

### TC42 — Combined personal + team task view

| Field | Value |
|-------|-------|
| **Feature** | Unified Task View (CombineLatest) |
| **Layer** | Data model (list merge) |
| **Test Steps** | 1. Merge 2 personal tasks + 2 team tasks |
| **Expected Outcome** | Combined list has 4 entries; 2 personal + 2 team; no duplicates |

---

### TC43 — Full team task structure

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Data model |
| **Test Steps** | 1. Create task with `teamId`, `assignedTo`, `status`, `priority`<br>2. Verify `toFirestore()` map |
| **Expected Outcome** | Map contains `teamId` and `assignedTo` keys with correct values |

---

## Section 7 — Calendar & AI Integration (TC44–TC48)

**File:** `test/features/calendar/calendar_event_test.dart`

---

### TC44 — Calendar time-block display (duration)

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model computed property |
| **Test Steps** | 1. Create event from 09:00–10:30<br>2. Check `event.duration` |
| **Expected Outcome** | Duration is 1h 30m; back-to-back 1h events each report 60 minutes |

---

### TC45 — Overlap (conflict) detection

| Field | Value |
|-------|-------|
| **Feature** | Calendar Conflict Detection |
| **Layer** | Data model |
| **Test Steps** | 1. Test fully overlapping, consecutive (boundary), non-adjacent, self, and partial-overlap pairs |
| **Expected Outcome** | Full/partial overlap → `true`; consecutive boundary → `false`; non-adjacent → `false`; self → `false` |

---

### TC46 — Daily/weekly/monthly view type labels

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model (enum extension) |
| **Test Steps** | 1. Check `.label` on all `CalendarEventType` values<br>2. Test `fromFirestore` with unknown type string |
| **Expected Outcome** | Correct labels; unknown type defaults to `CalendarEventType.personal` |

---

### TC47 — AI-generated event and team event structure

| Field | Value |
|-------|-------|
| **Feature** | AI Integration / Team Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Create team event with `eventType=team`, `teamId`, and `assignedMemberIds`<br>2. Check `isTeamEvent`, `hasLinkedTask` |
| **Expected Outcome** | `isTeamEvent=true` when both `eventType=team` and `teamId` are set; `false` without teamId |

---

### TC48 — Calendar events sorted chronologically

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model (list sorting) |
| **Test Steps** | 1. Sort list of 3 events with different `startAt` times |
| **Expected Outcome** | Events in ascending `startAt` order; mixed event types ordered by time |

---

## Section 8 — Offline Mode & Security (TC49–TC50)

**File:** `test/core/offline_task_cache_test.dart`

---

### TC49 — Offline-first task creation and sync

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (OfflineTaskCache + LruCache) |
| **Pre-conditions** | `SharedPreferences.setMockInitialValues({})` called in setUp |
| **Test Steps** | 1. Create `OfflineTaskCache`<br>2. `upsertTask` → `getTask` → `markTaskSynced` → `removeTask`<br>3. Create second cache instance (simulates restart) |
| **Expected Outcome** | Task persists across `getTask`; dirty flag present after upsert; cleared after sync; task absent after remove; task survives cache re-creation (SharedPreferences persistence) |

---

### TC50 — Firestore Security Rules: cross-user data isolation

| Field | Value |
|-------|-------|
| **Feature** | Security |
| **Layer** | Data model + Firestore path structure |
| **Pre-conditions** | Two user UIDs (`user-alice`, `user-bob`) |
| **Test Steps** | 1. Build personal task collection paths for both users<br>2. Compare paths<br>3. Verify `toFirestore()` does not emit a `userId` field |
| **Expected Outcome** | `users/user-alice/tasks ≠ users/user-bob/tasks`; Firestore document does **not** contain a `userId` field that could be spoofed; ownership is enforced by the write path, not by document content |

---

---

## Section 9 — Authentication Extended (TC51–TC60)

**File:** `test/features/auth/auth_extended_test.dart`  
**Layer tested:** Validation logic (format rules), gamification profile defaults

---

### TC51 — Long TLD email passes validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Test Steps** | 1. Pass `user@example.museum` and `contact@company.online` to `isValidEmail` |
| **Expected Outcome** | Both return `true` — TLDs of 4+ chars are valid |

---

### TC52 — Email with hyphen in domain passes validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Test Steps** | 1. Pass `user@my-company.com` and `user@sub-domain.example.org` |
| **Expected Outcome** | Both return `true` — hyphens in domain labels are RFC-valid |

---

### TC53 — Email with underscore in local part passes validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Test Steps** | 1. Pass `first_last@example.com` and `_admin@example.org` |
| **Expected Outcome** | Both return `true` — `\w` in the regex includes `_` |

---

### TC54 — Empty string fails email validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Test Steps** | 1. Pass `''` to `isValidEmail` |
| **Expected Outcome** | Returns `false` |

---

### TC55 — Empty string fails password validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Test Steps** | 1. Pass `''` to `isValidPassword` |
| **Expected Outcome** | Returns `false` — empty password is 0 chars, below the 8-char minimum |

---

### TC56 — Password of 9 characters passes validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Test Steps** | 1. Pass `'abcdefghi'` (9 chars) |
| **Expected Outcome** | Returns `true` — 9 > 8 |

---

### TC57 — Very long password (100 chars) passes validation

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Validation |
| **Test Steps** | 1. Pass a 100-char string |
| **Expected Outcome** | Returns `true` — no maximum length constraint |

---

### TC58 — New user profile map contains all required gamification keys

| Field | Value |
|-------|-------|
| **Feature** | Authentication / Gamification |
| **Layer** | Data model |
| **Test Steps** | 1. Build profile map with `uid`, `points`, `level`, `streak`<br>2. Assert all keys present |
| **Expected Outcome** | All 4 keys (`uid`, `points`, `level`, `streak`) are present in the map |

---

### TC59 — Initial user level is exactly 1

| Field | Value |
|-------|-------|
| **Feature** | Gamification |
| **Layer** | Data model |
| **Test Steps** | 1. Assert `profile['level'] == 1` |
| **Expected Outcome** | Level is `1`, not `0` or `2` — level 0 would be an invalid starting state |

---

### TC60 — Distinct auth error types are distinguishable by message content

| Field | Value |
|-------|-------|
| **Feature** | Authentication |
| **Layer** | Error handling |
| **Test Steps** | 1. Create `wrong-password`, `email-already-in-use`, and `user-not-found` exceptions<br>2. Compare `.toString()` output |
| **Expected Outcome** | Each exception's message is unique and contains its error code |

---

## Section 10 — Task Management Extended (TC61–TC75)

**File:** `test/features/tasks/task_extended_test.dart`  
**Layer tested:** `TaskEntity` copyWith mutations, sorting, grouping, and Firestore map shape

---

### TC61 — copyWith updates title field

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model (copyWith) |
| **Test Steps** | 1. Create task with `title='Original Title'`<br>2. Call `copyWith(title: 'Updated Title')` |
| **Expected Outcome** | `title` updated; `id`, `domainId`, `status`, `priority` unchanged |

---

### TC62 — copyWith updates priority field

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(priority: TaskPriority.high)` on a low-priority task<br>2. Call `copyWith(priority: TaskPriority.low)` on a medium-priority task |
| **Expected Outcome** | Priority changes as requested; other fields unchanged |

---

### TC63 — copyWith updates domainId field

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(domainId: 'domain-new')` on a task in `'domain-old'` |
| **Expected Outcome** | `domainId` updated; `id` unchanged |

---

### TC64 — copyWith updates version field

| Field | Value |
|-------|-------|
| **Feature** | Real-time Sync |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(version: original.version + 1)` on a version-3 task |
| **Expected Outcome** | New version is `4`; original version remains `3` |

---

### TC65 — copyWith updates lastModifiedBy field

| Field | Value |
|-------|-------|
| **Feature** | Audit Trail |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(lastModifiedBy: 'user-editor-1')` on a task with `null` lastModifiedBy |
| **Expected Outcome** | `lastModifiedBy` set; original remains `null` |

---

### TC66 — Tasks sorted by priority (high first)

| Field | Value |
|-------|-------|
| **Feature** | Task Filtering |
| **Layer** | Data model (list operations) |
| **Test Steps** | 1. Create tasks with `low`, `high`, `medium` priority<br>2. Sort using a `priorityOrder` map |
| **Expected Outcome** | `high` first, `low` last |

---

### TC67 — Tasks sorted by dueDate ascending (null dates last)

| Field | Value |
|-------|-------|
| **Feature** | Task Filtering |
| **Layer** | Data model |
| **Test Steps** | 1. Sort tasks with different dueDates<br>2. Verify null dates are placed last |
| **Expected Outcome** | Earliest dueDate first; `null` dueDate tasks are at the end |

---

### TC68 — Tasks grouped by status

| Field | Value |
|-------|-------|
| **Feature** | Kanban Board |
| **Layer** | Data model |
| **Test Steps** | 1. Group 6 tasks (2 todo, 1 inProgress, 3 done) by `status` |
| **Expected Outcome** | `todo` bucket: 2, `inProgress` bucket: 1, `done` bucket: 3 |

---

### TC69 — Filter tasks by done status

| Field | Value |
|-------|-------|
| **Feature** | Task Filtering |
| **Layer** | Data model |
| **Test Steps** | 1. Filter list by `status == TaskStatus.done` |
| **Expected Outcome** | Only `done` tasks returned; count is 2 |

---

### TC70 — Filter tasks by assignedTo

| Field | Value |
|-------|-------|
| **Feature** | Team Tasks |
| **Layer** | Data model |
| **Test Steps** | 1. Filter list by `assignedTo == 'member-alice'` |
| **Expected Outcome** | Only Alice's tasks returned; unassigned tasks excluded |

---

### TC71 — toFirestore omits teamId when null

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` on a personal task (no `teamId`) |
| **Expected Outcome** | Map does NOT contain `teamId` key |

---

### TC72 — toFirestore omits assignedTo when null

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` on an unassigned task |
| **Expected Outcome** | Map does NOT contain `assignedTo` key |

---

### TC73 — toFirestore includes description when set / null when not set

| Field | Value |
|-------|-------|
| **Feature** | Task Detail |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` with non-null description<br>2. Call with `null` description |
| **Expected Outcome** | Non-null → map value equals the description; null → map value is `null` |

---

### TC74 — fromFirestore parses version field

| Field | Value |
|-------|-------|
| **Feature** | Real-time Sync |
| **Layer** | Data model |
| **Test Steps** | 1. Parse map with `version: 7`<br>2. Parse map with missing `version` |
| **Expected Outcome** | Explicit version → `7`; missing version → `0` |

---

### TC75 — fromFirestore parses lastModifiedBy field

| Field | Value |
|-------|-------|
| **Feature** | Audit Trail |
| **Layer** | Data model |
| **Test Steps** | 1. Parse map with `lastModifiedBy: 'user-auditor-99'`<br>2. Parse map without the field |
| **Expected Outcome** | Present → `'user-auditor-99'`; absent → `null` |

---

## Section 11 — Notes Extended (TC76–TC85)

**File:** `test/features/notes/note_extended_test.dart`  
**Layer tested:** `NoteEntity` copyWith, filtering, grouping, and Firestore map shape

---

### TC76 — NoteEntity copyWith updates title

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(title: 'Revised Title')` |
| **Expected Outcome** | `title` updated; `id`, `userId`, `content`, `createdAt` unchanged |

---

### TC77 — NoteEntity copyWith updates domainId

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(domainId: 'domain-personal')` on a work-domain note |
| **Expected Outcome** | `domainId` updated; `id` unchanged |

---

### TC78 — Filter notes by domainId

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Test Steps** | 1. Filter 4 notes by `domainId == 'domain-health'`<br>2. Filter for a domain with no notes |
| **Expected Outcome** | Returns 2 matching notes; empty domain returns empty list |

---

### TC79 — Combined title OR content search

| Field | Value |
|-------|-------|
| **Feature** | Notes Search |
| **Layer** | Data model |
| **Test Steps** | 1. Search for `'quarterly'` across `title` and `content` fields |
| **Expected Outcome** | Matches note whose title contains the query AND note whose content contains it |

---

### TC80 — Note with empty content is valid

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Test Steps** | 1. Create `NoteEntity` with `content: ''` |
| **Expected Outcome** | Entity is valid; `content` is empty; `title` is non-empty |

---

### TC81 — NoteEntity toFirestore includes userId field

| Field | Value |
|-------|-------|
| **Feature** | Notes / Security |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` and inspect the map |
| **Expected Outcome** | Map contains `userId` key with correct value |

---

### TC82 — NoteEntity toFirestore contains all required fields

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` and check for all 6 required keys |
| **Expected Outcome** | Map contains `userId`, `domainId`, `title`, `content`, `createdAt`, `updatedAt` |

---

### TC83 — Multiple notes under same domain can coexist

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Test Steps** | 1. Filter 3 notes all sharing `domainId='shared-domain'` |
| **Expected Outcome** | All 3 notes returned; no truncation |

---

### TC84 — Note with very long content round-trips correctly

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Test Steps** | 1. Create note with 10 000-char content<br>2. `toFirestore()` → `fromFirestore()` |
| **Expected Outcome** | `content.length == 10000` after deserialization |

---

### TC85 — Notes sorted by updatedAt for edit-time ordering

| Field | Value |
|-------|-------|
| **Feature** | Notes |
| **Layer** | Data model |
| **Test Steps** | 1. Sort 3 notes by `b.updatedAt.compareTo(a.updatedAt)` (descending) |
| **Expected Outcome** | Most recently edited note appears first; oldest-edited note is last |

---

## Section 12 — Habit Tracker Extended (TC86–TC95)

**File:** `test/features/habits/habit_extended_test.dart`  
**Layer tested:** `Habit` edge cases — large streaks, completedDates, boundary conditions

---

### TC86 — Habit with large streak value (365)

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Test Steps** | 1. Create habit with `streak: 365`<br>2. Check `toMap()` and fire-icon condition |
| **Expected Outcome** | `streak == 365`; `toMap()['streak'] == 365`; fire icon shows |

---

### TC87 — completedDates count matches expected length

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Test Steps** | 1. Create habit with 7 date strings<br>2. Add a new date to get 3-entry list |
| **Expected Outcome** | Lengths are 7 and 3 respectively |

---

### TC88 — Habit name is preserved in toMap

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toMap()` on habit with `name='Evening meditation'` |
| **Expected Outcome** | `map['name'] == 'Evening meditation'` |

---

### TC89 — Habit domainId is preserved in toMap

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toMap()` on habit with `domainId='domain-wellness'` |
| **Expected Outcome** | `map['domain_id'] == 'domain-wellness'` |

---

### TC90 — Habit userId is preserved in toMap

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker / Security |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toMap()` on habit with `userId='user-owner-7'` |
| **Expected Outcome** | `map['user_id'] == 'user-owner-7'` |

---

### TC91 — shouldResetStreak boundary — exactly 2-day gap

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Test Steps** | 1. Set `lastCompleted` to 2 days ago → check `shouldResetStreak`<br>2. Set to 3 days ago → check again |
| **Expected Outcome** | 2-day gap → `false` (within grace window); 3-day gap → `true` |

---

### TC92 — Consecutive completion dates build streak

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Test Steps** | 1. Add today's date to `completedDates` for a running habit |
| **Expected Outcome** | Today's date-string is in `completedDates`; length is 3 |

---

### TC93 — Paused habit retains its streak

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker / Guardrails |
| **Layer** | Data model |
| **Test Steps** | 1. Create paused habit with `streak: 42` |
| **Expected Outcome** | `streak == 42` is preserved while `isPaused == true` |

---

### TC94 — created_at field appears in toMap as Timestamp

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toMap()` and check for `created_at` key |
| **Expected Outcome** | `created_at` is present and non-null (Firestore Timestamp type) |

---

### TC95 — Empty completedDates serializes to empty list in toMap

| Field | Value |
|-------|-------|
| **Feature** | Habit Tracker |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toMap()` on a brand-new habit with no completions |
| **Expected Outcome** | `map['completed_dates']` is an empty `List`, not `null` |

---

## Section 13 — Calendar Extended (TC96–TC105)

**File:** `test/features/calendar/calendar_extended_test.dart`  
**Layer tested:** `CalendarEventEntity` copyWith, duration edge cases, Firestore round-trip

---

### TC96 — CalendarEventEntity copyWith updates title

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(title: 'New Title')` |
| **Expected Outcome** | `title` updated; `id`, `userId`, `startAt`, `endAt` unchanged |

---

### TC97 — copyWith updates eventType

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(eventType: CalendarEventType.task)` on a personal event |
| **Expected Outcome** | `eventType` updated; original remains `personal` |

---

### TC98 — Event spanning midnight has correct duration

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model computed property |
| **Test Steps** | 1. Create event from `23:00` to `01:00` next day |
| **Expected Outcome** | `duration == Duration(hours: 2)` |

---

### TC99 — Recurring event flag serialized to Firestore

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Set `isRecurring: true`; call `toFirestore()`<br>2. Verify default `false` also serializes |
| **Expected Outcome** | `map['isRecurring']` reflects the flag in both cases |

---

### TC100 — Event colorHex preserved in toFirestore

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Set `colorHex: '#FF5722'`; call `toFirestore()`<br>2. Verify key absent when `null` |
| **Expected Outcome** | Present → key with `'#FF5722'`; absent → key not in map |

---

### TC101 — Event externalEventId preserved in toFirestore

| Field | Value |
|-------|-------|
| **Feature** | Calendar (external sync) |
| **Layer** | Data model |
| **Test Steps** | 1. Set `externalEventId: 'google-evt-xyz'`; call `toFirestore()` |
| **Expected Outcome** | Map contains `externalEventId: 'google-evt-xyz'` |

---

### TC102 — CalendarEventEntity fromFirestore round-trip

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. `toFirestore()` then `fromFirestore()` on a team event with members |
| **Expected Outcome** | `id`, `userId`, `title`, `eventType`, `teamId`, `assignedMemberIds`, `startAt` all preserved |

---

### TC103 — Filter events by eventType

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Filter 4 events (2 personal, 1 task, 1 classSchedule) by `personal` |
| **Expected Outcome** | Returns 2 personal events |

---

### TC104 — Event with multiple assigned members

| Field | Value |
|-------|-------|
| **Feature** | Team Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Create event with 4 `assignedMemberIds`<br>2. Verify `toFirestore()` round-trip |
| **Expected Outcome** | All 4 member UIDs preserved; `assignedMemberIds` in map is a `List` |

---

### TC105 — sourceCollection is preserved via copyWith

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(sourceCollection: EventSourceCollection.team)` |
| **Expected Outcome** | `sourceCollection` updated; original remains `personal` |

---

## Section 14 — Domain Management Extended (TC106–TC115)

**File:** `test/features/domain/domain_extended_test.dart`  
**Layer tested:** `DomainEntity` copyWith mutations, sorting, and Firestore defaults

---

### TC106 — DomainEntity copyWith updates name

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(name: 'Wellness')` on a `'Health'` domain |
| **Expected Outcome** | `name` updated; `id`, `colorHex`, `iconCode` unchanged |

---

### TC107 — DomainEntity copyWith updates colorHex

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(colorHex: '#E91E63')` |
| **Expected Outcome** | `colorHex` updated; `name`, `id` unchanged |

---

### TC108 — DomainEntity copyWith updates iconCode

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(iconCode: 0xe52f)` on a domain with code `0xe1af` |
| **Expected Outcome** | `iconCode` updated to `0xe52f` |

---

### TC109 — DomainEntity copyWith updates description

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(description: 'Tracks health habits')` on a domain with `null` description |
| **Expected Outcome** | `description` set; original remains `null` |

---

### TC110 — Domains sorted alphabetically by name

| Field | Value |
|-------|-------|
| **Feature** | Domain Dashboard |
| **Layer** | Data model |
| **Test Steps** | 1. Sort `['Fitness', 'Career', 'Education']` domains by `name.compareTo` |
| **Expected Outcome** | Order: `Career`, `Education`, `Fitness` |

---

### TC111 — Domain with description includes it in toFirestore

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` on domain with `description: 'Personal wellness tracking'` |
| **Expected Outcome** | Map contains `description` key with the correct value |

---

### TC112 — Domain without description serializes description as null

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` on domain with `description: null` |
| **Expected Outcome** | Map contains `description` key with `null` value |

---

### TC113 — fromFirestore uses default iconCode when missing

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Parse map without `iconCode` field |
| **Expected Outcome** | `iconCode` defaults to `0xe1af` |

---

### TC114 — fromFirestore uses default colorHex when missing

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Parse map without `colorHex` field |
| **Expected Outcome** | `colorHex` defaults to `'#7C4DFF'` (brand purple) |

---

### TC115 — Multiple domains with same colorHex can coexist

| Field | Value |
|-------|-------|
| **Feature** | Domain Management |
| **Layer** | Data model |
| **Test Steps** | 1. Create two domains with `colorHex: '#E91E63'` but different `id` and `name` |
| **Expected Outcome** | Entities are distinct (different `id`); `colorHex` is the same |

---

## Section 15 — Team Collaboration Extended (TC116–TC125)

**File:** `test/features/teams/team_extended_test.dart`  
**Layer tested:** Invite code edge cases, task assignment mutations, version handling

---

### TC116 — Invite code with lowercase letters is rejected

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Input validation |
| **Test Steps** | 1. Validate `'abc123'` and `'Abc123'` against `^[A-Z0-9]{6}$` |
| **Expected Outcome** | Both fail — lowercase is not permitted |

---

### TC117 — Invite code with special characters is rejected

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Input validation |
| **Test Steps** | 1. Validate `'AB-123'`, `'ABC 23'`, `'AB!123'` |
| **Expected Outcome** | All fail — hyphens, spaces, punctuation are not valid |

---

### TC118 — All-digit invite code is valid

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Input validation |
| **Test Steps** | 1. Validate `'123456'` |
| **Expected Outcome** | Passes — digits satisfy `[A-Z0-9]{6}` |

---

### TC119 — Team tasks can be filtered from a combined list

| Field | Value |
|-------|-------|
| **Feature** | Team Tasks |
| **Layer** | Data model |
| **Test Steps** | 1. Filter 5 tasks (2 personal + 3 team) by `teamId != null` |
| **Expected Outcome** | 3 team tasks returned; all have non-null `teamId` |

---

### TC120 — Personal task count in combined list is correct

| Field | Value |
|-------|-------|
| **Feature** | Unified Task View |
| **Layer** | Data model |
| **Test Steps** | 1. Filter combined list by `teamId == null` |
| **Expected Outcome** | Exactly 2 personal tasks |

---

### TC121 — Task reassignment changes assignedTo via copyWith

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(assignedTo: 'member-B')` on a task assigned to `'member-A'` |
| **Expected Outcome** | `assignedTo` updated to `member-B`; original unchanged |

---

### TC122 — Task lastModifiedBy field can be set

| Field | Value |
|-------|-------|
| **Feature** | Audit Trail |
| **Layer** | Data model |
| **Test Steps** | 1. Create task with `lastModifiedBy: 'user-editor-55'`<br>2. Create task with no modifier |
| **Expected Outcome** | Present → correct uid; absent → `null` |

---

### TC123 — Team task with null assignedTo is a valid unassigned team task

| Field | Value |
|-------|-------|
| **Feature** | Team Collaboration |
| **Layer** | Data model |
| **Test Steps** | 1. Create task with `teamId` set but `assignedTo: null` |
| **Expected Outcome** | `teamId != null` (is a team task); `assignedTo == null` (unassigned, claimable) |

---

### TC124 — Version 0 is the default initial version

| Field | Value |
|-------|-------|
| **Feature** | Real-time Sync |
| **Layer** | Data model |
| **Test Steps** | 1. Create `TaskEntity` without specifying version<br>2. Increment from 0 to 1 |
| **Expected Outcome** | Default `version == 0`; after increment `version == 1` |

---

### TC125 — Large version numbers increment correctly

| Field | Value |
|-------|-------|
| **Feature** | Real-time Sync |
| **Layer** | Data model |
| **Test Steps** | 1. Call `copyWith(version: 1000)` on a task at `version: 999` |
| **Expected Outcome** | `version == 1000` — no integer overflow |

---

## Section 16 — LRU Cache Extended (TC126–TC135)

**File:** `test/core/lru_cache_extended_test.dart`  
**Layer tested:** `LruCache<K,V>` edge cases and value types

---

### TC126 — Cache with capacity 1 evicts previous entry on every put

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Put `'a'` then `'b'` into capacity-1 cache |
| **Expected Outcome** | `'a'` evicted after `'b'` inserted; only `'b'` retrievable |

---

### TC127 — keys() returns all currently cached keys

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Insert 3 entries; call `keys()` |
| **Expected Outcome** | All 3 keys present; `keys().length == 3` |

---

### TC128 — remove on a non-existent key returns null

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Call `cache.remove('ghost')` on an empty cache |
| **Expected Outcome** | Returns `null` without throwing |

---

### TC129 — Removed entry can be re-inserted without side effects

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Put `'a'` and `'b'`; remove `'a'`; re-insert `'a'` with new value |
| **Expected Outcome** | `cache.get('a') == 99`; `'b'` still present; `length == 2` |

---

### TC130 — Repeated get on same key does not grow the cache

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Put one entry; call `get` 100 times |
| **Expected Outcome** | `length == 1` — reads never increase cache size |

---

### TC131 — Evicted key can be re-inserted after eviction

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Fill capacity-2 cache; evict `'a'`; re-insert `'a'` |
| **Expected Outcome** | `cache.get('a') == 100`; `length == 2` |

---

### TC132 — Cache handles boolean values correctly

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Put `true` and `false` values; retrieve both |
| **Expected Outcome** | `false` is distinguishable from a cache miss (`null`) |

---

### TC133 — Capacity-1 cache always holds exactly one entry

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Put 10 entries sequentially into a capacity-1 cache |
| **Expected Outcome** | `length == 1`; only key `9` (last inserted) is retrievable |

---

### TC134 — values() on an empty cache returns an empty iterable

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Call `values()` on a freshly created empty cache |
| **Expected Outcome** | Returns an empty iterable (not `null`) |

---

### TC135 — containsKey returns false after the entry is removed

| Field | Value |
|-------|-------|
| **Feature** | Offline Mode |
| **Layer** | Data (LruCache) |
| **Test Steps** | 1. Insert entry; verify `containsKey == true`<br>2. Remove it; verify `containsKey == false` |
| **Expected Outcome** | `containsKey` immediately reflects the removal |

---

## Section 17 — Security & Data Integrity Extended (TC136–TC150)

**File:** `test/core/security_extended_test.dart`  
**Layer tested:** Firestore path isolation, field-level ownership markers, structural integrity

---

### TC136 — NoteEntity includes userId in toFirestore for ownership

| Field | Value |
|-------|-------|
| **Feature** | Security |
| **Layer** | Data model |
| **Test Steps** | 1. Check `toFirestore()['userId']` on notes for Alice and Bob |
| **Expected Outcome** | Each note's map carries its owner's uid; the two values differ |

---

### TC137 — Domain collection path is isolated by user uid

| Field | Value |
|-------|-------|
| **Feature** | Security |
| **Layer** | Data (Firestore path) |
| **Test Steps** | 1. Build `users/{uid}/domains` path<br>2. Compare paths for two users |
| **Expected Outcome** | Path starts with `users/` and ends with `/domains`; two users produce distinct paths |

---

### TC138 — Habit toMap includes user_id for ownership

| Field | Value |
|-------|-------|
| **Feature** | Security |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toMap()` and inspect `user_id` field |
| **Expected Outcome** | `user_id` matches the Habit model's `userId` |

---

### TC139 — CalendarEventEntity includes userId in toFirestore

| Field | Value |
|-------|-------|
| **Feature** | Security |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` and inspect `userId` field |
| **Expected Outcome** | `userId` is present with the correct owner value |

---

### TC140 — Merging personal and team tasks produces no duplicates

| Field | Value |
|-------|-------|
| **Feature** | Unified Task View |
| **Layer** | Data model |
| **Test Steps** | 1. Merge 3 personal + 2 team tasks<br>2. Check for duplicate ids |
| **Expected Outcome** | `combined.length == 5`; all 5 ids are unique |

---

### TC141 — Team task collection path uses teams namespace

| Field | Value |
|-------|-------|
| **Feature** | Security |
| **Layer** | Data (Firestore path) |
| **Test Steps** | 1. Build `teams/{teamId}/tasks` path<br>2. Verify prefix |
| **Expected Outcome** | Starts with `teams/`; does NOT start with `users/`; two teams produce distinct paths |

---

### TC142 — Note collection path uses personal namespace

| Field | Value |
|-------|-------|
| **Feature** | Security |
| **Layer** | Data (Firestore path) |
| **Test Steps** | 1. Build `users/{uid}/notes` path |
| **Expected Outcome** | Path contains `uid` and ends with `/notes` |

---

### TC143 — TaskEntity toFirestore does not expose raw userId

| Field | Value |
|-------|-------|
| **Feature** | Security |
| **Layer** | Data model |
| **Test Steps** | 1. Call `toFirestore()` on a task; check for `userId` key |
| **Expected Outcome** | Map does NOT contain `userId` — ownership enforced by path, not document content |

---

### TC144 — Tasks from different domains do not share domainId

| Field | Value |
|-------|-------|
| **Feature** | Domain Isolation |
| **Layer** | Data model |
| **Test Steps** | 1. Filter all-tasks list by `domainId == 'health'` |
| **Expected Outcome** | Only health tasks returned; no career tasks in result |

---

### TC145 — Task version increment is always positive

| Field | Value |
|-------|-------|
| **Feature** | Real-time Sync |
| **Layer** | Data model |
| **Test Steps** | 1. For versions `0, 1, 5, 42, 999` — bump each by +1 and assert result is strictly greater |
| **Expected Outcome** | `updated.version > original.version` for all starting values |

---

### TC146 — CalendarEvent assignedMemberIds is always a list type

| Field | Value |
|-------|-------|
| **Feature** | Team Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Create event with empty `assignedMemberIds: []`; check type |
| **Expected Outcome** | `assignedMemberIds` is `List<String>`, never `null` |

---

### TC147 — Empty assignedMemberIds is a valid event state

| Field | Value |
|-------|-------|
| **Feature** | Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Create personal event with no members |
| **Expected Outcome** | `assignedMemberIds.isEmpty == true`; `isTeamEvent == false` |

---

### TC148 — Team event with empty assignedMemberIds is still valid

| Field | Value |
|-------|-------|
| **Feature** | Team Calendar |
| **Layer** | Data model |
| **Test Steps** | 1. Create team event with `assignedMemberIds: []` and `teamId` set |
| **Expected Outcome** | `isTeamEvent == true` (based on `eventType + teamId`); `assignedMemberIds` empty |

---

### TC149 — Task domainId is preserved through Firestore round-trip

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model |
| **Test Steps** | 1. `toFirestore()` then `fromFirestore()` on task with `domainId='domain-career'` |
| **Expected Outcome** | `domainId == 'domain-career'` after deserialization; field is never empty |

---

### TC150 — Task priority enum ordering (high > medium > low)

| Field | Value |
|-------|-------|
| **Feature** | Task Management |
| **Layer** | Data model |
| **Test Steps** | 1. Compare `priorityOrder` indices for all three values<br>2. Assert all enum values are distinct |
| **Expected Outcome** | `high` has lower index than `medium`; `medium` lower than `low`; all three are distinct |

---

## Appendix — Architecture Coverage Matrix

| Architecture Layer | Covered By |
|--------------------|-----------|
| **Data Layer — Entity serialization** | TC15, TC25, TC30, TC39, TC43, TC73–TC75, TC82, TC84, TC94, TC99–TC102, TC111–TC115, TC149 |
| **Data Layer — copyWith mutations** | TC09, TC17, TC61–TC65, TC76–TC77, TC96–TC98, TC105–TC109, TC121 |
| **Data Layer — Offline cache (LruCache)** | TC49, TC126–TC135 |
| **Data Layer — Firestore path security** | TC50, TC136–TC143 |
| **Business Logic — BLoC (TasksBloc)** | TC11, TC12, TC13, TC19 |
| **Business Logic — Cubit (DomainCubit)** | TC06, TC07, TC08, TC10 |
| **Business Logic — Cubit (NotesCubit)** | TC21, TC22 |
| **Business Logic — Habit model logic** | TC26–TC33, TC86–TC95 |
| **Presentation State** | TC10, TC19 (state assertions) |
| **Domain Model — Filtering / Sorting** | TC14, TC18, TC20, TC23, TC24, TC48, TC66–TC70, TC78, TC79, TC85, TC103, TC110, TC119, TC120, TC144 |
| **Domain Model — Computed properties** | TC16, TC26–TC29, TC31, TC36, TC38, TC44–TC47, TC91, TC93, TC146–TC148 |
| **Validation** | TC01, TC04, TC05, TC34, TC51–TC57, TC116–TC118 |
| **Error Handling** | TC02, TC03, TC60 |
| **Team Collaboration** | TC34–TC43, TC116–TC125 |
| **Calendar** | TC44–TC48, TC96–TC105 |
| **Gamification** | TC03, TC27, TC30, TC31, TC58, TC59 |
| **Security / Ownership** | TC50, TC81, TC88–TC90, TC136–TC150 |
| **Audit Trail** | TC65, TC75, TC122 |
| **Version / Conflict Detection** | TC40, TC64, TC74, TC124, TC125, TC145 |

---

## Running the Tests

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/features/tasks/tasks_bloc_test.dart

# Run with verbose output
flutter test --reporter=expanded

# Run with coverage (requires lcov)
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html
```

> Tests that require a Firebase emulator (auth sign-in, Firestore read/write,
> Cloud Functions) should be run separately with `firebase emulators:start` and
> a dedicated integration test suite.
