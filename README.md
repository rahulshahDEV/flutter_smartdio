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
- **Request queuing** for offline scenarios
- **Automatic queue processing** when connectivity returns
- **Connectivity monitoring** with quality assessment
- **Seamless online/offline transitions**

### **📊 Advanced Monitoring**
- **Performance metrics** with response time tracking
- **Success rate analytics** and failure reporting
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
  flutter_smartdio: ^1.0.1
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
    logLevel: LogLevel.debug,
    enableMetrics: true,
    enableDeduplication: true,
    enableRequestQueue: true,
  ),
  cacheStore: HiveCacheStore(),
  requestQueue: RequestQueue(
    storage: MemoryQueueStorage(),
    maxSize: 50,
  ),
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
- **Enhanced logging** with colorful console output
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