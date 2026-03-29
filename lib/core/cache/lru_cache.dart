
/// Simple in-memory LRU (least recently used) cache.
///
/// - Reads (`get`) mark an entry as most recently used.
/// - Writes (`put`) update or insert and evict the least recently used entry
///   when capacity is exceeded.
class LruCache<K, V> {
  LruCache({required this.capacity}) : assert(capacity > 0, 'capacity must be > 0');

  final int capacity;

  final _entries = <K, V>{};

  V? get(K key) {
    if (!_entries.containsKey(key)) {
      return null;
    }

    final value = _entries.remove(key) as V;
    _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    if (_entries.containsKey(key)) {
      _entries.remove(key);
    } else if (_entries.length >= capacity) {
      final oldestKey = _entries.keys.first;
      _entries.remove(oldestKey);
    }

    _entries[key] = value;
  }

  bool containsKey(K key) => _entries.containsKey(key);

  V? remove(K key) => _entries.remove(key);

  Iterable<V> values() => _entries.values;

  Iterable<K> keys() => _entries.keys;

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  bool get isNotEmpty => _entries.isNotEmpty;
}

