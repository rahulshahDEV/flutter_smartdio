import 'package:dio/dio.dart';
import 'package:flutter_smartdio/flutter_smartdio.dart';

/// Example demonstrating different queue storage configurations
Future<void> main() async {
  print('=== SmartDio Queue Storage Examples ===\n');

  // Example 1: Persistent storage (default - survives app restart)
  await _demonstratePersistentStorage();

  // Example 2: Memory storage (lost on app restart)
  await _demonstrateMemoryStorage();

  // Example 3: No queue storage (queuing disabled)
  await _demonstrateNoStorage();

  // Example 4: Custom configuration
  await _demonstrateCustomConfiguration();
}

/// Persistent storage example - requests survive app restarts
Future<void> _demonstratePersistentStorage() async {
  print('📦 Persistent Storage Example');
  print('Requests are stored using Hive and survive app restarts\n');

  const config = SmartDioConfig(
    queueStorageType: QueueStorageType.persistent,
    maxQueueSize: 50,
    maxQueueAge: Duration(days: 3),
    enableRequestQueue: true,
  );

  final client = SmartDioClient(
    adapter: DioClientAdapter(dioInstance: Dio()),
    config: config,
  );

  // Simulate offline requests that will be persisted
  print('Making requests while "offline" (will be queued and persisted)...');

  try {
    await client.post<Map<String, dynamic>>(
      'https://jsonplaceholder.typicode.com/posts',
      body: {'title': 'Test Post 1', 'body': 'Test body 1'},
      transformer: (data) => data as Map<String, dynamic>,
    );
  } catch (e) {
    print('✓ Request queued: ${e.toString()}');
  }

  try {
    await client.put<Map<String, dynamic>>(
      'https://jsonplaceholder.typicode.com/posts/1',
      body: {'title': 'Updated Post', 'body': 'Updated body'},
      transformer: (data) => data as Map<String, dynamic>,
    );
  } catch (e) {
    print('✓ Request queued: ${e.toString()}');
  }

  // Check queue status
  print('Queue length: ${client.queue.length}');
  print('Requests will persist if app is restarted\n');

  await client.dispose();
}

/// Memory storage example - requests lost on app restart
Future<void> _demonstrateMemoryStorage() async {
  print('🧠 Memory Storage Example');
  print('Requests are stored in memory only and lost on app restart\n');

  const config = SmartDioConfig(
    queueStorageType: QueueStorageType.memory,
    maxQueueSize: 100,
    enableRequestQueue: true,
  );

  final client = SmartDioClient(
    adapter: DioClientAdapter(dioInstance: Dio()),
    config: config,
  );

  print('Making requests while "offline" (will be queued in memory only)...');

  try {
    await client.post<Map<String, dynamic>>(
      'https://jsonplaceholder.typicode.com/posts',
      body: {
        'title': 'Memory Test Post',
        'body': 'This will be lost on restart'
      },
      transformer: (data) => data as Map<String, dynamic>,
    );
  } catch (e) {
    print('✓ Request queued in memory: ${e.toString()}');
  }

  print('Queue length: ${client.queue.length}');
  print('These requests will be lost if app restarts\n');

  await client.dispose();
}

/// No storage example - queuing disabled
Future<void> _demonstrateNoStorage() async {
  print('🚫 No Storage Example');
  print('Request queuing is completely disabled\n');

  const config = SmartDioConfig(
    queueStorageType: QueueStorageType.none,
    enableRequestQueue: false,
  );

  final client = SmartDioClient(
    adapter: DioClientAdapter(dioInstance: Dio()),
    config: config,
  );

  print('Making request with queuing disabled...');

  try {
    await client.post<Map<String, dynamic>>(
      'https://jsonplaceholder.typicode.com/posts',
      body: {'title': 'No Queue Post', 'body': 'This will fail immediately'},
      transformer: (data) => data as Map<String, dynamic>,
    );
  } catch (e) {
    print('✗ Request failed immediately: ${e.toString()}');
  }

  print('Queue length: ${client.queue.length}');
  print('No requests are queued when offline\n');

  await client.dispose();
}

/// Custom configuration example
Future<void> _demonstrateCustomConfiguration() async {
  print('⚙️ Custom Configuration Example');
  print('Fine-tuned queue settings for specific use cases\n');

  const config = SmartDioConfig(
    queueStorageType: QueueStorageType.persistent,
    maxQueueSize: 20, // Smaller queue
    maxQueueAge: Duration(hours: 12), // Shorter retention
    enableRequestQueue: true,
    connectivityCheckInterval: Duration(seconds: 5),
  );

  final client = SmartDioClient(
    adapter: DioClientAdapter(dioInstance: Dio()),
    config: config,
  );

  print('Configuration:');
  print('- Storage: Persistent (Hive)');
  print('- Max queue size: 20 requests');
  print('- Max age: 12 hours');
  print('- Connectivity check: every 5 seconds');

  // Listen to queue events
  client.queue.events.listen((event) {
    print('Queue event: ${event.runtimeType}');
    if (event is QueueItemAdded) {
      print(
          '  → Added request: ${event.request.request.method} ${event.request.request.uri}');
    } else if (event is QueueItemEvicted) {
      print('  → Evicted request: ${event.correlationId}');
    }
  });

  // Add multiple requests to demonstrate queue management
  for (int i = 0; i < 5; i++) {
    try {
      await client.post<Map<String, dynamic>>(
        'https://jsonplaceholder.typicode.com/posts',
        body: {'title': 'Batch Post $i', 'body': 'Batch request $i'},
        transformer: (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      print('✓ Request $i queued');
    }
  }

  print('Final queue length: ${client.queue.length}\n');

  await client.dispose();
}

/// Helper to check storage configuration at runtime
void printStorageInfo(SmartDioClient client) {
  print('Current queue configuration:');
  print('- Enabled: ${client.config.enableRequestQueue}');
  print('- Storage type: ${client.config.queueStorageType}');
  print('- Max size: ${client.config.maxQueueSize}');
  print('- Max age: ${client.config.maxQueueAge}');
  print('- Current queue length: ${client.queue.length}');
}
