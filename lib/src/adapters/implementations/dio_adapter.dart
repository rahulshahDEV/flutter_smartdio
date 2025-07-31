import 'package:dio/dio.dart' hide HttpClientAdapter;
import '../../core/smart_dio_request.dart';
import '../../core/smart_dio_response.dart';
import '../http_client_adapter.dart';

class DioClientAdapter extends HttpClientAdapter {
  final Dio _dio;
  final bool _closeDioOnDispose;

  DioClientAdapter({
    Dio? dioInstance,
  })  : _dio = dioInstance ?? Dio(),
        _closeDioOnDispose = dioInstance == null {
    // Set default headers to avoid 403 errors
    _dio.options.headers.addAll({
      'User-Agent': 'SmartDio Flutter App/1.0 (Dio)',
      'Accept': 'application/json',
    });
  }

  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    final startTime = DateTime.now();

    try {
      final options = Options(
        method: request.method,
        headers: request.headers,
        sendTimeout: request.timeout,
        receiveTimeout: request.timeout,
      );

      final response = await _dio.request(
        request.uri.toString(),
        data: request.body,
        options: options,
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      return SmartDioSuccess<T>(
        data: transformer(response.data),
        statusCode: response.statusCode ?? 200,
        headers: _extractHeaders(response.headers),
        correlationId: request.correlationId,
        timestamp: endTime,
        duration: duration,
      );
    } on DioException catch (e, stackTrace) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      return SmartDioError<T>(
        error: _mapDioException(e),
        stackTrace: stackTrace,
        statusCode: e.response?.statusCode,
        headers: e.response?.headers != null 
            ? _extractHeaders(e.response!.headers) 
            : {},
        type: _mapDioErrorType(e),
        correlationId: request.correlationId,
        timestamp: endTime,
        duration: duration,
      );
    } catch (e, stackTrace) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      return SmartDioError<T>(
        error: UnknownException('Unexpected error: $e', e, stackTrace),
        stackTrace: stackTrace,
        type: SmartDioErrorType.unknown,
        correlationId: request.correlationId,
        timestamp: endTime,
        duration: duration,
      );
    }
  }

  Map<String, String> _extractHeaders(Headers headers) {
    final headerMap = <String, String>{};
    headers.forEach((name, values) {
      if (values.isNotEmpty) {
        headerMap[name] = values.join(', ');
      }
    });
    return headerMap;
  }

  AdapterException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(
          'Request timeout: ${e.message}',
          e,
          e.stackTrace,
        );
      case DioExceptionType.badResponse:
        return BadResponseException(
          'HTTP ${e.response?.statusCode}: ${e.message}',
          e.response?.statusCode ?? 0,
          e.response?.headers != null 
              ? _extractHeaders(e.response!.headers) 
              : {},
          e,
          e.stackTrace,
        );
      case DioExceptionType.cancel:
        return CancelledException(
          'Request cancelled: ${e.message}',
          e,
          e.stackTrace,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return NetworkException(
          'Network error: ${e.message}',
          e,
          e.stackTrace,
        );
      case DioExceptionType.unknown:
      default:
        return UnknownException(
          'Unknown error: ${e.message}',
          e,
          e.stackTrace,
        );
    }
  }

  SmartDioErrorType _mapDioErrorType(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return SmartDioErrorType.timeout;
      case DioExceptionType.badResponse:
        return SmartDioErrorType.badResponse;
      case DioExceptionType.cancel:
        return SmartDioErrorType.cancelled;
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return SmartDioErrorType.network;
      case DioExceptionType.unknown:
      default:
        return SmartDioErrorType.unknown;
    }
  }

  @override
  Future<void> close() async {
    if (_closeDioOnDispose) {
      _dio.close();
    }
  }
}