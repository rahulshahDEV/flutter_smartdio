import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../cache_manager.dart';

/// Hive-based persistent cache store that survives app restarts
class HiveCacheStore implements CacheStore {
  static const String _boxName = 'smartdio_cache';
  
  Box<String>? _cacheBox;
  bool _isInitialized = false;

  /// Initialize Hive and open cache boxes
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize Hive with platform-specific path
    if (kIsWeb) {
      // On web, Hive doesn't need a specific path
      Hive.init('.');
    } else {
      // On other platforms, use Flutter-specific initialization
      await Hive.initFlutter('smartdio_cache');
    }
    
    // Open cache box
    _cacheBox = await Hive.openBox<String>(_boxName);
    
    _isInitialized = true;
    
    // Clean expired entries on startup
    await _cleanExpiredEntries();
  }

  @override
  Future<CacheEntry?> get(String key) async {
    await _ensureInitialized();
    
    final data = _cacheBox!.get(key);
    if (data == null) {
      return null;
    }
    
    // Parse the cached entry
    try {
      final jsonData = jsonDecode(data);
      final entry = CacheEntry.fromJson(jsonData);
      
      // Check if entry is expired
      if (entry.isExpired) {
        await remove(key);
        return null;
      }
      
      return entry;
    } catch (e) {
      // Remove corrupted entry
      await remove(key);
      return null;
    }
  }

  @override
  Future<void> set(String key, CacheEntry entry) async {
    await _ensureInitialized();
    
    // Store the entry as JSON string
    try {
      final jsonString = jsonEncode(entry.toJson());
      await _cacheBox!.put(key, jsonString);
    } catch (e) {
      // If encoding fails, don't cache
      return;
    }
  }

  @override
  Future<void> remove(String key) async {
    await _ensureInitialized();
    
    await _cacheBox!.delete(key);
  }

  @override
  Future<void> clear() async {
    await _ensureInitialized();
    
    await _cacheBox!.clear();
  }

  @override
  Future<List<String>> keys() async {
    await _ensureInitialized();
    
    return _cacheBox!.keys.cast<String>().toList();
  }

  Future<int> size() async {
    await _ensureInitialized();
    
    return _cacheBox!.length;
  }

  Future<bool> containsKey(String key) async {
    await _ensureInitialized();
    
    return _cacheBox!.containsKey(key);
  }

  @override
  Future<void> cleanup() async {
    await _cleanExpiredEntries();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    await _ensureInitialized();
    
    final keys = await this.keys();
    int validEntries = 0;
    int expiredEntries = 0;
    int totalSize = 0;
    
    for (final key in keys) {
      final data = _cacheBox!.get(key);
      if (data != null) {
        totalSize += data.length;
        
        try {
          final jsonData = jsonDecode(data);
          final entry = CacheEntry.fromJson(jsonData);
          
          if (entry.isExpired) {
            expiredEntries++;
          } else {
            validEntries++;
          }
        } catch (e) {
          // Corrupted entry
          expiredEntries++;
        }
      }
    }
    
    return {
      'totalEntries': keys.length,
      'validEntries': validEntries,
      'expiredEntries': expiredEntries,
      'totalSizeBytes': totalSize,
      'boxPath': _cacheBox?.path ?? 'Unknown',
    };
  }

  /// Clean up expired cache entries
  Future<void> _cleanExpiredEntries() async {
    await _ensureInitialized();
    
    final keys = await this.keys();
    final expiredKeys = <String>[];
    
    for (final key in keys) {
      final data = _cacheBox!.get(key);
      if (data != null) {
        try {
          final jsonData = jsonDecode(data);
          final entry = CacheEntry.fromJson(jsonData);
          
          if (entry.isExpired) {
            expiredKeys.add(key);
          }
        } catch (e) {
          // Corrupted entry, mark for removal
          expiredKeys.add(key);
        }
      }
    }
    
    // Remove expired entries
    for (final key in expiredKeys) {
      await remove(key);
    }
  }

  /// Ensure cache is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Close the cache store and release resources
  Future<void> close() async {
    await _cacheBox?.close();
    _isInitialized = false;
  }

  /// Compact the database to reclaim space
  Future<void> compact() async {
    await _ensureInitialized();
    
    await _cacheBox!.compact();
  }
}