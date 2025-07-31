import 'dart:convert';

import 'package:chopper/chopper.dart';

import '../../core/smart_dio_request.dart';
import '../../core/smart_dio_response.dart';
import '../http_client_adapter.dart';

class ChopperClientAdapter extends HttpClientAdapter {
  final ChopperClient _chopperClient;
  final bool _closeClientOnDispose;

  ChopperClientAdapter({
    ChopperClient? chopperClient,
  })  : _chopperClient = chopperClient ?? ChopperClient(),
        _closeClientOnDispose = chopperClient == null;

  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    final startTime = DateTime.now();

    try {
      // Add default headers to avoid 403 errors
      final headers = Map<String, String>.from(request.headers);
      if (!headers.containsKey('user-agent')) {
        headers['user-agent'] = 'SmartDio Flutter App/1.0 (Chopper)';
      }
      if (!headers.containsKey('accept')) {
        headers['accept'] = 'application/json';
      }
      
      // Build the request
      final chopperRequest = Request(
        request.method,
        request.uri,
        request.uri,
        headers: headers,
        body: request.body,
      );

      // Execute the request
      final response = await _chopperClient.send(chopperRequest);

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      if (response.isSuccessful) {
        dynamic parsedData = response.body;

        // If response body is a string, try to parse as JSON
        if (parsedData is String && parsedData.isNotEmpty) {
          try {
            parsedData = jsonDecode(parsedData);
          } catch (e) {
            // Keep as string if JSON parsing fails
          }
        }

        return SmartDioSuccess<T>(
          data: transformer(parsedData),
          statusCode: response.statusCode,
          headers: response.headers,
          correlationId: request.correlationId,
          timestamp: endTime,
          duration: duration,
        );
      } else {
        return SmartDioError<T>(
          error: BadResponseException(
            'HTTP ${response.statusCode}: ${response.error}',
            response.statusCode,
            response.headers,
          ),
          statusCode: response.statusCode,
          headers: response.headers,
          type: SmartDioErrorType.badResponse,
          correlationId: request.correlationId,
          timestamp: endTime,
          duration: duration,
        );
      }
    } catch (e, stackTrace) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      SmartDioErrorType errorType;
      AdapterException adaptedException;

      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        errorType = SmartDioErrorType.timeout;
        adaptedException =
            TimeoutException('Request timeout: $e', e, stackTrace);
      } else if (e.toString().contains('connection') ||
          e.toString().contains('network') ||
          e.toString().contains('socket')) {
        errorType = SmartDioErrorType.network;
        adaptedException = NetworkException('Network error: $e', e, stackTrace);
      } else if (e.toString().contains('cancel')) {
        errorType = SmartDioErrorType.cancelled;
        adaptedException =
            CancelledException('Request cancelled: $e', e, stackTrace);
      } else {
        errorType = SmartDioErrorType.unknown;
        adaptedException = UnknownException('Unknown error: $e', e, stackTrace);
      }

      return SmartDioError<T>(
        error: adaptedException,
        stackTrace: stackTrace,
        type: errorType,
        correlationId: request.correlationId,
        timestamp: endTime,
        duration: duration,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closeClientOnDispose) {
      _chopperClient.dispose();
    }
  }
}
