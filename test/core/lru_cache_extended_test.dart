// ignore_for_file: lines_longer_than_80_chars

/// LRU Cache Extended Tests — TC126 through TC135
///
/// Additional unit tests for LruCache<K,V> covering edge cases:
/// capacity-1 caches, key iterable, boolean value types, removal
/// from non-existent keys, and boundary eviction scenarios.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/core/cache/lru_cache.dart';

void main() {
  group('LruCache Extended', () {
    // TC126 ─────────────────────────────────────────────────────────────────
    test('TC126: cache with capacity 1 evicts previous entry on every put', () {
      final cache = LruCache<String, int>(capacity: 1);
      cache.put('a', 1);
      expect(cache.get('a'), 1);

      cache.put('b', 2); // evicts 'a'
      expect(cache.get('a'), isNull,
          reason: "Previous entry must be evicted when capacity is 1.");
      expect(cache.get('b'), 2);
    });

    // TC127 ─────────────────────────────────────────────────────────────────
    test('TC127: keys() returns all currently cached keys', () {
      final cache = LruCache<String, int>(capacity: 5);
      cache.put('x', 10);
      cache.put('y', 20);
      cache.put('z', 30);

      expect(cache.keys(), containsAll(['x', 'y', 'z']),
          reason: 'All inserted keys must be enumerable via keys().');
      expect(cache.keys().length, 3);
    });

    // TC128 ─────────────────────────────────────────────────────────────────
    test('TC128: remove on a non-existent key returns null', () {
      final cache = LruCache<String, String>(capacity: 3);
      final result = cache.remove('ghost');

      expect(result, isNull,
          reason: 'Removing a key that was never inserted must return null gracefully.');
    });

    // TC129 ─────────────────────────────────────────────────────────────────
    test('TC129: removed entry can be re-inserted without side effects', () {
      final cache = LruCache<String, int>(capacity: 2);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.remove('a');

      // Re-insert 'a' — the cache now has 'b' and 'a'.
      cache.put('a', 99);

      expect(cache.get('a'), 99,
          reason: 'Re-inserted entry must be retrievable with the new value.');
      expect(cache.get('b'), 2);
      expect(cache.length, 2);
    });

    // TC130 ─────────────────────────────────────────────────────────────────
    test('TC130: repeated get on same key does not grow the cache', () {
      final cache = LruCache<String, int>(capacity: 3);
      cache.put('key', 42);

      for (var i = 0; i < 100; i++) {
        cache.get('key');
      }

      expect(cache.length, 1,
          reason: 'Reads must never increase the cache size.');
    });

    // TC131 ─────────────────────────────────────────────────────────────────
    test('TC131: evicted key can be re-inserted after eviction', () {
      final cache = LruCache<String, int>(capacity: 2);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3); // 'a' evicted

      expect(cache.get('a'), isNull);

      // Re-insert 'a' — 'b' becomes LRU and should be evicted.
      cache.put('a', 100);

      expect(cache.get('a'), 100,
          reason: 'Previously evicted key can be re-inserted.');
      expect(cache.length, 2);
    });

    // TC132 ─────────────────────────────────────────────────────────────────
    test('TC132: cache handles boolean values correctly', () {
      final cache = LruCache<String, bool>(capacity: 4);
      cache.put('flag-on', true);
      cache.put('flag-off', false);

      expect(cache.get('flag-on'), isTrue);
      expect(cache.get('flag-off'), isFalse,
          reason: 'false must be distinguishable from a cache miss (null).');
    });

    // TC133 ─────────────────────────────────────────────────────────────────
    test('TC133: capacity-1 cache always holds exactly one entry', () {
      final cache = LruCache<int, String>(capacity: 1);
      for (var i = 0; i < 10; i++) {
        cache.put(i, 'value-$i');
      }

      expect(cache.length, 1,
          reason: 'A capacity-1 cache must never hold more than one entry.');
      expect(cache.get(9), 'value-9',
          reason: 'Only the most recently inserted value must be present.');
    });

    // TC134 ─────────────────────────────────────────────────────────────────
    test('TC134: values() on an empty cache returns an empty iterable', () {
      final cache = LruCache<String, int>(capacity: 5);

      expect(cache.values(), isEmpty,
          reason: 'Empty cache must return an empty values iterable, not null.');
    });

    // TC135 ─────────────────────────────────────────────────────────────────
    test('TC135: containsKey returns false after the entry is removed', () {
      final cache = LruCache<String, int>(capacity: 3);
      cache.put('present', 1);
      expect(cache.containsKey('present'), isTrue);

      cache.remove('present');
      expect(cache.containsKey('present'), isFalse,
          reason: 'containsKey must reflect the removal immediately.');
    });
  });
}
