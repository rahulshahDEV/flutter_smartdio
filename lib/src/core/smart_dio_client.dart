import 'dart:async';

import '../adapters/http_client_adapter.dart';
import '../cache/cache_manager.dart';
import '../connectivity/connectivity_manager.dart';
import '../interceptors/interceptor.dart';
import '../logging/smart_logger.dart';
import '../metrics/performance_metrics.dart';
import '../queue/request_queue.dart';
import '../retry/retry_policy.dart';
import 'smart_dio_config.dart';
import 'smart_dio_request.dart';
import 'smart_dio_response.dart';

/// A smart HTTP client that provides transport-agnostic HTTP operations with
/// caching, queuing, retry mechanisms, and comprehensive logging.
/// 
/// This class serves as the main entry point for all HTTP operations and
/// orchestrates various features like offline caching, request deduplication,
/// connectivity management, and performance monitoring.
class SmartDioClient {
  final HttpClientAdapter _adapter;
  final SmartDioConfig _config;
  final SmartLogger _logger;
  final PerformanceMetrics _metrics;
  final ConnectivityManager _connectivityManager;
  final RequestQueue _requestQueue;
  final CacheStore? _cacheStore;
  final InterceptorChain _interceptors;
  
  final Map<String, SmartDioRequest> _activeRequests = {};
  final Map<String, Completer<SmartDioResponse>> _deduplicationMap = {};

  /// Creates a new SmartDioClient with the specified configuration.
  /// 
  /// The [adapter] parameter is required and defines the underlying HTTP client
  /// to use (Dio, HTTP, or Chopper). All other parameters are optional and will
  /// use sensible defaults if not provided.
  SmartDioClient({
    required HttpClientAdapter adapter,
    SmartDioConfig? config,
    SmartLogger? logger,
    PerformanceMetrics? metrics,
    ConnectivityManager? connectivityManager,
    RequestQueue? requestQueue,
    CacheStore? cacheStore,
    List<SmartDioInterceptor>? interceptors,
  })  : _adapter = adapter,
        _config = config ?? const SmartDioConfig(),
        _logger = logger ?? SmartLogger(),
        _metrics = metrics ?? PerformanceMetrics(),
        _connectivityManager = connectivityManager ?? ConnectivityManager(),
        _requestQueue = requestQueue ?? RequestQueue.withStorageType(
          storageType: config?.queueStorageType ?? QueueStorageType.persistent,
          maxSize: config?.maxQueueSize ?? 100,
          maxAge: config?.maxQueueAge ?? const Duration(days: 7),
        ),
        _cacheStore = cacheStore,
        _interceptors = InterceptorChain() {
    if (interceptors != null) {
      _interceptors.addAll(interceptors);
    }
  }

  SmartDioConfig get config => _config;
  SmartLogger get logger => _logger;
  PerformanceMetrics get metrics => _metrics;
  ConnectivityManager get connectivity => _connectivityManager;
  RequestQueue get queue => _requestQueue;
  InterceptorChain get interceptors => _interceptors;

  Future<SmartDioResponse<T>> execute<T>({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    RequestConfig? requestConfig,
    required T Function(dynamic data) transformer,
  }) async {
    final uri = Uri.parse(url);
    final correlationId = _generateCorrelationId();
    final startTime = DateTime.now();
    
    final mergedConfig = _mergeConfigs(requestConfig);
    final mergedHeaders = {
      ..._config.defaultHeaders,
      ...?mergedConfig.headers,
      ...?headers,
    };

    var request = SmartDioRequest(
      method: method.toUpperCase(),
      uri: uri,
      headers: mergedHeaders,
      body: body,
      timeout: mergedConfig.timeout ?? _config.defaultTimeout,
      extra: mergedConfig.extra,
      correlationId: correlationId,
      tags: mergedConfig.tags,
    );

    _logger.httpRequest(
      method,
      url,
      correlationId: correlationId,
      headers: mergedHeaders,
      body: body,
    );

    try {
      request = await _interceptors.processRequest(request);
      
      if (_shouldCheckDeduplication(request, mergedConfig)) {
        final duplicate = await _checkDeduplication<T>(request);
        if (duplicate != null) {
          _logger.debug('Request deduplicated', correlationId: correlationId);
          return duplicate;
        }
      }

      if (!_connectivityManager.isConnected) {
        if (_config.enableRequestQueue && _requestQueue.shouldQueue(request)) {
          await _requestQueue.enqueue(request);
          _logger.info('Request queued (offline)', correlationId: correlationId);
          
          return SmartDioError<T>(
            error: 'Request queued due to no connectivity',
            type: SmartDioErrorType.network,
            correlationId: correlationId,
            timestamp: DateTime.now(),
            duration: DateTime.now().difference(startTime),
          );
        }
      }

      final cachePolicy = mergedConfig.cachePolicy ?? _config.cachePolicy;
      
      if (_shouldCheckCache(request, cachePolicy)) {
        final cached = await _getCachedResponse<T>(request, transformer);
        if (cached != null) {
          _logger.debug('Cache hit', correlationId: correlationId);
          _metrics.recordCacheHit(correlationId, request.signature);
          
          // Log cached response
          final success = cached as SmartDioSuccess<T>;
          _logger.httpResponse(
            success.statusCode,
            method,
            url,
            success.duration,
            correlationId: correlationId,
            headers: success.headers,
            body: success.data,
            rawBody: success.rawData,
            fromCache: true,
          );
          
          return cached;
        }
        _metrics.recordCacheMiss(correlationId, request.signature);
      }

      _activeRequests[correlationId] = request;
      
      var response = await _executeWithRetry<T>(
        request: request,
        transformer: transformer,
        retryPolicy: mergedConfig.retryPolicy ?? _config.retryPolicy,
        startTime: startTime,
      );

      response = await _interceptors.processResponse(response);

      // Log the response with detailed debug information
      final duration = DateTime.now().difference(startTime);
      if (response.isSuccess) {
        final success = response as SmartDioSuccess;
        _logger.httpResponse(
          success.statusCode,
          method,
          url,
          duration,
          correlationId: correlationId,
          headers: success.headers,
          body: success.data,
          rawBody: success.rawData,
          fromCache: response.isFromCache,
        );
      } else {
        final error = response as SmartDioError;
        _logger.httpResponse(
          error.statusCode ?? 0,
          method,
          url,
          duration,
          correlationId: correlationId,
          headers: error.headers,
          body: error.error.toString(),
          fromCache: response.isFromCache,
        );
      }

      if (response.isSuccess && _shouldCache(request, response, cachePolicy)) {
        await _cacheResponse(request, response);
      }

      _recordMetrics(request, response, startTime, duration);

      return response;
      
    } catch (e, stackTrace) {
      _logger.error(
        'Request failed with exception',
        correlationId: correlationId,
        error: e,
        stackTrace: stackTrace,
      );

      final error = SmartDioError<T>(
        error: e,
        stackTrace: stackTrace,
        type: SmartDioErrorType.unknown,
        correlationId: correlationId,
        timestamp: DateTime.now(),
        duration: DateTime.now().difference(startTime),
      );

      final processedError = await _interceptors.processError(error);
      
      final duration = DateTime.now().difference(startTime);
      _recordMetrics(request, processedError, startTime, duration);

      return processedError;
      
    } finally {
      _activeRequests.remove(correlationId);
      _deduplicationMap.remove(request.signature);
    }
  }

  Future<SmartDioResponse<T>> get<T>(
    String url, {
    Map<String, String>? headers,
    RequestConfig? config,
    required T Function(dynamic data) transformer,
  }) {
    return execute<T>(
      method: 'GET',
      url: url,
      headers: headers,
      requestConfig: config,
      transformer: transformer,
    );
  }

  Future<SmartDioResponse<T>> post<T>(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    RequestConfig? config,
    required T Function(dynamic data) transformer,
  }) {
    return execute<T>(
      method: 'POST',
      url: url,
      headers: headers,
      body: body,
      requestConfig: config,
      transformer: transformer,
    );
  }

  Future<SmartDioResponse<T>> put<T>(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    RequestConfig? config,
    required T Function(dynamic data) transformer,
  }) {
    return execute<T>(
      method: 'PUT',
      url: url,
      headers: headers,
      body: body,
      requestConfig: config,
      transformer: transformer,
    );
  }

  Future<SmartDioResponse<T>> patch<T>(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    RequestConfig? config,
    required T Function(dynamic data) transformer,
  }) {
    return execute<T>(
      method: 'PATCH',
      url: url,
      headers: headers,
      body: body,
      requestConfig: config,
      transformer: transformer,
    );
  }

  Future<SmartDioResponse<T>> delete<T>(
    String url, {
    Map<String, String>? headers,
    RequestConfig? config,
    required T Function(dynamic data) transformer,
  }) {
    return execute<T>(
      method: 'DELETE',
      url: url,
      headers: headers,
      requestConfig: config,
      transformer: transformer,
    );
  }

  void cancelByTag(String tag) {
    final requests = _activeRequests.values.where((r) => r.tags.contains(tag));
    for (final request in requests) {
      _logger.info('Cancelling request by tag: $tag', correlationId: request.correlationId);
    }
  }

  void cancelByCorrelationId(String correlationId) {
    if (_activeRequests.containsKey(correlationId)) {
      _logger.info('Cancelling request', correlationId: correlationId);
      _activeRequests.remove(correlationId);
    }
  }

  void cancelAll() {
    final count = _activeRequests.length;
    _activeRequests.clear();
    _logger.info('Cancelled all requests', metadata: {'count': count});
  }

  Future<SmartDioResponse<T>> _executeWithRetry<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
    required RetryPolicy retryPolicy,
    required DateTime startTime,
    int attempt = 0,
  }) async {
    try {
      final response = await _adapter.execute<T>(
        request: request,
        transformer: transformer,
      );

      if (response.isSuccess) {
        return response;
      }

      final error = response as SmartDioError<T>;
      if (retryPolicy.shouldRetry(error, attempt)) {
        final delay = retryPolicy.getDelay(attempt);
        
        _logger.info(
          'Retrying request',
          correlationId: request.correlationId,
          metadata: {
            'attempt': attempt + 1,
            'maxAttempts': retryPolicy.maxAttempts,
            'delay': delay.inMilliseconds,
          },
        );

        await Future.delayed(delay);
        
        return _executeWithRetry<T>(
          request: request,
          transformer: transformer,
          retryPolicy: retryPolicy,
          startTime: startTime,
          attempt: attempt + 1,
        );
      }

      return error.copyWith(retryCount: attempt);
      
    } catch (e, stackTrace) {
      final error = SmartDioError<T>(
        error: e,
        stackTrace: stackTrace,
        type: _categorizeError(e),
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: DateTime.now().difference(startTime),
        retryCount: attempt,
      );

      if (retryPolicy.shouldRetry(error, attempt)) {
        final delay = retryPolicy.getDelay(attempt);
        await Future.delayed(delay);
        
        return _executeWithRetry<T>(
          request: request,
          transformer: transformer,
          retryPolicy: retryPolicy,
          startTime: startTime,
          attempt: attempt + 1,
        );
      }

      return error;
    }
  }

  SmartDioErrorType _categorizeError(Object error) {
    if (error is TimeoutException) return SmartDioErrorType.timeout;
    if (error is NetworkException) return SmartDioErrorType.network;
    if (error is CancelledException) return SmartDioErrorType.cancelled;
    if (error is BadResponseException) return SmartDioErrorType.badResponse;
    return SmartDioErrorType.unknown;
  }

  RequestConfig _mergeConfigs(RequestConfig? requestConfig) {
    return RequestConfig(
      timeout: requestConfig?.timeout,
      headers: requestConfig?.headers,
      retryPolicy: requestConfig?.retryPolicy,
      cachePolicy: requestConfig?.cachePolicy,
      logLevel: requestConfig?.logLevel,
      enableMetrics: requestConfig?.enableMetrics ?? _config.enableMetrics,
      enableDeduplication: requestConfig?.enableDeduplication ?? _config.enableDeduplication,
      enableQueue: requestConfig?.enableQueue ?? _config.enableRequestQueue,
      extra: requestConfig?.extra ?? {},
      tags: requestConfig?.tags ?? {},
    );
  }

  bool _shouldCheckDeduplication(SmartDioRequest request, RequestConfig config) {
    return config.enableDeduplication == true;
  }

  Future<SmartDioResponse<T>?> _checkDeduplication<T>(SmartDioRequest request) async {
    final signature = request.signature;
    
    if (_deduplicationMap.containsKey(signature)) {
      final completer = _deduplicationMap[signature]!;
      return completer.future as SmartDioResponse<T>;
    }

    _deduplicationMap[signature] = Completer<SmartDioResponse>();
    
    Timer(_config.deduplicationWindow, () {
      _deduplicationMap.remove(signature);
    });

    return null;
  }

  bool _shouldCheckCache(SmartDioRequest request, CachePolicy policy) {
    return _cacheStore != null && policy.shouldUseCache(request.method);
  }

  Future<SmartDioResponse<T>?> _getCachedResponse<T>(
    SmartDioRequest request,
    T Function(dynamic data) transformer,
  ) async {
    if (_cacheStore == null) return null;

    try {
      final entry = await _cacheStore!.get(request.signature);
      if (entry == null || entry.isExpired) return null;

      return SmartDioSuccess<T>(
        data: transformer(entry.data),
        rawData: entry.data,
        statusCode: 200,
        headers: entry.headers,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: Duration.zero,
        isFromCache: true,
      );
    } catch (e) {
      _logger.warning(
        'Cache read failed',
        correlationId: request.correlationId,
        metadata: {'error': e.toString()},
      );
      return null;
    }
  }

  bool _shouldCache(SmartDioRequest request, SmartDioResponse response, CachePolicy policy) {
    if (_cacheStore == null || !response.isSuccess) return false;
    
    final success = response as SmartDioSuccess;
    return policy.shouldCache(request.method, success.statusCode);
  }

  Future<void> _cacheResponse(SmartDioRequest request, SmartDioResponse response) async {
    if (_cacheStore == null || !response.isSuccess) return;

    try {
      final success = response as SmartDioSuccess;
      final entry = CacheEntry(
        data: success.data,
        createdAt: DateTime.now(),
        ttl: _config.cachePolicy.ttl,
        headers: success.headers,
      );

      await _cacheStore!.set(request.signature, entry);
    } catch (e) {
      _logger.warning(
        'Cache write failed',
        correlationId: request.correlationId,
        metadata: {'error': e.toString()},
      );
    }
  }

  void _recordMetrics(
    SmartDioRequest request,
    SmartDioResponse response,
    DateTime startTime,
    Duration duration,
  ) {
    if (!_config.enableMetrics) return;

    final metrics = RequestMetrics(
      correlationId: request.correlationId,
      method: request.method,
      uri: request.uri,
      startTime: startTime,
      endTime: DateTime.now(),
      totalDuration: duration,
      statusCode: response.isSuccess 
          ? (response as SmartDioSuccess).statusCode 
          : (response as SmartDioError).statusCode,
      success: response.isSuccess,
      fromCache: response.isFromCache,
      retryCount: response.retryCount,
      errorType: response.isError ? (response as SmartDioError).type.name : null,
    );

    _metrics.recordRequest(metrics);
  }

  String _generateCorrelationId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_activeRequests.length}';
  }

  Future<void> dispose() async {
    await _adapter.close();
    await _logger.close();
    _metrics.dispose();
    _connectivityManager.dispose();
    await _requestQueue.dispose();
  }
}

extension SmartDioResponseExtension<T> on SmartDioError<T> {
  SmartDioError<T> copyWith({
    Object? error,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, String>? headers,
    SmartDioErrorType? type,
    String? correlationId,
    DateTime? timestamp,
    Duration? duration,
    bool? isFromCache,
    int? retryCount,
  }) {
    return SmartDioError<T>(
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      type: type ?? this.type,
      correlationId: correlationId ?? this.correlationId,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      isFromCache: isFromCache ?? this.isFromCache,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}