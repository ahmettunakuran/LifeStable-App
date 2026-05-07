// ignore_for_file: lines_longer_than_80_chars

/// LRU Cache unit tests — supporting TC49
///
/// Tests the core eviction and access-order behaviour of LruCache<K,V>.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/core/cache/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('put and get a single entry', () {
      final cache = LruCache<String, int>(capacity: 3);
      cache.put('a', 1);
      expect(cache.get('a'), 1);
    });

    test('returns null for a missing key', () {
      final cache = LruCache<String, int>(capacity: 3);
      expect(cache.get('nonexistent'), isNull);
    });

    test('evicts the least-recently-used entry when capacity is exceeded', () {
      final cache = LruCache<String, int>(capacity: 2);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3); // 'a' should be evicted

      expect(cache.get('a'), isNull, reason: "'a' is LRU and must be evicted.");
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
    });

    test('accessing an entry promotes it and saves it from eviction', () {
      final cache = LruCache<String, int>(capacity: 2);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.get('a'); // promotes 'a' → 'b' becomes LRU
      cache.put('c', 3); // 'b' should now be evicted

      expect(cache.get('a'), 1, reason: "'a' was promoted and must survive.");
      expect(cache.get('b'), isNull, reason: "'b' became LRU and must be evicted.");
      expect(cache.get('c'), 3);
    });

    test('put overwrites an existing key without incrementing length', () {
      final cache = LruCache<String, int>(capacity: 3);
      cache.put('x', 10);
      cache.put('x', 99);

      expect(cache.get('x'), 99);
      expect(cache.length, 1);
    });

    test('remove deletes the entry and returns its value', () {
      final cache = LruCache<String, String>(capacity: 5);
      cache.put('key', 'value');
      final removed = cache.remove('key');

      expect(removed, 'value');
      expect(cache.containsKey('key'), isFalse);
    });

    test('values() returns all cached values', () {
      final cache = LruCache<String, int>(capacity: 5);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      expect(cache.values(), containsAll([1, 2, 3]));
    });

    test('length, isEmpty, and isNotEmpty reflect actual state', () {
      final cache = LruCache<String, int>(capacity: 5);
      expect(cache.isEmpty, isTrue);
      expect(cache.isNotEmpty, isFalse);
      expect(cache.length, 0);

      cache.put('x', 1);
      expect(cache.isEmpty, isFalse);
      expect(cache.isNotEmpty, isTrue);
      expect(cache.length, 1);
    });
  });
}
