import 'dart:convert';
import 'dart:io';

import '../../core/smart_dio_request.dart';
import '../../core/smart_dio_response.dart';
import '../http_client_adapter.dart';

class HttpClientAdapterImpl extends HttpClientAdapter {
  final HttpClient _client;
  final bool _closeClientOnDispose;

  HttpClientAdapterImpl({
    HttpClient? client,
  })  : _client = client ?? HttpClient(),
        _closeClientOnDispose = client == null;

  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    final startTime = DateTime.now();
    HttpClientRequest? httpRequest;
    HttpClientResponse? httpResponse;

    try {
      final uri = request.uri;

      switch (request.method.toUpperCase()) {
        case 'GET':
          httpRequest = await _client.getUrl(uri);
          break;
        case 'POST':
          httpRequest = await _client.postUrl(uri);
          break;
        case 'PUT':
          httpRequest = await _client.putUrl(uri);
          break;
        case 'PATCH':
          httpRequest = await _client.patchUrl(uri);
          break;
        case 'DELETE':
          httpRequest = await _client.deleteUrl(uri);
          break;
        case 'HEAD':
          httpRequest = await _client.headUrl(uri);
          break;
        default:
          httpRequest = await _client.openUrl(request.method, uri);
      }

      if (request.timeout != null) {
        _client.connectionTimeout = request.timeout;
      }

      // Add default headers to avoid 403 errors
      httpRequest.headers
          .set('user-agent', 'SmartDio Flutter App/1.0 (dart:io HttpClient)');
      httpRequest.headers.set('accept', 'application/json');

      // Add request-specific headers
      request.headers.forEach((key, value) {
        httpRequest?.headers.set(key, value);
      });

      if (request.body != null) {
        if (request.body is String) {
          httpRequest.write(request.body);
        } else if (request.body is List<int>) {
          httpRequest.add(request.body);
        } else if (request.body is Map || request.body is List) {
          final jsonString = jsonEncode(request.body);
          httpRequest.headers.set('content-type', 'application/json');
          httpRequest.write(jsonString);
        } else {
          httpRequest.write(request.body.toString());
        }
      }

      httpResponse = await httpRequest.close();

      final responseHeaders = <String, String>{};
      httpResponse.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      final responseData = await httpResponse.transform(utf8.decoder).join();

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        dynamic parsedData = responseData;

        final contentType = httpResponse.headers.contentType;
        if (contentType?.mimeType == 'application/json' &&
            responseData.isNotEmpty) {
          try {
            parsedData = jsonDecode(responseData);
          } catch (e) {
            parsedData = responseData;
          }
        }

        return SmartDioSuccess<T>(
          data: transformer(parsedData),
          statusCode: httpResponse.statusCode,
          headers: responseHeaders,
          correlationId: request.correlationId,
          timestamp: endTime,
          duration: duration,
        );
      } else {
        return SmartDioError<T>(
          error: BadResponseException(
            'HTTP ${httpResponse.statusCode}: $responseData',
            httpResponse.statusCode,
            responseHeaders,
          ),
          statusCode: httpResponse.statusCode,
          headers: responseHeaders,
          type: SmartDioErrorType.badResponse,
          correlationId: request.correlationId,
          timestamp: endTime,
          duration: duration,
        );
      }
    } on SocketException catch (e, stackTrace) {
      return SmartDioError<T>(
        error: NetworkException('Network error: ${e.message}', e, stackTrace),
        type: SmartDioErrorType.network,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: DateTime.now().difference(startTime),
        stackTrace: stackTrace,
      );
    } on TimeoutException catch (e, stackTrace) {
      return SmartDioError<T>(
        error: TimeoutException('Request timeout: ${e.message}', e, stackTrace),
        type: SmartDioErrorType.timeout,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: DateTime.now().difference(startTime),
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      return SmartDioError<T>(
        error: UnknownException('Unknown error: $e', e, stackTrace),
        type: SmartDioErrorType.unknown,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: DateTime.now().difference(startTime),
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closeClientOnDispose) {
      _client.close();
    }
  }
}
