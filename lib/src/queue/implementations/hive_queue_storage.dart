import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../request_queue.dart';

/// Hive-based persistent queue storage that survives app restarts
class HiveQueueStorage implements RequestQueueStorage {
  static const String _boxName = 'smartdio_queue';
  
  Box<String>? _queueBox;
  bool _isInitialized = false;

  /// Initialize Hive and open queue box
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize Hive with platform-specific path
    if (kIsWeb) {
      // On web, Hive doesn't need a specific path
      Hive.init('.');
    } else {
      // On other platforms, use Flutter-specific initialization
      await Hive.initFlutter('smartdio_queue');
    }
    
    // Open queue box
    _queueBox = await Hive.openBox<String>(_boxName);
    
    _isInitialized = true;
  }

  @override
  Future<void> save(List<QueuedRequest> requests) async {
    await _ensureInitialized();
    
    try {
      // Clear existing data
      await _queueBox!.clear();
      
      // Save each request with an index key
      for (int i = 0; i < requests.length; i++) {
        final jsonString = jsonEncode(requests[i].toJson());
        await _queueBox!.put('request_$i', jsonString);
      }
    } catch (e) {
      // If encoding fails, don't save
      return;
    }
  }

  @override
  Future<List<QueuedRequest>> load() async {
    await _ensureInitialized();
    
    final requests = <QueuedRequest>[];
    final keys = _queueBox!.keys.cast<String>().toList();
    
    // Sort keys to maintain order
    keys.sort((a, b) {
      final aIndex = int.tryParse(a.split('_').last) ?? 0;
      final bIndex = int.tryParse(b.split('_').last) ?? 0;
      return aIndex.compareTo(bIndex);
    });
    
    for (final key in keys) {
      final data = _queueBox!.get(key);
      if (data != null) {
        try {
          final jsonData = jsonDecode(data);
          final request = QueuedRequest.fromJson(jsonData);
          requests.add(request);
        } catch (e) {
          // Remove corrupted entry
          await _queueBox!.delete(key);
        }
      }
    }
    
    return requests;
  }

  @override
  Future<void> clear() async {
    await _ensureInitialized();
    
    await _queueBox!.clear();
  }

  /// Get queue statistics
  Future<Map<String, dynamic>> getStats() async {
    await _ensureInitialized();
    
    final keys = _queueBox!.keys.cast<String>().toList();
    int validRequests = 0;
    int corruptedRequests = 0;
    int totalSize = 0;
    
    for (final key in keys) {
      final data = _queueBox!.get(key);
      if (data != null) {
        totalSize += data.length;
        
        try {
          final jsonData = jsonDecode(data);
          QueuedRequest.fromJson(jsonData);
          validRequests++;
        } catch (e) {
          corruptedRequests++;
        }
      }
    }
    
    return {
      'totalRequests': keys.length,
      'validRequests': validRequests,
      'corruptedRequests': corruptedRequests,
      'totalSizeBytes': totalSize,
      'boxPath': _queueBox?.path ?? 'Unknown',
    };
  }

  /// Clean up corrupted queue entries
  Future<void> cleanup() async {
    await _ensureInitialized();
    
    final keys = _queueBox!.keys.cast<String>().toList();
    final corruptedKeys = <String>[];
    
    for (final key in keys) {
      final data = _queueBox!.get(key);
      if (data != null) {
        try {
          final jsonData = jsonDecode(data);
          QueuedRequest.fromJson(jsonData);
        } catch (e) {
          // Corrupted entry, mark for removal
          corruptedKeys.add(key);
        }
      }
    }
    
    // Remove corrupted entries
    for (final key in corruptedKeys) {
      await _queueBox!.delete(key);
    }
  }

  /// Get the number of stored requests
  Future<int> size() async {
    await _ensureInitialized();
    
    return _queueBox!.length;
  }

  /// Check if queue storage is empty
  Future<bool> isEmpty() async {
    await _ensureInitialized();
    
    return _queueBox!.isEmpty;
  }

  /// Ensure queue storage is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Close the queue storage and release resources
  Future<void> close() async {
    await _queueBox?.close();
    _isInitialized = false;
  }

  /// Compact the database to reclaim space
  Future<void> compact() async {
    await _ensureInitialized();
    
    await _queueBox!.compact();
  }
}