import '../core/smart_dio_request.dart';
import '../core/smart_dio_response.dart';

abstract class HttpClientAdapter {
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  });

  Future<void> close();
}

abstract class AdapterException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AdapterException(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() => 'AdapterException: $message';
}

class NetworkException extends AdapterException {
  const NetworkException(super.message, [super.originalError, super.stackTrace]);
}

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