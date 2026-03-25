import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/entities/calendar_event_entity.dart';
import '../domain/repositories/calendar_repository.dart';

/// Merges the current user's personal calendar events with every team they
/// belong to — all as a single real-time stream.
///
/// Personal events  → users/{uid}/calendar_events
/// Team events      → teams/{teamId}/calendar_events
class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  // ── Write helpers ─────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _personalCol =>
      _db.collection('users').doc(_uid).collection('calendar_events');

  CollectionReference<Map<String, dynamic>> _teamCol(String teamId) =>
      _db.collection('teams').doc(teamId).collection('calendar_events');

  // ── Repository contract ───────────────────────────────────────────────────

  @override
  Stream<List<CalendarEventEntity>> watchEventsForMonth(DateTime month) {
    // Build ISO date bounds for the query window.
    final start = DateTime(month.year, month.month, 1).toIso8601String();
    final end =
    DateTime(month.year, month.month + 1, 0, 23, 59, 59).toIso8601String();

    // We push every update through a broadcast StreamController so callers
    // get a single merged stream regardless of how many team subs we open.
    late StreamController<List<CalendarEventEntity>> controller;

    List<CalendarEventEntity> _personal = [];
    final Map<String, List<CalendarEventEntity>> _teamMap = {};

    StreamSubscription<QuerySnapshot>? _personalSub;
    final List<StreamSubscription<QuerySnapshot>> _teamSubs = [];

    void _push() {
      final merged = <CalendarEventEntity>[
        ..._personal,
        for (final list in _teamMap.values) ...list,
      ];
      merged.sort((a, b) => a.startAt.compareTo(b.startAt));
      if (!controller.isClosed) controller.add(merged);
    }

    Future<void> _setup() async {
      // 1 — Personal events stream
      _personalSub = _personalCol
          .where('startAt', isGreaterThanOrEqualTo: start)
          .where('startAt', isLessThanOrEqualTo: end)
          .orderBy('startAt')
          .snapshots()
          .listen(
            (snap) {
          _personal = snap.docs
              .map((d) => CalendarEventEntity.fromFirestore(
            d.id,
            d.data(),
            source: EventSourceCollection.personal,
          ))
              .toList();
          _push();
        },
        onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        },
      );

      // 2 — Team events streams (one per team)
      try {
        final memberSnap = await _db
            .collection('team_members')
            .where('user_id', isEqualTo: _uid)
            .get();

        for (final memberDoc in memberSnap.docs) {
          final teamId = memberDoc.data()['team_id'] as String? ?? '';
          if (teamId.isEmpty) continue;
          _teamMap[teamId] = [];

          final sub = _teamCol(teamId)
              .where('startAt', isGreaterThanOrEqualTo: start)
              .where('startAt', isLessThanOrEqualTo: end)
              .orderBy('startAt')
              .snapshots()
              .listen(
                (snap) {
              _teamMap[teamId] = snap.docs
                  .map((d) => CalendarEventEntity.fromFirestore(
                d.id,
                d.data(),
                source: EventSourceCollection.team,
              ))
                  .toList();
              _push();
            },
            onError: (_) {/* ignore individual team errors */},
          );
          _teamSubs.add(sub);
        }
      } catch (_) {
        // If we can't load teams, fall back to personal-only.
      }
    }

    controller = StreamController<List<CalendarEventEntity>>(
      onListen: () => _setup(),
      onCancel: () {
        _personalSub?.cancel();
        for (final s in _teamSubs) {
          s.cancel();
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<void> createPersonalEvent(CalendarEventEntity event) async {
    final data = event.toFirestore();
    data['userId'] = _uid;
    await _personalCol.add(data);
  }

  @override
  Future<void> createTeamEvent(CalendarEventEntity event) async {
    assert(event.teamId != null, 'teamId must be set for team events');
    final data = event.toFirestore();
    data['userId'] = _uid; // creator
    await _teamCol(event.teamId!).add(data);
  }

  @override
  Future<void> updateEvent(CalendarEventEntity event) {
    final col = event.sourceCollection == EventSourceCollection.team &&
        event.teamId != null
        ? _teamCol(event.teamId!)
        : _personalCol;
    return col.doc(event.id).update(event.toFirestore());
  }

  @override
  Future<void> deleteEvent(CalendarEventEntity event) {
    final col = event.sourceCollection == EventSourceCollection.team &&
        event.teamId != null
        ? _teamCol(event.teamId!)
        : _personalCol;
    return col.doc(event.id).delete();
  }
}