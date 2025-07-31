import 'dart:async';
import 'package:meta/meta.dart';
import '../core/smart_dio_request.dart';

/// Represents a queued HTTP request waiting to be executed.
/// 
/// This immutable class stores request information along with metadata
/// about when it was queued, retry attempts, and any previous errors.
@immutable
class QueuedRequest {
  final String id;
  final SmartDioRequest request;
  final DateTime queuedAt;
  final int retryCount;
  final DateTime? lastAttempt;
  final Object? lastError;

  /// Creates a QueuedRequest with the specified parameters.
  /// 
  /// [id] is a unique identifier for this queued request
  /// [request] is the HTTP request to be executed
  /// [queuedAt] is when this request was added to the queue
  const QueuedRequest({
    required this.id,
    required this.request,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastAttempt,
    this.lastError,
  });

  QueuedRequest copyWith({
    String? id,
    SmartDioRequest? request,
    DateTime? queuedAt,
    int? retryCount,
    DateTime? lastAttempt,
    Object? lastError,
  }) {
    return QueuedRequest(
      id: id ?? this.id,
      request: request ?? this.request,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request': {
        'method': request.method,
        'uri': request.uri.toString(),
        'headers': request.headers,
        'body': request.body,
        'timeout': request.timeout?.inMilliseconds,
        'extra': request.extra,
        'correlationId': request.correlationId,
        'tags': request.tags.toList(),
      },
      'queuedAt': queuedAt.toIso8601String(),
      'retryCount': retryCount,
      'lastAttempt': lastAttempt?.toIso8601String(),
      'lastError': lastError?.toString(),
    };
  }

  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    final requestJson = json['request'] as Map<String, dynamic>;
    return QueuedRequest(
      id: json['id'],
      request: SmartDioRequest(
        method: requestJson['method'],
        uri: Uri.parse(requestJson['uri']),
        headers: Map<String, String>.from(requestJson['headers'] ?? {}),
        body: requestJson['body'],
        timeout: requestJson['timeout'] != null 
            ? Duration(milliseconds: requestJson['timeout']) 
            : null,
        extra: Map<String, dynamic>.from(requestJson['extra'] ?? {}),
        correlationId: requestJson['correlationId'],
        tags: Set<String>.from(requestJson['tags'] ?? []),
      ),
      queuedAt: DateTime.parse(json['queuedAt']),
      retryCount: json['retryCount'] ?? 0,
      lastAttempt: json['lastAttempt'] != null 
          ? DateTime.parse(json['lastAttempt']) 
          : null,
      lastError: json['lastError'],
    );
  }

  @override
  String toString() {
    return 'QueuedRequest(id: $id, method: ${request.method}, uri: ${request.uri}, retryCount: $retryCount)';
  }
}

enum QueueStatus {
  idle,
  processing,
  paused,
}

abstract class RequestQueueStorage {
  Future<void> save(List<QueuedRequest> requests);
  Future<List<QueuedRequest>> load();
  Future<void> clear();
}

class RequestQueue {
  final RequestQueueStorage? storage;
  final int maxSize;
  final Duration maxAge;
  final Set<String> queueMethods;
  final StreamController<QueueEvent> _eventController;
  
  final List<QueuedRequest> _queue = [];
  QueueStatus _status = QueueStatus.idle;
  Timer? _cleanupTimer;

  RequestQueue({
    this.storage,
    this.maxSize = 100,
    this.maxAge = const Duration(days: 7),
    this.queueMethods = const {'POST', 'PUT', 'PATCH', 'DELETE'},
  }) : _eventController = StreamController<QueueEvent>.broadcast() {
    _startCleanupTimer();
    _loadFromStorage();
  }

  Stream<QueueEvent> get events => _eventController.stream;
  
  QueueStatus get status => _status;
  
  int get length => _queue.length;
  
  bool get isEmpty => _queue.isEmpty;
  
  bool get isNotEmpty => _queue.isNotEmpty;

  List<QueuedRequest> get requests => List.unmodifiable(_queue);

  bool shouldQueue(SmartDioRequest request) {
    return queueMethods.contains(request.method.toUpperCase());
  }

  Future<void> enqueue(SmartDioRequest request) async {
    if (!shouldQueue(request)) return;

    if (_queue.length >= maxSize) {
      _queue.removeAt(0);
      _emitEvent(QueueEvent.itemEvicted(request.correlationId));
    }

    final queuedRequest = QueuedRequest(
      id: _generateId(),
      request: request,
      queuedAt: DateTime.now(),
    );

    _queue.add(queuedRequest);
    _emitEvent(QueueEvent.itemAdded(queuedRequest));
    await _saveToStorage();
  }

  Future<QueuedRequest?> dequeue() async {
    if (_queue.isEmpty) return null;

    final request = _queue.removeAt(0);
    _emitEvent(QueueEvent.itemRemoved(request));
    await _saveToStorage();
    return request;
  }

  Future<void> remove(String id) async {
    final index = _queue.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final request = _queue.removeAt(index);
    _emitEvent(QueueEvent.itemRemoved(request));
    await _saveToStorage();
  }

  Future<void> retry(String id) async {
    final index = _queue.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final request = _queue[index];
    final updatedRequest = request.copyWith(
      retryCount: request.retryCount + 1,
      lastAttempt: DateTime.now(),
    );

    _queue[index] = updatedRequest;
    _emitEvent(QueueEvent.itemRetried(updatedRequest));
    await _saveToStorage();
  }

  Future<void> markFailed(String id, Object error) async {
    final index = _queue.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final request = _queue[index];
    final updatedRequest = request.copyWith(
      lastAttempt: DateTime.now(),
      lastError: error,
    );

    _queue[index] = updatedRequest;
    _emitEvent(QueueEvent.itemFailed(updatedRequest, error));
    await _saveToStorage();
  }

  Future<void> clear() async {
    final clearedCount = _queue.length;
    _queue.clear();
    _emitEvent(QueueEvent.queueCleared(clearedCount));
    await _saveToStorage();
  }

  Future<void> pause() async {
    _status = QueueStatus.paused;
    _emitEvent(QueueEvent.queuePaused());
  }

  Future<void> resume() async {
    _status = QueueStatus.idle;
    _emitEvent(QueueEvent.queueResumed());
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) => _cleanup());
  }

  Future<void> _cleanup() async {
    final now = DateTime.now();
    final oldCount = _queue.length;

    _queue.removeWhere((request) {
      return now.difference(request.queuedAt) > maxAge;
    });

    final removedCount = oldCount - _queue.length;
    if (removedCount > 0) {
      _emitEvent(QueueEvent.itemsExpired(removedCount));
      await _saveToStorage();
    }
  }

  Future<void> _loadFromStorage() async {
    if (storage == null) return;

    try {
      final requests = await storage!.load();
      _queue.addAll(requests);
      _emitEvent(QueueEvent.queueLoaded(_queue.length));
    } catch (e) {
      _emitEvent(QueueEvent.storageError(e));
    }
  }

  Future<void> _saveToStorage() async {
    if (storage == null) return;

    try {
      await storage!.save(_queue);
    } catch (e) {
      _emitEvent(QueueEvent.storageError(e));
    }
  }

  void _emitEvent(QueueEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_queue.length}';
  }

  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    await _eventController.close();
  }
}

@immutable
sealed class QueueEvent {
  const QueueEvent();

  const factory QueueEvent.itemAdded(QueuedRequest request) = QueueItemAdded;
  const factory QueueEvent.itemRemoved(QueuedRequest request) = QueueItemRemoved;
  const factory QueueEvent.itemRetried(QueuedRequest request) = QueueItemRetried;
  const factory QueueEvent.itemFailed(QueuedRequest request, Object error) = QueueItemFailed;
  const factory QueueEvent.itemEvicted(String correlationId) = QueueItemEvicted;
  const factory QueueEvent.itemsExpired(int count) = QueueItemsExpired;
  const factory QueueEvent.queueCleared(int count) = QueueCleared;
  const factory QueueEvent.queuePaused() = QueuePaused;
  const factory QueueEvent.queueResumed() = QueueResumed;
  const factory QueueEvent.queueLoaded(int count) = QueueLoaded;
  const factory QueueEvent.storageError(Object error) = QueueStorageError;
}

@immutable
final class QueueItemAdded extends QueueEvent {
  final QueuedRequest request;
  const QueueItemAdded(this.request);
}

@immutable
final class QueueItemRemoved extends QueueEvent {
  final QueuedRequest request;
  const QueueItemRemoved(this.request);
}

@immutable
final class QueueItemRetried extends QueueEvent {
  final QueuedRequest request;
  const QueueItemRetried(this.request);
}

@immutable
final class QueueItemFailed extends QueueEvent {
  final QueuedRequest request;
  final Object error;
  const QueueItemFailed(this.request, this.error);
}

@immutable
final class QueueItemEvicted extends QueueEvent {
  final String correlationId;
  const QueueItemEvicted(this.correlationId);
}

@immutable
final class QueueItemsExpired extends QueueEvent {
  final int count;
  const QueueItemsExpired(this.count);
}

@immutable
final class QueueCleared extends QueueEvent {
  final int count;
  const QueueCleared(this.count);
}

@immutable
final class QueuePaused extends QueueEvent {
  const QueuePaused();
}

@immutable
final class QueueResumed extends QueueEvent {
  const QueueResumed();
}

@immutable
final class QueueLoaded extends QueueEvent {
  final int count;
  const QueueLoaded(this.count);
}

@immutable
final class QueueStorageError extends QueueEvent {
  final Object error;
  const QueueStorageError(this.error);
}