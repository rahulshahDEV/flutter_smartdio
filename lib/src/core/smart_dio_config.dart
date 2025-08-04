import 'package:meta/meta.dart';
import '../retry/retry_policy.dart';
import '../cache/cache_manager.dart';
import '../logging/smart_logger.dart';

/// Queue storage type options
enum QueueStorageType {
  /// Store requests only in memory (lost on app restart)
  memory,
  /// Store requests persistently using Hive (survives app restart)
  persistent,
  /// Disable request queuing entirely
  none,
}

/// Configuration class for SmartDioClient that defines behavior for caching,
/// retries, logging, and other advanced features.
/// 
/// This immutable configuration class allows you to customize various aspects
/// of the HTTP client behavior including timeouts, retry policies, cache settings,
/// and security configurations.
@immutable
class SmartDioConfig {
  final Duration defaultTimeout;
  final Map<String, String> defaultHeaders;
  final RetryPolicy retryPolicy;
  final CachePolicy cachePolicy;
  final LogLevel logLevel;
  final bool enableMetrics;
  final bool enableDeduplication;
  final Duration deduplicationWindow;
  final bool enableRequestQueue;
  final QueueStorageType queueStorageType;
  final int maxQueueSize;
  final Duration maxQueueAge;
  final Duration connectivityCheckInterval;
  final List<String> sensitiveHeaders;
  final List<String> sensitiveBodyFields;

  const SmartDioConfig({
    this.defaultTimeout = const Duration(seconds: 30),
    this.defaultHeaders = const {},
    this.retryPolicy = const RetryPolicy.none(),
    this.cachePolicy = const CachePolicy.none(),
    this.logLevel = LogLevel.info,
    this.enableMetrics = true,
    this.enableDeduplication = true,
    this.deduplicationWindow = const Duration(seconds: 5),
    this.enableRequestQueue = true,
    this.queueStorageType = QueueStorageType.persistent,
    this.maxQueueSize = 100,
    this.maxQueueAge = const Duration(days: 7),
    this.connectivityCheckInterval = const Duration(seconds: 10),
    this.sensitiveHeaders = const [
      'authorization',
      'x-api-key',
      'x-auth-token',
      'cookie',
      'set-cookie',
    ],
    this.sensitiveBodyFields = const [
      'password',
      'token',
      'secret',
      'key',
      'authorization',
    ],
  });

  SmartDioConfig copyWith({
    Duration? defaultTimeout,
    Map<String, String>? defaultHeaders,
    RetryPolicy? retryPolicy,
    CachePolicy? cachePolicy,
    LogLevel? logLevel,
    bool? enableMetrics,
    bool? enableDeduplication,
    Duration? deduplicationWindow,
    bool? enableRequestQueue,
    QueueStorageType? queueStorageType,
    int? maxQueueSize,
    Duration? maxQueueAge,
    Duration? connectivityCheckInterval,
    List<String>? sensitiveHeaders,
    List<String>? sensitiveBodyFields,
  }) {
    return SmartDioConfig(
      defaultTimeout: defaultTimeout ?? this.defaultTimeout,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      cachePolicy: cachePolicy ?? this.cachePolicy,
      logLevel: logLevel ?? this.logLevel,
      enableMetrics: enableMetrics ?? this.enableMetrics,
      enableDeduplication: enableDeduplication ?? this.enableDeduplication,
      deduplicationWindow: deduplicationWindow ?? this.deduplicationWindow,
      enableRequestQueue: enableRequestQueue ?? this.enableRequestQueue,
      queueStorageType: queueStorageType ?? this.queueStorageType,
      maxQueueSize: maxQueueSize ?? this.maxQueueSize,
      maxQueueAge: maxQueueAge ?? this.maxQueueAge,
      connectivityCheckInterval: connectivityCheckInterval ?? this.connectivityCheckInterval,
      sensitiveHeaders: sensitiveHeaders ?? this.sensitiveHeaders,
      sensitiveBodyFields: sensitiveBodyFields ?? this.sensitiveBodyFields,
    );
  }

  @override
  String toString() {
    return 'SmartDioConfig(timeout: $defaultTimeout, retryPolicy: $retryPolicy, cachePolicy: $cachePolicy)';
  }
}

@immutable
class RequestConfig {
  final Duration? timeout;
  final Map<String, String>? headers;
  final RetryPolicy? retryPolicy;
  final CachePolicy? cachePolicy;
  final LogLevel? logLevel;
  final bool? enableMetrics;
  final bool? enableDeduplication;
  final bool? enableQueue;
  final Map<String, dynamic> extra;
  final Set<String> tags;

  const RequestConfig({
    this.timeout,
    this.headers,
    this.retryPolicy,
    this.cachePolicy,
    this.logLevel,
    this.enableMetrics,
    this.enableDeduplication,
    this.enableQueue,
    this.extra = const {},
    this.tags = const {},
  });

  RequestConfig copyWith({
    Duration? timeout,
    Map<String, String>? headers,
    RetryPolicy? retryPolicy,
    CachePolicy? cachePolicy,
    LogLevel? logLevel,
    bool? enableMetrics,
    bool? enableDeduplication,
    bool? enableQueue,
    Map<String, dynamic>? extra,
    Set<String>? tags,
  }) {
    return RequestConfig(
      timeout: timeout ?? this.timeout,
      headers: headers ?? this.headers,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      cachePolicy: cachePolicy ?? this.cachePolicy,
      logLevel: logLevel ?? this.logLevel,
      enableMetrics: enableMetrics ?? this.enableMetrics,
      enableDeduplication: enableDeduplication ?? this.enableDeduplication,
      enableQueue: enableQueue ?? this.enableQueue,
      extra: extra ?? this.extra,
      tags: tags ?? this.tags,
    );
  }
}