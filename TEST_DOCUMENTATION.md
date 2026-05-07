# LifeStable — Automated Test Documentation

## Overview

This document describes all 50 automated test cases for the LifeStable project.
Tests are implemented in Dart using `flutter_test`, `bloc_test`, and `mocktail`.
No Firebase emulator or live connection is required to run the test suite.

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

## Appendix — Architecture Coverage Matrix

| Architecture Layer | Covered By |
|--------------------|-----------|
| **Data Layer — Entity serialization** | TC15, TC25, TC30, TC39, TC43 |
| **Data Layer — Offline cache** | TC49 |
| **Data Layer — Firestore path security** | TC50 |
| **Business Logic — BLoC (TasksBloc)** | TC11, TC12, TC13, TC19 |
| **Business Logic — Cubit (DomainCubit)** | TC06, TC07, TC08, TC10 |
| **Business Logic — Cubit (NotesCubit)** | TC21, TC22 |
| **Business Logic — Habit model logic** | TC26–TC33 |
| **Presentation State** | TC10, TC19 (state assertions) |
| **Domain Model — Filtering / Sorting** | TC14, TC18, TC20, TC23, TC24, TC48 |
| **Domain Model — Computed properties** | TC16, TC26–TC29, TC31, TC36, TC38, TC44–TC47 |
| **Validation** | TC01, TC04, TC05, TC34 |
| **Error Handling** | TC02, TC03 |
| **Team Collaboration** | TC34–TC43 |
| **Calendar** | TC44–TC48 |
| **Gamification** | TC03, TC27, TC30, TC31 |

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
