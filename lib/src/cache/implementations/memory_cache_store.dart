import 'dart:async';
import '../cache_manager.dart';

class MemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry> _cache = {};
  final int _maxSize;
  Timer? _cleanupTimer;

  MemoryCacheStore({
    int maxSize = 1000,
    Duration cleanupInterval = const Duration(minutes: 5),
  }) : _maxSize = maxSize {
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) => cleanup());
  }

  @override
  Future<CacheEntry?> get(String key) async {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry;
  }

  @override
  Future<void> set(String key, CacheEntry entry) async {
    if (_cache.length >= _maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[key] = entry;
  }

  @override
  Future<void> remove(String key) async {
    _cache.remove(key);
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  @override
  Future<List<String>> keys() async {
    return _cache.keys.toList();
  }

  @override
  Future<void> cleanup() async {
    final expiredKeys = <String>[];
    
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}