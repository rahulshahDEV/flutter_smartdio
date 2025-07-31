import 'lib/flutter_smartdio.dart';

void main() async {
  print('🚀 Testing SmartDio Package...');
  
  // Test that all classes can be instantiated
  final client = SmartDioClient(
    adapter: HttpClientAdapterImpl(),
    config: const SmartDioConfig(
      retryPolicy: RetryPolicy.exponentialBackoff(
        maxAttempts: 2,
        initialDelay: Duration(milliseconds: 100),
      ),
      cachePolicy: CachePolicy.networkFirst(),
      logLevel: LogLevel.info,
    ),
    cacheStore: MemoryCacheStore(),
    requestQueue: RequestQueue(
      storage: MemoryQueueStorage(),
    ),
  );

  print('✅ SmartDioClient created successfully');
  print('✅ All imports work correctly');
  print('✅ No undefined errors');
  
  // Test basic configuration
  print('📊 Configuration:');
  print('  - Retry Policy: ${client.config.retryPolicy}');
  print('  - Cache Policy: ${client.config.cachePolicy}');
  print('  - Log Level: ${client.config.logLevel}');
  print('  - Queue Size: ${client.queue.length}');
  print('  - Connectivity: ${client.connectivity.currentStatus.status}');

  print('🎯 Package test completed successfully!');
  
  await client.dispose();
}