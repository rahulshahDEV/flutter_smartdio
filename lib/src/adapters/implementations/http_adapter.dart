import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/smart_dio_request.dart';
import '../../core/smart_dio_response.dart';
import '../http_client_adapter.dart';

class HttpPackageAdapter extends HttpClientAdapter {
  final http.Client _client;
  final bool _closeClientOnDispose;

  HttpPackageAdapter({
    http.Client? httpClient,
  })  : _client = httpClient ?? http.Client(),
        _closeClientOnDispose = httpClient == null;

  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    final startTime = DateTime.now();

    try {
      http.Response response;
      final uri = request.uri;
      final headers = Map<String, String>.from(request.headers);

      // Add default headers to avoid 403 errors
      if (!headers.containsKey('user-agent')) {
        headers['user-agent'] = 'SmartDio Flutter App/1.0 (HTTP package)';
      }
      if (!headers.containsKey('accept')) {
        headers['accept'] = 'application/json';
      }

      // Add content-type if body is JSON
      if (request.body != null && 
          (request.body is Map || request.body is List) &&
          !headers.containsKey('content-type')) {
        headers['content-type'] = 'application/json';
      }

      switch (request.method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
          break;
        case 'POST':
          final body = _encodeBody(request.body);
          response = await _client.post(uri, headers: headers, body: body);
          break;
        case 'PUT':
          final body = _encodeBody(request.body);
          response = await _client.put(uri, headers: headers, body: body);
          break;
        case 'PATCH':
          final body = _encodeBody(request.body);
          response = await _client.patch(uri, headers: headers, body: body);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers);
          break;
        case 'HEAD':
          response = await _client.head(uri, headers: headers);
          break;
        default:
          final httpRequest = http.Request(request.method, uri);
          httpRequest.headers.addAll(headers);
          if (request.body != null) {
            httpRequest.body = _encodeBody(request.body);
          }
          final streamedResponse = await _client.send(httpRequest);
          response = await http.Response.fromStream(streamedResponse);
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        dynamic parsedData = response.body;
        
        // Try to parse JSON if content-type indicates JSON
        final contentType = response.headers['content-type'];
        if (contentType != null && 
            contentType.contains('application/json') && 
            response.body.isNotEmpty) {
          try {
            parsedData = jsonDecode(response.body);
          } catch (e) {
            // Keep as string if JSON parsing fails
            parsedData = response.body;
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
            'HTTP ${response.statusCode}: ${response.body}',
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
    } on SocketException catch (e, stackTrace) {
      return SmartDioError<T>(
        error: NetworkException('Network error: ${e.message}', e, stackTrace),
        type: SmartDioErrorType.network,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: DateTime.now().difference(startTime),
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (e, stackTrace) {
      return SmartDioError<T>(
        error: NetworkException('HTTP client error: ${e.message}', e, stackTrace),
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

  String _encodeBody(dynamic body) {
    if (body == null) return '';
    if (body is String) return body;
    if (body is List<int>) return utf8.decode(body);
    if (body is Map || body is List) return jsonEncode(body);
    return body.toString();
  }

  @override
  Future<void> close() async {
    if (_closeClientOnDispose) {
      _client.close();
    }
  }
}