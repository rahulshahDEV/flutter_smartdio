import '../core/smart_dio_request.dart';
import '../core/smart_dio_response.dart';

/// Abstract base class for HTTP client adapters that provide a unified interface
/// for different HTTP clients (Dio, HTTP, Chopper).
/// 
/// This adapter pattern allows SmartDioClient to work with any HTTP client
/// by implementing the execute and close methods.
abstract class HttpClientAdapter {
  /// Executes an HTTP request and returns a SmartDioResponse.
  /// 
  /// The [request] contains all the necessary information for the HTTP call.
  /// The [transformer] function is used to convert the response data to type [T].
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  });

  /// Closes the HTTP client and releases any resources.
  Future<void> close();
}

/// Base exception class for all adapter-related errors.
/// 
/// This exception provides context about errors that occur within HTTP adapters,
/// including the original error and stack trace for debugging purposes.
abstract class AdapterException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AdapterException(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() => 'AdapterException: $message';
}

/// Exception thrown when network-related errors occur during HTTP requests.
class NetworkException extends AdapterException {
  const NetworkException(super.message, [super.originalError, super.stackTrace]);
}

/// Exception thrown when HTTP requests exceed their timeout duration.
class TimeoutException extends AdapterException {
  const TimeoutException(super.message, [super.originalError, super.stackTrace]);
}

class CancelledException extends AdapterException {
  const CancelledException(super.message, [super.originalError, super.stackTrace]);
}

class BadResponseException extends AdapterException {
  final int statusCode;
  final Map<String, String> headers;

  const BadResponseException(
    super.message,
    this.statusCode,
    this.headers, [
    super.originalError,
    super.stackTrace,
  ]);
}

class UnknownException extends AdapterException {
  const UnknownException(super.message, [super.originalError, super.stackTrace]);
}