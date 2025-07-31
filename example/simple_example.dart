import '../lib/flutter_smartdio.dart';

void main() async {
  print('🚀 Flutter SmartDio Example');
  
  // Create a simple client
  final client = SmartDioClient(
    adapter: HttpClientAdapterImpl(),
    config: const SmartDioConfig(
      logLevel: LogLevel.info,
      retryPolicy: RetryPolicy.exponentialBackoff(
        maxAttempts: 2,
        initialDelay: Duration(milliseconds: 100),
      ),
    ),
  );

  print('\n📊 Client Configuration:');
  print('- Retry Policy: ${client.config.retryPolicy}');
  print('- Cache Policy: ${client.config.cachePolicy}');
  print('- Log Level: ${client.config.logLevel}');
  print('- Metrics Enabled: ${client.config.enableMetrics}');

  print('\n🔌 Connectivity Status:');
  print('- Connected: ${client.connectivity.isConnected}');
  print('- Status: ${client.connectivity.currentStatus.status}');

  print('\n📋 Queue Status:');
  print('- Size: ${client.queue.length}');
  print('- Status: ${client.queue.status}');
  print('- Empty: ${client.queue.isEmpty}');

  print('\n📈 Metrics:');
  final cacheMetrics = client.metrics.getCacheMetrics();
  print('- Cache Hit Rate: ${(cacheMetrics.hitRate * 100).toStringAsFixed(1)}%');
  print('- Total Requests: ${cacheMetrics.totalRequests}');
  
  final queueMetrics = client.metrics.getQueueMetrics(client.queue.length);
  print('- Queue Success Rate: ${(queueMetrics.successRate * 100).toStringAsFixed(1)}%');

  print('\n🎯 Testing Offline Mode:');
  client.connectivity.setManualOfflineMode(true);
  print('- Manual offline mode enabled');
  print('- Is Connected: ${client.connectivity.isConnected}');

  // Test queuing a request
  final response = await client.post<Map<String, dynamic>>(
    'https://api.example.com/test',
    body: {'test': 'data'},
    transformer: (data) => data as Map<String, dynamic>,
  );

  print('- Response Type: ${response.runtimeType}');
  print('- Is Error: ${response.isError}');
  print('- Queue Size After Request: ${client.queue.length}');

  print('\n🧹 Cleanup:');
  await client.dispose();
  print('- Client disposed successfully');
  
  print('\n✅ Example completed successfully!');
}