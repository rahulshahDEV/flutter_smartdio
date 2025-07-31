import 'package:meta/meta.dart';

/// Sealed class representing the result of an HTTP request execution.
/// 
/// This class can be either a [SmartDioSuccess] for successful responses
/// or a [SmartDioError] for failed responses. It includes metadata about
/// the request execution such as timing, caching, and retry information.
@immutable
sealed class SmartDioResponse<T> {
  final String correlationId;
  final DateTime timestamp;
  final Duration duration;
  final bool isFromCache;
  final int retryCount;

  /// Creates a SmartDioResponse with the specified metadata.
  /// 
  /// [correlationId] links this response to its corresponding request
  /// [timestamp] indicates when the response was received
  /// [duration] shows how long the request took to complete
  const SmartDioResponse({
    required this.correlationId,
    required this.timestamp,
    required this.duration,
    this.isFromCache = false,
    this.retryCount = 0,
  });

  bool get isSuccess => this is SmartDioSuccess<T>;
  bool get isError => this is SmartDioError<T>;

  SmartDioSuccess<T>? get asSuccess => this is SmartDioSuccess<T> ? this as SmartDioSuccess<T> : null;
  SmartDioError<T>? get asError => this is SmartDioError<T> ? this as SmartDioError<T> : null;

  /// Transforms this response into type [R] using the appropriate handler.
  /// 
  /// Calls [onSuccess] if this is a successful response, otherwise calls [onError].
  R fold<R>(
    R Function(SmartDioSuccess<T> success) onSuccess,
    R Function(SmartDioError<T> error) onError,
  ) {
    return switch (this) {
      SmartDioSuccess<T> success => onSuccess(success),
      SmartDioError<T> error => onError(error),
    };
  }

  /// Maps the data of a successful response to type [R].
  /// 
  /// If this is an error response, returns the error unchanged.
  SmartDioResponse<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      SmartDioSuccess<T> success => SmartDioSuccess<R>(
          data: transform(success.data),
          statusCode: success.statusCode,
          headers: success.headers,
          correlationId: correlationId,
          timestamp: timestamp,
          duration: duration,
          isFromCache: isFromCache,
          retryCount: retryCount,
        ),
      SmartDioError<T> error => SmartDioError<R>(
          error: error.error,
          statusCode: error.statusCode,
          headers: error.headers,
          type: error.type,
          correlationId: correlationId,
          timestamp: timestamp,
          duration: duration,
          isFromCache: isFromCache,
          retryCount: retryCount,
        ),
    };
  }

  SmartDioResponse<T> recover(T Function(SmartDioError<T> error) recovery) {
    return switch (this) {
      SmartDioSuccess<T> success => success,
      SmartDioError<T> error => SmartDioSuccess<T>(
          data: recovery(error),
          statusCode: error.statusCode ?? 200,
          headers: error.headers,
          correlationId: correlationId,
          timestamp: timestamp,
          duration: duration,
          isFromCache: isFromCache,
          retryCount: retryCount,
        ),
    };
  }
}

@immutable
final class SmartDioSuccess<T> extends SmartDioResponse<T> {
  final T data;
  final int statusCode;
  final Map<String, String> headers;

  const SmartDioSuccess({
    required this.data,
    required this.statusCode,
    this.headers = const {},
    required super.correlationId,
    required super.timestamp,
    required super.duration,
    super.isFromCache,
    super.retryCount,
  });

  @override
  String toString() {
    return 'SmartDioSuccess(statusCode: $statusCode, correlationId: $correlationId, fromCache: $isFromCache, retries: $retryCount)';
  }
}

@immutable
final class SmartDioError<T> extends SmartDioResponse<T> {
  final Object error;
  final StackTrace? stackTrace;
  final int? statusCode;
  final Map<String, String> headers;
  final SmartDioErrorType type;

  const SmartDioError({
    required this.error,
    this.stackTrace,
    this.statusCode,
    this.headers = const {},
    required this.type,
    required super.correlationId,
    required super.timestamp,
    required super.duration,
    super.isFromCache,
    super.retryCount,
  });

  @override
  String toString() {
    return 'SmartDioError(type: $type, statusCode: $statusCode, error: $error, correlationId: $correlationId, retries: $retryCount)';
  }
}

enum SmartDioErrorType {
  network,
  timeout,
  cancelled,
  badResponse,
  unknown,
}