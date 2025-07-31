import 'dart:async';
import 'package:meta/meta.dart';

@immutable
class RequestMetrics {
  final String correlationId;
  final String method;
  final Uri uri;
  final DateTime startTime;
  final DateTime endTime;
  final Duration totalDuration;
  final Duration? networkDuration;
  final int? statusCode;
  final bool success;
  final bool fromCache;
  final int retryCount;
  final int? responseSize;
  final String? errorType;

  const RequestMetrics({
    required this.correlationId,
    required this.method,
    required this.uri,
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
    this.networkDuration,
    this.statusCode,
    required this.success,
    this.fromCache = false,
    this.retryCount = 0,
    this.responseSize,
    this.errorType,
  });

  Map<String, dynamic> toJson() {
    return {
      'correlationId': correlationId,
      'method': method,
      'uri': uri.toString(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'totalDuration': totalDuration.inMilliseconds,
      'networkDuration': networkDuration?.inMilliseconds,
      'statusCode': statusCode,
      'success': success,
      'fromCache': fromCache,
      'retryCount': retryCount,
      'responseSize': responseSize,
      'errorType': errorType,
    };
  }

  @override
  String toString() {
    return 'RequestMetrics(${method.toUpperCase()} ${uri.path}, ${totalDuration.inMilliseconds}ms, success: $success)';
  }
}

@immutable
class CacheMetrics {
  final int hitCount;
  final int missCount;
  final int evictionCount;
  final int totalRequests;
  final double hitRate;
  final int storageSize;
  final DateTime lastReset;

  const CacheMetrics({
    required this.hitCount,
    required this.missCount,
    required this.evictionCount,
    required this.totalRequests,
    required this.hitRate,
    required this.storageSize,
    required this.lastReset,
  });

  Map<String, dynamic> toJson() {
    return {
      'hitCount': hitCount,
      'missCount': missCount,
      'evictionCount': evictionCount,
      'totalRequests': totalRequests,
      'hitRate': hitRate,
      'storageSize': storageSize,
      'lastReset': lastReset.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'CacheMetrics(hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, hits: $hitCount, misses: $missCount)';
  }
}

@immutable
class QueueMetrics {
  final int currentSize;
  final int totalProcessed;
  final int totalFailed;
  final int totalExpired;
  final double successRate;
  final Duration averageWaitTime;
  final DateTime lastReset;

  const QueueMetrics({
    required this.currentSize,
    required this.totalProcessed,
    required this.totalFailed,
    required this.totalExpired,
    required this.successRate,
    required this.averageWaitTime,
    required this.lastReset,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentSize': currentSize,
      'totalProcessed': totalProcessed,
      'totalFailed': totalFailed,
      'totalExpired': totalExpired,
      'successRate': successRate,
      'averageWaitTime': averageWaitTime.inMilliseconds,
      'lastReset': lastReset.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'QueueMetrics(size: $currentSize, processed: $totalProcessed, successRate: ${(successRate * 100).toStringAsFixed(1)}%)';
  }
}

@immutable
sealed class MetricsEvent {
  const MetricsEvent();

  const factory MetricsEvent.requestCompleted(RequestMetrics metrics) = RequestCompletedEvent;
  const factory MetricsEvent.cacheHit(String correlationId, String key) = CacheHitEvent;
  const factory MetricsEvent.cacheMiss(String correlationId, String key) = CacheMissEvent;
  const factory MetricsEvent.cacheEviction(String key) = CacheEvictionEvent;
  const factory MetricsEvent.queueItemAdded(String correlationId) = QueueItemAddedEvent;
  const factory MetricsEvent.queueItemProcessed(String correlationId, bool success) = QueueItemProcessedEvent;
  const factory MetricsEvent.queueItemExpired(String correlationId) = QueueItemExpiredEvent;
  const factory MetricsEvent.custom(String name, Map<String, dynamic> data) = CustomMetricsEvent;
}

@immutable
final class RequestCompletedEvent extends MetricsEvent {
  final RequestMetrics metrics;
  const RequestCompletedEvent(this.metrics);
}

@immutable
final class CacheHitEvent extends MetricsEvent {
  final String correlationId;
  final String key;
  const CacheHitEvent(this.correlationId, this.key);
}

@immutable
final class CacheMissEvent extends MetricsEvent {
  final String correlationId;
  final String key;
  const CacheMissEvent(this.correlationId, this.key);
}

@immutable
final class CacheEvictionEvent extends MetricsEvent {
  final String key;
  const CacheEvictionEvent(this.key);
}

@immutable
final class QueueItemAddedEvent extends MetricsEvent {
  final String correlationId;
  const QueueItemAddedEvent(this.correlationId);
}

@immutable
final class QueueItemProcessedEvent extends MetricsEvent {
  final String correlationId;
  final bool success;
  const QueueItemProcessedEvent(this.correlationId, this.success);
}

@immutable
final class QueueItemExpiredEvent extends MetricsEvent {
  final String correlationId;
  const QueueItemExpiredEvent(this.correlationId);
}

@immutable
final class CustomMetricsEvent extends MetricsEvent {
  final String name;
  final Map<String, dynamic> data;
  const CustomMetricsEvent(this.name, this.data);
}

class PerformanceMetrics {
  final StreamController<MetricsEvent> _eventController;
  final List<RequestMetrics> _requestHistory;
  final Map<String, int> _methodCounts;
  final Map<int, int> _statusCounts;
  
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _cacheEvictions = 0;
  int _queueAdded = 0;
  int _queueProcessed = 0;
  int _queueFailed = 0;
  int _queueExpired = 0;
  
  DateTime _startTime;
  final Duration _historyRetention;

  PerformanceMetrics({
    Duration historyRetention = const Duration(hours: 24),
  }) : _eventController = StreamController<MetricsEvent>.broadcast(),
       _requestHistory = [],
       _methodCounts = {},
       _statusCounts = {},
       _startTime = DateTime.now(),
       _historyRetention = historyRetention;

  Stream<MetricsEvent> get events => _eventController.stream;

  void recordRequest(RequestMetrics metrics) {
    _requestHistory.add(metrics);
    _methodCounts[metrics.method] = (_methodCounts[metrics.method] ?? 0) + 1;
    
    if (metrics.statusCode != null) {
      _statusCounts[metrics.statusCode!] = (_statusCounts[metrics.statusCode!] ?? 0) + 1;
    }

    _cleanupHistory();
    _emitEvent(MetricsEvent.requestCompleted(metrics));
  }

  void recordCacheHit(String correlationId, String key) {
    _cacheHits++;
    _emitEvent(MetricsEvent.cacheHit(correlationId, key));
  }

  void recordCacheMiss(String correlationId, String key) {
    _cacheMisses++;
    _emitEvent(MetricsEvent.cacheMiss(correlationId, key));
  }

  void recordCacheEviction(String key) {
    _cacheEvictions++;
    _emitEvent(MetricsEvent.cacheEviction(key));
  }

  void recordQueueItemAdded(String correlationId) {
    _queueAdded++;
    _emitEvent(MetricsEvent.queueItemAdded(correlationId));
  }

  void recordQueueItemProcessed(String correlationId, bool success) {
    _queueProcessed++;
    if (!success) _queueFailed++;
    _emitEvent(MetricsEvent.queueItemProcessed(correlationId, success));
  }

  void recordQueueItemExpired(String correlationId) {
    _queueExpired++;
    _emitEvent(MetricsEvent.queueItemExpired(correlationId));
  }

  void recordCustomMetric(String name, Map<String, dynamic> data) {
    _emitEvent(MetricsEvent.custom(name, data));
  }

  RequestMetrics? getLatestRequest() {
    return _requestHistory.isNotEmpty ? _requestHistory.last : null;
  }

  List<RequestMetrics> getRequestHistory({Duration? since}) {
    if (since == null) return List.unmodifiable(_requestHistory);
    
    final cutoff = DateTime.now().subtract(since);
    return _requestHistory
        .where((r) => r.startTime.isAfter(cutoff))
        .toList();
  }

  CacheMetrics getCacheMetrics() {
    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? _cacheHits / totalRequests : 0.0;

    return CacheMetrics(
      hitCount: _cacheHits,
      missCount: _cacheMisses,
      evictionCount: _cacheEvictions,
      totalRequests: totalRequests,
      hitRate: hitRate,
      storageSize: 0,
      lastReset: _startTime,
    );
  }

  QueueMetrics getQueueMetrics(int currentQueueSize) {
    final successRate = _queueProcessed > 0 
        ? (_queueProcessed - _queueFailed) / _queueProcessed 
        : 0.0;

    return QueueMetrics(
      currentSize: currentQueueSize,
      totalProcessed: _queueProcessed,
      totalFailed: _queueFailed,
      totalExpired: _queueExpired,
      successRate: successRate,
      averageWaitTime: Duration.zero,
      lastReset: _startTime,
    );
  }

  Map<String, int> getMethodStats() => Map.unmodifiable(_methodCounts);
  
  Map<int, int> getStatusStats() => Map.unmodifiable(_statusCounts);

  double getSuccessRate({Duration? period}) {
    final requests = getRequestHistory(since: period);
    if (requests.isEmpty) return 0.0;
    
    final successful = requests.where((r) => r.success).length;
    return successful / requests.length;
  }

  Duration getAverageResponseTime({Duration? period}) {
    final requests = getRequestHistory(since: period);
    if (requests.isEmpty) return Duration.zero;
    
    final totalMs = requests
        .map((r) => r.totalDuration.inMilliseconds)
        .reduce((a, b) => a + b);
    
    return Duration(milliseconds: (totalMs / requests.length).round());
  }

  void reset() {
    _requestHistory.clear();
    _methodCounts.clear();
    _statusCounts.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
    _cacheEvictions = 0;
    _queueAdded = 0;
    _queueProcessed = 0;
    _queueFailed = 0;
    _queueExpired = 0;
    _startTime = DateTime.now();
  }

  void _cleanupHistory() {
    final cutoff = DateTime.now().subtract(_historyRetention);
    _requestHistory.removeWhere((r) => r.startTime.isBefore(cutoff));
  }

  void _emitEvent(MetricsEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void dispose() {
    _eventController.close();
  }
}