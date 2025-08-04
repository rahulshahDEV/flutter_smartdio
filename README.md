# Flutter SmartDio

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**A transport-agnostic HTTP wrapper that enhances ANY HTTP client with offline caching, request queuing, retry mechanisms, and comprehensive logging.**

[Features](#-features) • [Installation](#-installation) • [Quick Start](#-quick-start) • [Documentation](#-documentation) • [Example](#-example)

</div>

## 🚀 Features

### **🔌 Transport-Agnostic Design**
- **Works with ANY HTTP client**: Dio, http package, Chopper, dart:io HttpClient
- **Unified API** across all transport layers
- **Easy client switching** without changing your code
- **Adapter pattern** for extensibility

### **💾 Persistent Caching**
- **Hive-based storage** that survives app restarts
- **Intelligent TTL management** with automatic expiry
- **Cache policies**: Network-first, Cache-first, Cache-only, Network-only
- **Real-time cache statistics** and analytics

### **🔄 Smart Retry & Resilience**
- **Exponential backoff** with configurable delays
- **Custom retry policies** for different scenarios
- **Request deduplication** to prevent duplicate calls
- **Never-crash philosophy** with structured error handling

### **📱 Offline-First Architecture**
- **Persistent request queuing** with Hive storage that survives app restarts
- **Configurable storage options**: persistent, memory-only, or disabled
- **Automatic queue processing** when connectivity returns
- **Connectivity monitoring** with quality assessment
- **Seamless online/offline transitions**

### **📊 Advanced Monitoring**
- **Performance metrics** with response time tracking
- **Success rate analytics** and failure reporting
- **Enhanced response logging** that shows actual object data instead of "Instance of Object"
- **Dual logging**: raw JSON response + transformed object data
- **Smart object serialization** with automatic toJson() detection
- **Colorized debug logging** with syntax-highlighted JSON and headers
- **Comprehensive logging** with sensitive data protection
- **Real-time event streaming** for monitoring

### **🎯 Developer Experience**
- **Type-safe responses** with sealed classes
- **Clean architecture** with dependency injection
- **Minimal configuration** required
- **Extensive documentation** and examples

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_smartdio: ^1.0.4
```

Then run:

```bash
flutter pub get
```

## ⚡ Quick Start

### 1. Basic Setup

```dart
import 'package:flutter_smartdio/flutter_smartdio.dart';

// Initialize with built-in dart:io HttpClient (default)
final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
  config: const SmartDioConfig(
    defaultTimeout: Duration(seconds: 30),
    cachePolicy: CachePolicy.networkFirst(
      ttl: Duration(minutes: 5),
    ),
    enableMetrics: true,
    enableRequestQueue: true,
    queueStorageType: QueueStorageType.persistent, // Survives app restarts
  ),
  cacheStore: HiveCacheStore(), // Persistent cache
);

// Or use with Dio
import 'package:dio/dio.dart';
final dioClient = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  config: const SmartDioConfig(
    defaultTimeout: Duration(seconds: 30),
    retryPolicy: RetryPolicy.exponentialBackoff(
      maxAttempts: 3,
      initialDelay: Duration(milliseconds: 500),
    ),
    cachePolicy: CachePolicy.networkFirst(ttl: Duration(minutes: 10)),
    logLevel: LogLevel.debug, // Enable detailed response logging
    enableMetrics: true,
    enableDeduplication: true,
    enableRequestQueue: true,
    queueStorageType: QueueStorageType.persistent, // Default, survives app restarts
    maxQueueSize: 100,
    maxQueueAge: Duration(days: 7),
  ),
  cacheStore: HiveCacheStore(),
);
```

### 2. Making Requests

```dart
// Type-safe GET request
final response = await client.get<User>(
  'https://jsonplaceholder.typicode.com/users/1',
  transformer: (data) => User.fromJson(data as Map<String, dynamic>),
);

response.fold(
  (success) => print('User: ${success.data.name}'),
  (error) => print('Error: ${error.error}'),
);

// POST request with caching
final postResponse = await client.post<Map<String, dynamic>>(
  'https://jsonplaceholder.typicode.com/posts',
  body: {'title': 'Hello World', 'body': 'Test content', 'userId': 1},
  config: const RequestConfig(
    cachePolicy: CachePolicy.networkFirst(ttl: Duration(hours: 1)),
  ),
  transformer: (data) => data as Map<String, dynamic>,
);

// All HTTP methods are supported
final putResponse = await client.put<Post>(
  'https://jsonplaceholder.typicode.com/posts/1',
  body: updatedPost.toJson(),
  transformer: (data) => Post.fromJson(data as Map<String, dynamic>),
);

final patchResponse = await client.patch<Post>(
  'https://jsonplaceholder.typicode.com/posts/1',
  body: {'title': 'Updated Title'},
  transformer: (data) => Post.fromJson(data as Map<String, dynamic>),
);

final deleteResponse = await client.delete<Map<String, dynamic>>(
  'https://jsonplaceholder.typicode.com/posts/1',
  transformer: (data) => data as Map<String, dynamic>? ?? {},
);
```

### 3. Switch HTTP Clients Seamlessly

```dart
// Start with dart:io HttpClient
final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
  config: const SmartDioConfig(
    defaultTimeout: Duration(seconds: 30),
    enableMetrics: true,
  ),
);

// Switch to Dio - same API!
await client.dispose();
import 'package:dio/dio.dart';
final newClient = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  config: const SmartDioConfig(
    defaultTimeout: Duration(seconds: 30),
    enableMetrics: true,
  ),
);

// Or use HTTP package
import 'package:http/http.dart' as http;
final httpPackageClient = SmartDioClient(
  adapter: HttpPackageAdapter(httpClient: http.Client()),
  config: const SmartDioConfig(
    defaultTimeout: Duration(seconds: 30),
    enableMetrics: true,
  ),
);

// Or use Chopper
import 'package:chopper/chopper.dart';
final chopperClient = SmartDioClient(
  adapter: ChopperClientAdapter(client: ChopperClient()),
  config: const SmartDioConfig(
    defaultTimeout: Duration(seconds: 30),
    enableMetrics: true,
  ),
);
```

## 🏗️ Supported HTTP Clients

| Client | Adapter Class | Package |
|--------|---------------|---------|
| **dart:io HttpClient** | `HttpClientAdapterImpl` | Built-in (Default) |
| **Dio** | `DioClientAdapter` | `dio: ^5.8.0` |
| **HTTP Package** | `HttpPackageAdapter` | `http: ^1.4.0` |
| **Chopper** | `ChopperClientAdapter` | `chopper: ^8.3.0` |

## 🎛️ Configuration Options

### Cache Policies

```dart
// Network-first (default)
CachePolicy.networkFirst(ttl: Duration(minutes: 5))

// Cache-first (offline-friendly)
CachePolicy.cacheFirst(ttl: Duration(hours: 1))

// Cache-only (no network)
CachePolicy.cacheOnly()

// Network-only (no cache)
CachePolicy.networkOnly()

// No caching
CachePolicy.none()
```

### Retry Policies

```dart
// Exponential backoff (default configuration)
const RetryPolicy.exponentialBackoff(
  maxAttempts: 3,
  initialDelay: Duration(milliseconds: 500),
  multiplier: 2.0,
  jitter: true,
)

// Fixed delay
const RetryPolicy.fixed(
  maxAttempts: 3,
  delay: Duration(seconds: 1),
)

// Custom retry logic
final RetryPolicy.custom(
  maxAttempts: 5,
  delayCalculator: (attempt) => Duration(seconds: attempt * 2),
  shouldRetry: (error) => error.type == SmartDioErrorType.network,
)

// No retry
const RetryPolicy.none()
```

### Queue Storage Options

```dart
// Persistent storage (default) - survives app restarts
SmartDioConfig(
  queueStorageType: QueueStorageType.persistent,
  maxQueueSize: 100,
  maxQueueAge: Duration(days: 7),
)

// Memory-only storage - lost on app restart
SmartDioConfig(
  queueStorageType: QueueStorageType.memory,
  maxQueueSize: 50,
)

// Disable queuing entirely
SmartDioConfig(
  queueStorageType: QueueStorageType.none,
  enableRequestQueue: false,
)
```

### Enhanced Debug Logging

```dart
// Enable detailed logging to see actual response data
SmartDioConfig(
  logLevel: LogLevel.debug, // Shows both raw JSON and transformed objects
)

// Example output:
// 📥 Raw Response Data:
// {
//   "id": 1,
//   "name": "John Doe",
//   "email": "john@example.com"
// }
// 🔄 Transformed Response:
// User(id: 1, name: John Doe, email: john@example.com)
```

## 📊 Monitoring & Analytics

```dart
// Listen to performance metrics
client.metrics.events.listen((event) {
  switch (event) {
    case RequestCompletedEvent(:final metrics):
      print('Request took: ${metrics.totalDuration.inMilliseconds}ms');
      print('Success: ${metrics.success}');
      break;
    case CacheHitEvent():
      print('Cache hit occurred');
      break;
    case CacheMissEvent():
      print('Cache miss occurred');
      break;
  }
});

// Get real-time statistics
final cacheMetrics = client.metrics.getCacheMetrics();
print('Cache hit rate: ${(cacheMetrics.hitRate * 100).toStringAsFixed(1)}%');
print('Cache hits: ${cacheMetrics.hitCount}');
print('Cache misses: ${cacheMetrics.missCount}');

final successRate = client.metrics.getSuccessRate();
print('Overall success rate: ${(successRate * 100).toStringAsFixed(1)}%');

final avgResponseTime = client.metrics.getAverageResponseTime();
print('Average response time: ${avgResponseTime.inMilliseconds}ms');

// Get queue metrics
final queueMetrics = client.metrics.getQueueMetrics(client.queue.length);
print('Queue size: ${queueMetrics.currentSize}');
print('Queue processed: ${queueMetrics.totalProcessed}');
print('Queue success rate: ${(queueMetrics.successRate * 100).toStringAsFixed(1)}%');
```

## 🎨 Enhanced Debug Logging

SmartDio includes a powerful, colorized logging system that provides detailed insights into your HTTP traffic. Perfect for development and debugging!

### 🌈 Colorized Console Output

When debug logging is enabled, you'll see beautiful, color-coded logs with:
- **📋 Headers** - Blue keys, Green values, Red for sensitive data
- **📤 Request Payload** - Syntax-highlighted JSON with proper indentation
- **📥 Response Body** - Color-coded data types (strings, numbers, booleans)
- **🔒 Security** - Sensitive data automatically redacted as `[REDACTED]`

### 🔧 Enable Debug Logging

There are **two LogLevel settings** that control different aspects of logging:

#### 1. Framework-Level Logging (SmartDioConfig)
Controls internal client operations like cache hits, retries, queue operations:

```dart
final client = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  config: const SmartDioConfig(
    logLevel: LogLevel.debug,  // Framework operations logging
    enableMetrics: true,
    enableDeduplication: true,
    enableRequestQueue: true,
  ),
  // ...
);
```

#### 2. HTTP Traffic Logging (SmartLogger)
Controls detailed HTTP request/response logging with headers, payloads, and response bodies:

```dart
final client = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  logger: SmartLogger(level: LogLevel.debug),  // HTTP traffic logging
  config: const SmartDioConfig(
    // ... other config
  ),
);
```

### 📊 Log Level Comparison

| Aspect | SmartDioConfig.logLevel | SmartLogger.level |
|--------|------------------------|-------------------|
| **Scope** | Client framework operations | HTTP traffic details |
| **Controls** | Cache, retry, queue logs | Headers, payloads, responses |
| **Example Logs** | "Cache hit", "Retrying request" | Request headers, JSON payloads |
| **Performance Impact** | Low | Higher (detailed HTTP data) |
| **Security** | General client info | Sensitive data (sanitized) |

### 🎯 Recommended Settings

#### **Development Mode**
```dart
final client = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  logger: SmartLogger(level: LogLevel.debug),  // Full HTTP details
  config: const SmartDioConfig(
    logLevel: LogLevel.debug,  // All framework details
    enableMetrics: true,
  ),
);
```

#### **Production Mode**
```dart
final client = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  logger: SmartLogger(level: LogLevel.warning),  // Errors only
  config: const SmartDioConfig(
    logLevel: LogLevel.warning,  // Framework errors only
    enableMetrics: true,
  ),
);
```

#### **Performance Testing**
```dart
final client = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  logger: SmartLogger(level: LogLevel.error),  // Minimal logging
  config: const SmartDioConfig(
    logLevel: LogLevel.error,  // Minimal logging
    enableMetrics: false,  // Disable for pure performance
  ),
);
```

### 🎨 Example Debug Output

When both log levels are set to `LogLevel.debug`, you'll see output like:

```bash
🔧 [DEBUG] 📋 Request Headers:
  content-type: application/json
  authorization: [REDACTED]
  user-agent: SmartDio Flutter App/1.0

🔧 [DEBUG] 📤 Request Payload:
{
  "title": "Hello World",
  "body": "Test content",
  "userId": 1,
  "password": "[REDACTED]"
}

✅ [INFO] HTTP Response: 201 POST /api/posts (245ms)

🔧 [DEBUG] 📋 Response Headers:
  content-type: application/json; charset=utf-8
  server: nginx/1.18.0
  location: /api/posts/101

🔧 [DEBUG] 📥 Response Body:
{
  "id": 101,
  "title": "Hello World",
  "body": "Test content",
  "userId": 1,
  "createdAt": "2023-12-01T10:30:00Z"
}
```

### 🛡️ Security Features

- **Automatic Sanitization**: Sensitive headers and body fields are automatically redacted
- **Configurable Sensitive Fields**: 
  - Headers: `authorization`, `x-api-key`, `cookie`, `x-auth-token`
  - Body: `password`, `token`, `secret`, `key`, `authorization`
- **Nested Object Support**: Deep sanitization of complex JSON structures
- **Performance Optimized**: Colors only applied when using ColorfulConsoleLogSink

### 🎛️ Custom Logger Configuration

```dart
// Basic logger (no colors/emojis)
final basicLogger = SmartLogger.basic(level: LogLevel.debug);

// Compact logger (minimal output)
final compactLogger = SmartLogger.compact(level: LogLevel.debug);

// Custom logger with specific settings
final customLogger = SmartLogger(
  level: LogLevel.debug,
  sensitiveHeaders: ['custom-auth', 'x-secret'],
  sensitiveBodyFields: ['customPassword', 'apiKey'],
  sinks: [ColorfulConsoleLogSink(
    enableColors: true,
    enableEmojis: true,
    compactMode: false,
  )],
);
```

## 🔧 Advanced Usage

### Custom Error Handling

```dart
final response = await client.get<Data>('/api/data', 
  transformer: (data) => Data.fromJson(data),
);

response.fold(
  (success) {
    // Handle success
    final data = success.data;
    final fromCache = success.isFromCache;
    final statusCode = success.statusCode;
  },
  (error) {
    // Handle different error types
    switch (error.type) {
      case SmartDioErrorType.network:
        showNetworkError();
        break;
      case SmartDioErrorType.timeout:
        showTimeoutError();
        break;
      case SmartDioErrorType.badResponse:
        showServerError(error.statusCode);
        break;
    }
  },
);
```

### Offline Queue Management

```dart
// Enable offline queueing (enabled by default)
final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
  config: const SmartDioConfig(
    enableRequestQueue: true,
    maxQueueSize: 100,
  ),
  requestQueue: RequestQueue(
    storage: MemoryQueueStorage(),
    maxSize: 50,
  ),
);

// Listen to queue events
client.queue.events.listen((event) {
  switch (event) {
    case QueueItemAdded():
      print('Request queued for later');
      break;
    case QueueItemRemoved():
      print('Request removed from queue');
      break;
    case QueueItemFailed():
      print('Queued request failed');
      break;
  }
});

// Manually control offline mode
client.connectivity.setManualOfflineMode(true);  // Force offline
client.connectivity.setManualOfflineMode(false); // Back online

// Check connectivity status
final connectivityInfo = client.connectivity.currentStatus;
print('Status: ${connectivityInfo.status}');
print('Quality: ${connectivityInfo.quality}');
```

## 🧪 Testing

SmartDio is designed to be test-friendly with easy mocking:

```dart
// Create a mock adapter for testing
class MockAdapter extends HttpClientAdapter {
  final Map<String, dynamic> mockResponses;
  
  MockAdapter(this.mockResponses);
  
  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    final mockData = mockResponses[request.uri.toString()];
    if (mockData == null) {
      return SmartDioError<T>(
        error: Exception('No mock response found'),
        type: SmartDioErrorType.network,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: Duration.zero,
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
final mockClient = SmartDioClient(
  adapter: MockAdapter({
    'https://api.example.com/users/1': {
      'id': 1,
      'name': 'Test User',
      'email': 'test@example.com'
    }
  }),
  config: const SmartDioConfig(),
);

final response = await mockClient.get<User>(
  'https://api.example.com/users/1',
  transformer: (data) => User.fromJson(data as Map<String, dynamic>),
);
```

## 📱 Example Apps

The package includes two comprehensive example apps:

### Main Example (`example/lib/main.dart`)
- **Multi-HTTP client switching** (Dio, HTTP, Chopper, dart:io HttpClient)
- **Interactive feature testing** with live UI
- **Real-time performance metrics** and analytics
- **Persistent cache management** with Hive
- **Colorized debug logging** with headers, payloads, and response bodies
- **Enhanced logging** with security-safe sensitive data redaction
- **Offline mode simulation** and queue management
- **Request deduplication** testing
- **Type-safe API demonstrations**

### Simple API Demo (`example/lib/example2.dart`)
- **Clean API service implementation**
- **All HTTP methods** (GET, POST, PUT, PATCH, DELETE)
- **Type-safe model examples** (User, Post, Comment)
- **Cache strategies** demonstration
- **Error handling** patterns
- **Performance metrics** integration

```bash
cd example
flutter run lib/main.dart        # Interactive multi-client demo
# or
flutter run lib/example2.dart    # Simple API demo
```

## 🏛️ Architecture

SmartDio uses clean architecture principles:

```
┌─────────────────────────────────────────┐
│             SmartDioClient              │
├─────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────────────┐ │
│  │   Config    │ │     Interceptors    │ │
│  └─────────────┘ └─────────────────────┘ │
├─────────────────────────────────────────┤
│  ┌─────────────┐ ┌──────────┐ ┌────────┐ │
│  │    Cache    │ │  Queue   │ │ Logger │ │
│  └─────────────┘ └──────────┘ └────────┘ │
├─────────────────────────────────────────┤
│            HTTP Adapters                │
│  ┌──────┐ ┌──────┐ ┌─────────┐ ┌──────┐ │
│  │ Dio  │ │ HTTP │ │ Chopper │ │ dart │ │
│  └──────┘ └──────┘ └─────────┘ └──────┘ │
└─────────────────────────────────────────┘
```

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) first.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🐛 Issues

If you encounter any issues, please [create an issue](https://github.com/rahulshahDEV/flutter_smartdio/issues) with:
- Flutter version
- Dart version
- SmartDio version
- Minimal reproduction code
- Error logs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by the need for a universal HTTP solution in Flutter
- Built with ❤️ for the Flutter community
- Thanks to all HTTP client library authors for their excellent work

## 🔗 Links

- [GitHub Repository](https://github.com/rahulshahDEV/flutter_smartdio)
- [Issue Tracker](https://github.com/rahulshahDEV/flutter_smartdio/issues)
- [Changelog](https://github.com/rahulshahDEV/flutter_smartdio/blob/main/CHANGELOG.md)

---

<div align="center">

**Made with ❤️ by [Rahul Shah](https://github.com/rahulshahDEV)**

If you find this package helpful, please ⭐ the repository!

</div>