# Flutter SmartDio Usage Guide

## 🚀 Quick Start

### Basic Setup

```dart
import 'package:flutter_smartdio/flutter_smartdio.dart';

// Create a basic client
final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
);

// Make a request
final response = await client.get<Map<String, dynamic>>(
  'https://api.example.com/users/1',
  transformer: (data) => data as Map<String, dynamic>,
);

// Handle response
response.fold(
  (success) => print('Data: ${success.data}'),
  (error) => print('Error: ${error.error}'),
);
```

### Advanced Configuration

```dart
final config = SmartDioConfig(
  defaultTimeout: const Duration(seconds: 10),
  retryPolicy: const RetryPolicy.exponentialBackoff(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 500),
    multiplier: 2.0,
    jitter: true,
  ),
  cachePolicy: const CachePolicy.networkFirst(
    ttl: Duration(minutes: 5),
  ),
  logLevel: LogLevel.debug,
  enableMetrics: true,
  enableDeduplication: true,
);

final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
  config: config,
  cacheStore: MemoryCacheStore(),
  requestQueue: RequestQueue(
    storage: MemoryQueueStorage(),
    maxSize: 100,
  ),
);
```

## 🔄 Retry Strategies

### Exponential Backoff (Recommended)
```dart
const retryPolicy = RetryPolicy.exponentialBackoff(
  maxAttempts: 3,
  initialDelay: Duration(milliseconds: 500),
  multiplier: 2.0,  // 500ms, 1000ms, 2000ms
  jitter: true,     // Add randomization
  retryStatusCodes: {408, 429, 500, 502, 503, 504},
);
```

### Fixed Delay
```dart
const retryPolicy = RetryPolicy.fixed(
  maxAttempts: 3,
  delay: Duration(seconds: 1),
  retryStatusCodes: {500, 502, 503},
);
```

### Custom Retry Logic
```dart
final retryPolicy = RetryPolicy.custom(
  maxAttempts: 5,
  delayCalculator: (attempt) => Duration(seconds: attempt * 2),
  shouldRetry: (error) => 
    error.type == SmartDioErrorType.network ||
    (error.statusCode != null && error.statusCode! >= 500),
);
```

## 💾 Caching Strategies

### Network First (Default for most apps)
```dart
const cachePolicy = CachePolicy.networkFirst(
  ttl: Duration(minutes: 5),
  cacheMethods: {'GET', 'HEAD'},
  cacheStatusCodes: {200, 201, 204, 300, 301, 302, 404, 410},
);
```

### Cache First (For offline-first apps)
```dart
const cachePolicy = CachePolicy.cacheFirst(
  ttl: Duration(hours: 1),
);
```

### Cache Only / Network Only
```dart
// For testing or specific scenarios
const cacheOnly = CachePolicy.cacheOnly();
const networkOnly = CachePolicy.networkOnly();
const noCache = CachePolicy.none();
```

## 📱 Offline Support

### Automatic Request Queuing
```dart
final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
  config: const SmartDioConfig(
    enableRequestQueue: true,
  ),
  requestQueue: RequestQueue(
    storage: MemoryQueueStorage(), // Use persistent storage in production
    maxSize: 50,
    maxAge: Duration(days: 7),
  ),
);

// Requests are automatically queued when offline
await client.post<String>(
  'https://api.example.com/posts',
  body: {'title': 'My Post'},
  transformer: (data) => data.toString(),
);

// Monitor queue
print('Queue size: ${client.queue.length}');
client.queue.events.listen((event) {
  print('Queue event: $event');
});
```

### Manual Offline Mode
```dart
// Enable offline mode for testing
client.connectivity.setManualOfflineMode(true);

// Check connectivity
print('Is connected: ${client.connectivity.isConnected}');
print('Connection quality: ${client.connectivity.currentStatus.quality}');

// Listen to connectivity changes
client.connectivity.statusStream.listen((status) {
  print('Connectivity changed: ${status.status}');
});
```

## 🎯 Type-Safe Responses

### Custom Data Models
```dart
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
  );
}

// Type-safe request
final response = await client.get<User>(
  'https://api.example.com/users/1',
  transformer: (data) => User.fromJson(data as Map<String, dynamic>),
);

// Pattern matching
final result = response.fold(
  (success) => 'Welcome ${success.data.name}!',
  (error) => 'Failed to load user: ${error.error}',
);
```

### Response Transformation
```dart
// Chain transformations
final response = await client.get<List<String>>(
  'https://api.example.com/items',
  transformer: (data) => (data as List).cast<String>(),
);

// Map responses
final names = response.map((items) => items.map((item) => item.toUpperCase()).toList());

// Recover from errors
final safeNames = response.recover((error) => <String>[]);
```

## 🔐 Security & Logging

### Sensitive Data Protection
```dart
final logger = SmartLogger(
  level: LogLevel.debug,
  sensitiveHeaders: [
    'authorization',
    'x-api-key',
    'x-auth-token',
    'cookie',
  ],
  sensitiveBodyFields: [
    'password',
    'secret',
    'token',
    'credit_card',
  ],
);

final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
  logger: logger,
);
```

### Custom Log Sinks
```dart
class FileLogSink implements LogSink {
  final File logFile;
  
  FileLogSink(this.logFile);
  
  @override
  void write(LogEntry entry) {
    logFile.writeAsStringSync('${entry.toJson()}\n', mode: FileMode.append);
  }
  
  @override
  Future<void> flush() async {
    // Implement if needed
  }
  
  @override
  Future<void> close() async {
    // Cleanup resources
  }
}

final logger = SmartLogger(
  sinks: [
    ConsoleLogSink(),
    FileLogSink(File('app.log')),
  ],
);
```

## 🔌 Interceptors

### Authentication Interceptor
```dart
class AuthInterceptor extends SmartDioInterceptor {
  final String token;
  
  AuthInterceptor(this.token);
  
  @override
  Future<SmartDioRequest> onRequest(SmartDioRequest request) async {
    return request.copyWith(
      headers: {
        ...request.headers,
        'Authorization': 'Bearer $token',
      },
    );
  }
}

client.interceptors.add(AuthInterceptor('your-token'));
```

### Error Recovery Interceptor
```dart
class ErrorRecoveryInterceptor extends SmartDioInterceptor {
  @override
  Future<SmartDioResponse<T>> onError<T>(SmartDioError<T> error) async {
    // Refresh token on 401
    if (error.statusCode == 401) {
      final newToken = await refreshToken();
      // Retry with new token...
    }
    
    return error;
  }
}
```

### Logging Interceptor
```dart
class CustomLoggingInterceptor extends SmartDioInterceptor {
  @override
  Future<SmartDioRequest> onRequest(SmartDioRequest request) async {
    print('→ ${request.method} ${request.uri}');
    return request;
  }
  
  @override
  Future<SmartDioResponse<T>> onResponse<T>(SmartDioResponse<T> response) async {
    print('← ${response.isSuccess ? 'SUCCESS' : 'ERROR'} (${response.duration.inMilliseconds}ms)');
    return response;
  }
}
```

## 📊 Monitoring & Metrics

### Performance Metrics
```dart
// Get latest request metrics
final latestRequest = client.metrics.getLatestRequest();
print('Last request took: ${latestRequest?.totalDuration}');

// Get success rate
final successRate = client.metrics.getSuccessRate(
  period: Duration(hours: 1),
);
print('Success rate (1h): ${(successRate * 100).toStringAsFixed(1)}%');

// Get average response time
final avgTime = client.metrics.getAverageResponseTime(
  period: Duration(minutes: 30),
);
print('Average response time: ${avgTime.inMilliseconds}ms');
```

### Cache Metrics
```dart
final cacheMetrics = client.metrics.getCacheMetrics();
print('Cache hit rate: ${(cacheMetrics.hitRate * 100).toStringAsFixed(1)}%');
print('Cache hits: ${cacheMetrics.hitCount}');
print('Cache misses: ${cacheMetrics.missCount}');
```

### Real-time Monitoring
```dart
// Listen to all metrics events
client.metrics.events.listen((event) {
  switch (event) {
    case RequestCompletedEvent(:final metrics):
      print('Request completed in ${metrics.totalDuration.inMilliseconds}ms');
    case CacheHitEvent(:final correlationId):
      print('Cache hit for request $correlationId');
    case QueueItemAddedEvent(:final correlationId):
      print('Request $correlationId added to queue');
  }
});
```

## 🎛️ Request Configuration

### Per-Request Configuration
```dart
final response = await client.post<String>(
  'https://api.example.com/posts',
  body: {'title': 'My Post'},
  config: const RequestConfig(
    timeout: Duration(seconds: 5),
    retryPolicy: RetryPolicy.fixed(maxAttempts: 1, delay: Duration.zero),
    cachePolicy: CachePolicy.networkOnly(),
    logLevel: LogLevel.verbose,
    tags: {'user-action', 'create-post'},
    extra: {'priority': 'high'},
  ),
  transformer: (data) => data.toString(),
);
```

### Request Tagging & Bulk Operations
```dart
// Tag requests for bulk operations
await client.get<String>(
  'https://api.example.com/data',
  config: const RequestConfig(tags: {'background-sync'}),
  transformer: (data) => data.toString(),
);

// Cancel all requests with specific tag
client.cancelByTag('background-sync');

// Cancel specific request
client.cancelByCorrelationId('correlation-id');

// Cancel all requests
client.cancelAll();
```

## 🧪 Testing

### Mock Adapter
```dart
class MockAdapter extends HttpClientAdapter {
  final Map<String, dynamic> responses;
  
  MockAdapter(this.responses);
  
  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    final mockData = responses[request.uri.toString()];
    
    if (mockData == null) {
      return SmartDioError<T>(
        error: 'Mock data not found',
        type: SmartDioErrorType.network,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: Duration(milliseconds: 100),
      );
    }
    
    return SmartDioSuccess<T>(
      data: transformer(mockData),
      statusCode: 200,
      correlationId: request.correlationId,
      timestamp: DateTime.now(),
      duration: Duration(milliseconds: 100),
    );
  }
  
  @override
  Future<void> close() async {}
}

// Use in tests
final client = SmartDioClient(
  adapter: MockAdapter({
    'https://api.example.com/users/1': {'id': 1, 'name': 'John'},
  }),
);
```

## 🔧 Custom Adapters

### Creating a Custom Adapter
```dart
class MyHttpAdapter extends HttpClientAdapter {
  final MyHttpClient client;
  
  MyHttpAdapter(this.client);
  
  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    try {
      final response = await client.request(
        method: request.method,
        url: request.uri.toString(),
        headers: request.headers,
        body: request.body,
      );
      
      return SmartDioSuccess<T>(
        data: transformer(response.data),
        statusCode: response.statusCode,
        headers: response.headers,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: response.duration,
      );
      
    } catch (e) {
      return SmartDioError<T>(
        error: e,
        type: _mapErrorType(e),
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: Duration.zero,
      );
    }
  }
  
  SmartDioErrorType _mapErrorType(Object error) {
    // Map your client's errors to SmartDio error types
    if (error is TimeoutException) return SmartDioErrorType.timeout;
    if (error is SocketException) return SmartDioErrorType.network;
    return SmartDioErrorType.unknown;
  }
  
  @override
  Future<void> close() async {
    await client.close();
  }
}
```

## 💡 Best Practices

### 1. Use Singleton Pattern
```dart
class ApiClient {
  static final _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();
  
  late final SmartDioClient client;
  
  void initialize() {
    client = SmartDioClient(
      adapter: HttpClientAdapterImpl(),
      config: const SmartDioConfig(
        defaultTimeout: Duration(seconds: 30),
        retryPolicy: RetryPolicy.exponentialBackoff(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 500),
        ),
      ),
    );
  }
}
```

### 2. Dispose Properly
```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late SmartDioClient client;
  
  @override
  void initState() {
    super.initState();
    client = SmartDioClient(
      adapter: HttpClientAdapterImpl(),
    );
  }
  
  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }
}
```

### 3. Use Type-Safe Models
```dart
// Define your models
class ApiResponse<T> {
  final T data;
  final String message;
  final bool success;
  
  ApiResponse({required this.data, required this.message, required this.success});
  
  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJson) {
    return ApiResponse(
      data: fromJson(json['data']),
      message: json['message'],
      success: json['success'],
    );
  }
}

// Use with SmartDio
final response = await client.get<ApiResponse<User>>(
  'https://api.example.com/users/1',
  transformer: (data) => ApiResponse.fromJson(
    data as Map<String, dynamic>,
    (data) => User.fromJson(data as Map<String, dynamic>),
  ),
);
```

### 4. Handle Errors Gracefully
```dart
extension SmartDioResponseExtension<T> on SmartDioResponse<T> {
  void handleResponse({
    required void Function(T data) onSuccess,
    void Function(String message)? onError,
  }) {
    fold(
      (success) => onSuccess(success.data),
      (error) => onError?.call(error.error.toString()),
    );
  }
}

// Usage
response.handleResponse(
  onSuccess: (user) => print('Welcome ${user.name}!'),
  onError: (message) => showSnackBar(message),
);
```