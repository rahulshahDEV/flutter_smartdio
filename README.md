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
  flutter_smartdio: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## ⚡ Quick Start

### 1. Basic Setup

```dart
import 'package:flutter_smartdio/flutter_smartdio.dart';
import 'package:dio/dio.dart';

// Initialize with any HTTP client
final client = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  config: const SmartDioConfig(
    defaultTimeout: Duration(seconds: 10),
    cachePolicy: CachePolicy.networkFirst(
      ttl: Duration(minutes: 5),
    ),
    enableMetrics: true,
  ),
  cacheStore: HiveCacheStore(), // Persistent cache
);
```

### 2. Making Requests

```dart
// Type-safe GET request
final response = await client.get<User>(
  'https://api.example.com/users/1',
  transformer: (data) => User.fromJson(data),
);

response.fold(
  (success) => print('User: ${success.data.name}'),
  (error) => print('Error: ${error.error}'),
);

// POST request with caching
final postResponse = await client.post<Map<String, dynamic>>(
  'https://api.example.com/posts',
  body: {'title': 'Hello World', 'userId': 1},
  config: const RequestConfig(
    cachePolicy: CachePolicy.networkFirst(ttl: Duration(hours: 1)),
  ),
  transformer: (data) => data as Map<String, dynamic>,
);
```

### 3. Switch HTTP Clients Seamlessly

```dart
// Start with Dio
final client = SmartDioClient(
  adapter: DioClientAdapter(dioInstance: Dio()),
  // ... config
);

// Switch to HTTP package - same API!
await client.dispose();
final newClient = SmartDioClient(
  adapter: HttpPackageAdapter(httpClient: http.Client()),
  // ... same config
);

// Or use dart:io HttpClient
final httpClient = SmartDioClient(
  adapter: HttpClientAdapterImpl(client: HttpClient()),
  // ... same config
);
```

## 🏗️ Supported HTTP Clients

| Client | Adapter Class | Package |
|--------|---------------|---------|
| **Dio** | `DioClientAdapter` | `dio: ^5.8.0` |
| **HTTP Package** | `HttpPackageAdapter` | `http: ^1.4.0` |
| **Chopper** | `ChopperClientAdapter` | `chopper: ^7.4.0` |
| **dart:io HttpClient** | `HttpClientAdapterImpl` | Built-in |

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
// Exponential backoff
RetryPolicy.exponentialBackoff(
  maxAttempts: 3,
  initialDelay: Duration(milliseconds: 500),
)

// Fixed delay
RetryPolicy.fixedDelay(
  maxAttempts: 5,
  delay: Duration(seconds: 1),
)

// Custom retry logic
RetryPolicy.custom((attempt, error) {
  return attempt < 3 && error is NetworkException;
})
```

## 📊 Monitoring & Analytics

```dart
// Listen to performance metrics
client.metrics.events.listen((event) {
  if (event is RequestCompletedEvent) {
    print('Request took: ${event.metrics.totalDuration}');
    print('Success: ${event.metrics.success}');
  }
});

// Get real-time statistics
final cacheMetrics = client.metrics.getCacheMetrics();
print('Cache hit rate: ${cacheMetrics.hitRate * 100}%');

final successRate = client.metrics.getSuccessRate();
print('Overall success rate: ${successRate * 100}%');
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
// Enable offline queueing
final client = SmartDioClient(
  // ... other config
  config: const SmartDioConfig(
    enableRequestQueue: true,
  ),
  requestQueue: RequestQueue(
    storage: MemoryQueueStorage(),
    maxSize: 100,
  ),
);

// Listen to queue events
client.queue.events.listen((event) {
  switch (event) {
    case QueueItemAdded():
      print('Request queued for later');
      break;
    case QueueItemProcessed():
      print('Queued request completed');
      break;
  }
});
```

## 🧪 Testing

The package includes comprehensive testing utilities:

```dart
// Mock adapter for testing
final mockClient = SmartDioClient(
  adapter: MockHttpAdapter(),
  config: const SmartDioConfig(),
);

// Test with fake responses
mockClient.adapter.setResponse('/api/test', {'result': 'success'});

final response = await mockClient.get('/api/test',
  transformer: (data) => data,
);
// Verify response...
```

## 📱 Example App

Check out the comprehensive example app in the `/example` folder that demonstrates:

- **Multi-client switching** with real-time UI updates
- **All SmartDio features** with interactive testing
- **Performance monitoring** with live metrics
- **Cache management** with statistics
- **Beautiful UI** with material design

```bash
cd example
flutter run
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

---

<div align="center">

**Made with ❤️ by [Rahul Shah](https://github.com/rahulshahDEV)**

If you find this package helpful, please ⭐ the repository!

</div>

- **Transport Agnostic**: Works with any HTTP client (Dio, http, Chopper, etc.) through adapter pattern
- **Offline Support**: Automatic request queuing when offline with smart sync
- **Intelligent Caching**: Multiple cache strategies with TTL and automatic cleanup  
- **Retry Policies**: Exponential backoff, fixed delay, and custom retry strategies
- **Never Crashes**: Always returns structured success/error results
- **Rich Logging**: Sensitive data protection and configurable verbosity
- **Performance Metrics**: Request timing, success rates, cache performance
- **Request Deduplication**: Prevent duplicate requests within time windows
- **Connectivity Awareness**: Real-time network status monitoring
- **Type Safety**: Full generic support for response transformation

## 🏗️ Architecture

Flutter SmartDio follows a clean, dependency-injectable architecture:

- **Minimal Dependencies**: Only Flutter/Dart core dependencies
- **Pluggable Components**: Every component is swappable through interfaces
- **Custom Implementations**: Built natively before considering external packages
- **Configuration Over Convention**: Highly configurable per-request and globally

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_smartdio: ^1.0.0
```

## 🎯 Quick Start

### Basic Usage

```dart
import 'package:flutter_smartdio/flutter_smartdio.dart';

final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
);

final response = await client.get<Map<String, dynamic>>(
  'https://api.example.com/users/1',
  transformer: (data) => data as Map<String, dynamic>,
);

response.fold(
  (success) => print('User: ${success.data}'),
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
  ),
  cachePolicy: const CachePolicy.networkFirst(
    ttl: Duration(minutes: 5),
  ),
  logLevel: LogLevel.debug,
);

final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
  config: config,
  cacheStore: MemoryCacheStore(),
  requestQueue: RequestQueue(
    storage: MemoryQueueStorage(),
  ),
);
```

### Type-Safe Responses

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

final response = await client.get<User>(
  'https://api.example.com/users/1',
  transformer: (data) => User.fromJson(data as Map<String, dynamic>),
);

response.fold(
  (success) => print('User: ${success.data.name}'),
  (error) => print('Failed: ${error.error}'),
);
```

## 🔄 Retry Policies

### Exponential Backoff
```dart
const retryPolicy = RetryPolicy.exponentialBackoff(
  maxAttempts: 3,
  initialDelay: Duration(milliseconds: 500),
  multiplier: 2.0,
  jitter: true,
);
```

### Fixed Delay
```dart
const retryPolicy = RetryPolicy.fixed(
  maxAttempts: 3,
  delay: Duration(seconds: 1),
);
```

### Custom Logic
```dart
final retryPolicy = RetryPolicy.custom(
  maxAttempts: 5,
  delayCalculator: (attempt) => Duration(seconds: attempt * 2),
  shouldRetry: (error) => error.type == SmartDioErrorType.network,
);
```

## 💾 Caching Strategies

### Network First
```dart
const cachePolicy = CachePolicy.networkFirst(
  ttl: Duration(minutes: 5),
);
```

### Cache First
```dart
const cachePolicy = CachePolicy.cacheFirst(
  ttl: Duration(hours: 1),
);
```

### Cache Only / Network Only
```dart
const cacheOnly = CachePolicy.cacheOnly();
const networkOnly = CachePolicy.networkOnly();
```

## 📱 Offline Support

SmartDio automatically queues requests when offline:

```dart
// Enable request queuing
final client = SmartDioClient(
  adapter: HttpClientAdapterImpl(),
  config: const SmartDioConfig(
    enableRequestQueue: true,
  ),
);

// Requests are automatically queued when offline
await client.post<Map<String, dynamic>>(
  'https://api.example.com/posts',
  body: {'title': 'My Post'},
  transformer: (data) => data as Map<String, dynamic>,
);

// Check queue status
print('Queue size: ${client.queue.length}');
print('Queue status: ${client.queue.status}');
```

## 📊 Performance Metrics

```dart
// Get request metrics
final metrics = client.metrics.getLatestRequest();
print('Duration: ${metrics?.totalDuration}');
print('Success: ${metrics?.success}');

// Get cache performance
final cacheMetrics = client.metrics.getCacheMetrics();
print('Hit rate: ${cacheMetrics.hitRate * 100}%');

// Get success rate
final successRate = client.metrics.getSuccessRate();
print('Success rate: ${successRate * 100}%');
```

## 🔌 Custom Adapters

Create adapters for any HTTP client:

```dart
class MyCustomAdapter extends HttpClientAdapter {
  final MyHttpClient _client;

  MyCustomAdapter(this._client);

  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    // Implement your HTTP client logic here
    try {
      final response = await _client.send(request);
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
        type: SmartDioErrorType.network,
        correlationId: request.correlationId,
        timestamp: DateTime.now(),
        duration: Duration.zero,
      );
    }
  }

  @override
  Future<void> close() async {
    await _client.close();
  }
}
```

## 🔐 Security

SmartDio automatically redacts sensitive information in logs:

```dart
final logger = SmartLogger(
  sensitiveHeaders: ['authorization', 'x-api-key'],
  sensitiveBodyFields: ['password', 'secret'],
);
```

## 🎛️ Interceptors

Add custom request/response processing:

```dart
class AuthInterceptor extends SmartDioInterceptor {
  @override
  Future<SmartDioRequest> onRequest(SmartDioRequest request) async {
    return request.copyWith(
      headers: {...request.headers, 'Authorization': 'Bearer $token'},
    );
  }
}

client.interceptors.add(AuthInterceptor());
```

## 📈 Monitoring

Listen to real-time events:

```dart
// Queue events
client.queue.events.listen((event) {
  print('Queue event: $event');
});

// Metrics events  
client.metrics.events.listen((event) {
  print('Metrics event: $event');
});

// Connectivity events
client.connectivity.statusStream.listen((status) {
  print('Connectivity: ${status.status}');
});
```

## 🧪 Testing

SmartDio is designed to be test-friendly:

```dart
class MockAdapter extends HttpClientAdapter {
  final Map<String, dynamic> mockResponses;
  
  MockAdapter(this.mockResponses);
  
  @override
  Future<SmartDioResponse<T>> execute<T>({
    required SmartDioRequest request,
    required T Function(dynamic data) transformer,
  }) async {
    final mockData = mockResponses[request.uri.toString()];
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
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Documentation](https://github.com/your-org/flutter_smartdio/wiki)
- [Issue Tracker](https://github.com/your-org/flutter_smartdio/issues)
- [Changelog](https://github.com/your-org/flutter_smartdio/blob/main/CHANGELOG.md)