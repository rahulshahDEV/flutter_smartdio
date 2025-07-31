import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_smartdio/flutter_smartdio.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartDioTestApp());
}

class SmartDioTestApp extends StatelessWidget {
  const SmartDioTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartDio Test App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SmartDioTestScreen(),
    );
  }
}

class SmartDioTestScreen extends StatefulWidget {
  const SmartDioTestScreen({super.key});

  @override
  State<SmartDioTestScreen> createState() => _SmartDioTestScreenState();
}

enum ClientType { httpClient, dio, httpPackage, chopper }

class _SmartDioTestScreenState extends State<SmartDioTestScreen> {
  late SmartDioClient client;
  final List<String> logs = [];
  final ScrollController _scrollController = ScrollController();
  bool isOfflineMode = false;
  ClientType currentClientType = ClientType.httpClient;

  // HTTP client instances
  late HttpClient httpClient;
  late dio.Dio dioClient;
  late http.Client httpPackageClient;
  late ChopperClient chopperClient;
  
  // Persistent cache store
  late HiveCacheStore cacheStore;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize cache store
    cacheStore = HiveCacheStore();
    await cacheStore.initialize();
    _addLog('💾 Initialized persistent cache store');
    
    // Show enhanced logging capabilities
    _demonstrateEnhancedLogging();

    // Initialize HTTP clients
    _initializeClients();
    
    // Initialize SmartDio client
    _initializeClient();
  }

  void _initializeClients() {
    httpClient = HttpClient();
    dioClient = dio.Dio();
    httpPackageClient = http.Client();
    chopperClient = ChopperClient();
  }

  HttpClientAdapter _getCurrentAdapter() {
    switch (currentClientType) {
      case ClientType.httpClient:
        return HttpClientAdapterImpl(client: httpClient);
      case ClientType.dio:
        return DioClientAdapter(dioInstance: dioClient);
      case ClientType.httpPackage:
        return HttpPackageAdapter(httpClient: httpPackageClient);
      case ClientType.chopper:
        return ChopperClientAdapter(chopperClient: chopperClient);
    }
  }

  void _initializeClient() {
    client = SmartDioClient(
        adapter: _getCurrentAdapter(),
        config: const SmartDioConfig(
          defaultTimeout: Duration(seconds: 10),
          retryPolicy: RetryPolicy.exponentialBackoff(
            maxAttempts: 3,
            initialDelay: Duration(milliseconds: 500),
          ),
          cachePolicy: CachePolicy.networkFirst(
            ttl: Duration(minutes: 10), // Increased TTL for better cache persistence
          ),
          logLevel: LogLevel.debug,
          enableMetrics: true,
          enableDeduplication: true,
          enableRequestQueue: true,
        ),
        cacheStore: cacheStore, // Use Hive persistent cache
        requestQueue: RequestQueue(
          storage: MemoryQueueStorage(),
          maxSize: 50,
        ),
        logger: SmartLogger()); // Uses ColorfulConsoleLogSink by default

    // Listen to events
    client.queue.events.listen(_onQueueEvent);
    client.metrics.events.listen(_onMetricsEvent);
    client.connectivity.statusStream.listen(_onConnectivityEvent);
  }

  void _switchClient(ClientType newClientType) async {
    if (newClientType == currentClientType) return;

    _addLog('🔄 Switching to ${_getClientName(newClientType)}...');

    // Dispose current client
    await client.dispose();

    // Update client type
    setState(() {
      currentClientType = newClientType;
    });

    // Initialize new client
    _initializeClient();

    _addLog('✅ Switched to ${_getClientName(newClientType)}');
  }

  String _getClientName(ClientType type) {
    switch (type) {
      case ClientType.httpClient:
        return 'dart:io HttpClient';
      case ClientType.dio:
        return 'Dio';
      case ClientType.httpPackage:
        return 'http package';
      case ClientType.chopper:
        return 'Chopper';
    }
  }

  void _demonstrateEnhancedLogging() {
    final logger = SmartLogger();
    
    // Demonstrate different log levels with emojis and colors
    logger.info('🎨 Enhanced SmartLogger initialized with colorful output!');
    logger.debug('🔧 Debug mode active - all HTTP requests will be logged');
    logger.warning('⚠️ This is a warning message example');
    logger.verbose('🔍 Verbose logging shows detailed information');
    
    // Demonstrate HTTP-specific logging
    logger.httpRequest('GET', 'https://api.example.com/test', 
      correlationId: 'demo-123');
    logger.cacheHit('test-key', age: Duration(minutes: 5));
    logger.cacheMiss('missing-key', reason: 'expired');
    
    _addLog('✨ Enhanced logging demonstration complete - check console for colorful output!');
  }

  void _addLog(String message) {
    setState(() {
      logs.add(
          '${DateTime.now().toIso8601String().substring(11, 19)} - $message');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onQueueEvent(QueueEvent event) {
    switch (event) {
      case QueueItemAdded():
        _addLog('📥 Item added to queue');
        break;
      case QueueItemRemoved():
        _addLog('📤 Item removed from queue');
        break;
      case QueueItemFailed():
        _addLog('❌ Queue item failed');
        break;
      default:
        _addLog('📋 Queue event: ${event.runtimeType}');
    }
  }

  void _onMetricsEvent(MetricsEvent event) {
    switch (event) {
      case RequestCompletedEvent(:final metrics):
        _addLog(
            '📊 Request completed in ${metrics.totalDuration.inMilliseconds}ms - ${metrics.success ? "SUCCESS" : "FAILED"}');
        break;
      case CacheHitEvent():
        _addLog('🎯 Cache hit');
        break;
      case CacheMissEvent():
        _addLog('❌ Cache miss');
        break;
      default:
        _addLog('📈 Metrics event: ${event.runtimeType}');
    }
  }

  void _onConnectivityEvent(ConnectivityInfo info) {
    _addLog('🌐 Connectivity: ${info.status} (${info.quality})');
  }

  Future<void> _testBasicGet() async {
    _addLog('🚀 Testing Basic GET Request...');

    final response = await client.get<Map<String, dynamic>>(
      'https://jsonplaceholder.typicode.com/posts/1',
      headers: {
        'User-Agent': 'SmartDio Flutter App/1.0',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      transformer: (data) => data as Map<String, dynamic>,
    );

    response.fold(
      (success) => _addLog(
          '✅ GET Success: ${success.data['title']?.toString().substring(0, 30)}...'),
      (error) =>
          _addLog('❌ GET Error: ${error.error.toString().substring(0, 50)}...'),
    );
  }

  Future<void> _testBasicPost() async {
    _addLog('🚀 Testing Basic POST Request...');

    final response = await client.post<Map<String, dynamic>>(
      'https://jsonplaceholder.typicode.com/posts',
      headers: {
        'User-Agent': 'SmartDio Flutter App/1.0',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: {
        'title': 'SmartDio Test Post',
        'body': 'Testing POST functionality',
        'userId': 1,
      },
      transformer: (data) => data as Map<String, dynamic>,
    );

    response.fold(
      (success) =>
          _addLog('✅ POST Success: Created with ID ${success.data['id']}'),
      (error) => _addLog(
          '❌ POST Error: ${error.error.toString().substring(0, 50)}...'),
    );
  }

  Future<void> _testRetryMechanism() async {
    _addLog('🚀 Testing Retry Mechanism (will fail)...');

    final response = await client.get<String>(
      'https://httpstat.us/500', // This endpoint returns 500 status
      headers: {
        'User-Agent': 'SmartDio Flutter App/1.0',
        'Accept': 'application/json',
      },
      config: const RequestConfig(
        retryPolicy: RetryPolicy.exponentialBackoff(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 200),
        ),
      ),
      transformer: (data) => data.toString(),
    );

    response.fold(
      (success) => _addLog('✅ Retry Success (unexpected)'),
      (error) => _addLog('❌ Retry Failed after ${error.retryCount} attempts'),
    );
  }

  Future<void> _testCaching() async {
    _addLog('🚀 Testing Persistent Cache Functionality...');

    final testUrl = 'https://jsonplaceholder.typicode.com/posts/2';
    const headers = {
      'User-Agent': 'SmartDio Flutter App/1.0',
      'Accept': 'application/json',
    };

    // First request - should miss cache
    _addLog('📡 Making first request (expect cache MISS)...');
    final response1 = await client.get<Map<String, dynamic>>(
      testUrl,
      headers: headers,
      config: const RequestConfig(
        cachePolicy: CachePolicy.networkFirst(ttl: Duration(minutes: 10)),
      ),
      transformer: (data) => data as Map<String, dynamic>,
    );

    response1.fold(
      (success) {
        _addLog('✅ First request SUCCESS');
        _addLog('📊 From cache: ${success.isFromCache}');
        _addLog('📄 Title: ${success.data['title']?.toString().substring(0, 20)}...');
      },
      (error) => _addLog('❌ First request failed: ${error.error}'),
    );

    // Small delay to show they're separate requests
    await Future.delayed(const Duration(milliseconds: 500));

    // Second request - should hit cache
    _addLog('📡 Making second request (expect cache HIT)...');
    final response2 = await client.get<Map<String, dynamic>>(
      testUrl,
      headers: headers,
      config: const RequestConfig(
        cachePolicy: CachePolicy.networkFirst(ttl: Duration(minutes: 10)),
      ),
      transformer: (data) => data as Map<String, dynamic>,
    );

    response2.fold(
      (success) {
        _addLog('✅ Second request SUCCESS');
        _addLog('📊 From cache: ${success.isFromCache}');
        _addLog('⚡ Cache is ${success.isFromCache ? "WORKING" : "NOT WORKING"}!');
      },
      (error) => _addLog('❌ Second request failed: ${error.error}'),
    );

    // Show cache stats
    final stats = await cacheStore.getStats();
    _addLog('💾 Cache entries: ${stats['validEntries']}/${stats['totalEntries']}');
  }

  Future<void> _testOfflineQueue() async {
    _addLog('🚀 Testing Offline Queue...');

    // Enable offline mode
    client.connectivity.setManualOfflineMode(true);
    _addLog('📴 Offline mode enabled');

    final response = await client.post<Map<String, dynamic>>(
      'https://jsonplaceholder.typicode.com/posts',
      body: {
        'title': 'Offline Post',
        'body': 'This should be queued',
        'userId': 1,
      },
      transformer: (data) => data as Map<String, dynamic>,
    );

    _addLog('📋 Queue size: ${client.queue.length}');

    response.fold(
      (success) => _addLog('✅ Request processed'),
      (error) => _addLog('📥 Request queued: ${error.error}'),
    );

    // Re-enable online mode
    client.connectivity.setManualOfflineMode(false);
    _addLog('🌐 Online mode restored');
  }

  Future<void> _testDeduplication() async {
    _addLog('🚀 Testing Request Deduplication...');

    // Send two identical requests quickly
    final futures = [
      client.get<Map<String, dynamic>>(
        'https://jsonplaceholder.typicode.com/posts/3',
        transformer: (data) => data as Map<String, dynamic>,
      ),
      client.get<Map<String, dynamic>>(
        'https://jsonplaceholder.typicode.com/posts/3',
        transformer: (data) => data as Map<String, dynamic>,
      ),
    ];

    final responses = await Future.wait(futures);
    _addLog('🔄 Sent 2 identical requests');
    _addLog('📊 Response 1 - From cache: ${responses[0].isFromCache}');
    _addLog('📊 Response 2 - From cache: ${responses[1].isFromCache}');
  }

  Future<void> _testTypesSafety() async {
    _addLog('🚀 Testing Type Safety...');

    final response = await client.get<User>(
      'https://jsonplaceholder.typicode.com/users/1',
      transformer: (data) => User.fromJson(data as Map<String, dynamic>),
    );

    response.fold(
      (success) => _addLog(
          '✅ Type Safe Success: ${success.data.name} (${success.data.email})'),
      (error) => _addLog('❌ Type Safe Error: ${error.error}'),
    );
  }

  void _showMetrics() async {
    final cacheMetrics = client.metrics.getCacheMetrics();
    final queueMetrics = client.metrics.getQueueMetrics(client.queue.length);
    final successRate = client.metrics.getSuccessRate();
    final avgTime = client.metrics.getAverageResponseTime();
    final cacheStats = await cacheStore.getStats();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Performance Metrics'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Performance Metrics
              const Text('📊 Performance Metrics', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Cache Hit Rate: ${(cacheMetrics.hitRate * 100).toStringAsFixed(1)}%'),
              Text('Cache Hits: ${cacheMetrics.hitCount}'),
              Text('Cache Misses: ${cacheMetrics.missCount}'),
              Text('Overall Success Rate: ${(successRate * 100).toStringAsFixed(1)}%'),
              Text('Average Response Time: ${avgTime.inMilliseconds}ms'),
              
              const SizedBox(height: 16),
              
              // Persistent Cache Stats
              const Text('💾 Persistent Cache (Hive)', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Total Entries: ${cacheStats['totalEntries']}'),
              Text('Valid Entries: ${cacheStats['validEntries']}'),
              Text('Expired Entries: ${cacheStats['expiredEntries']}'),
              Text('Total Size: ${(cacheStats['totalSizeBytes'] / 1024).toStringAsFixed(1)} KB'),
              
              const SizedBox(height: 16),
              
              // Queue Metrics
              const Text('📋 Queue Metrics', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Queue Size: ${queueMetrics.currentSize}'),
              Text('Queue Processed: ${queueMetrics.totalProcessed}'),
              Text('Queue Success Rate: ${(queueMetrics.successRate * 100).toStringAsFixed(1)}%'),
              
              const SizedBox(height: 16),
              
              // Connectivity
              const Text('🌐 Connectivity', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Status: ${client.connectivity.currentStatus.status}'),
              Text('Quality: ${client.connectivity.currentStatus.quality}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await cacheStore.clear();
              _addLog('🗑️ Persistent cache cleared');
              Navigator.of(context).pop();
            },
            child: const Text('Clear Cache'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      logs.clear();
    });
  }

  void _toggleOfflineMode() {
    setState(() {
      isOfflineMode = !isOfflineMode;
    });
    client.connectivity.setManualOfflineMode(isOfflineMode);
    _addLog('📴 Manual offline mode: ${isOfflineMode ? "ON" : "OFF"}');
  }

  @override
  void dispose() {
    client.dispose();
    _scrollController.dispose();

    // Dispose all HTTP clients
    httpClient.close();
    dioClient.close();
    httpPackageClient.close();
    chopperClient.dispose();
    
    // Close persistent cache
    cacheStore.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SmartDio - ${_getClientName(currentClientType)}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showMetrics,
            tooltip: 'Show Metrics',
          ),
          IconButton(
            icon: Icon(isOfflineMode ? Icons.wifi_off : Icons.wifi),
            onPressed: _toggleOfflineMode,
            tooltip: 'Toggle Offline Mode',
          ),
        ],
      ),
      body: Column(
        children: [
          // Client Toggle Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HTTP Client Selection:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildClientToggle(
                        'dart:io\nHttpClient',
                        ClientType.httpClient,
                        Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildClientToggle(
                        'Dio',
                        ClientType.dio,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildClientToggle(
                        'http\npackage',
                        ClientType.httpPackage,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildClientToggle(
                        'Chopper',
                        ClientType.chopper,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Buttons Section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: [
                  _buildTestButton(
                    '🚀 Basic GET',
                    Colors.green,
                    _testBasicGet,
                  ),
                  _buildTestButton(
                    '📝 Basic POST',
                    Colors.blue,
                    _testBasicPost,
                  ),
                  _buildTestButton(
                    '🔄 Test Retry',
                    Colors.orange,
                    _testRetryMechanism,
                  ),
                  _buildTestButton(
                    '💾 Test Cache',
                    Colors.purple,
                    _testCaching,
                  ),
                  _buildTestButton(
                    '📴 Offline Queue',
                    Colors.red,
                    _testOfflineQueue,
                  ),
                  _buildTestButton(
                    '🔄 Deduplication',
                    Colors.teal,
                    _testDeduplication,
                  ),
                  _buildTestButton(
                    '🎯 Type Safety',
                    Colors.indigo,
                    _testTypesSafety,
                  ),
                  _buildTestButton(
                    '🗑️ Clear Logs',
                    Colors.grey,
                    _clearLogs,
                  ),
                ],
              ),
            ),
          ),

          // Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(
                  isOfflineMode ? Icons.wifi_off : Icons.wifi,
                  color: isOfflineMode ? Colors.red : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Queue: ${client.queue.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Logs: ${logs.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Logs Section
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                border: Border.all(color: Colors.grey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[800],
                    child: const Row(
                      children: [
                        Icon(Icons.terminal, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Live Logs',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: log.contains('❌')
                                  ? Colors.red
                                  : log.contains('✅')
                                      ? Colors.green
                                      : log.contains('📊')
                                          ? Colors.blue
                                          : log.contains('🚀')
                                              ? Colors.yellow
                                              : Colors.white,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientToggle(String text, ClientType clientType, Color color) {
    final isSelected = currentClientType == clientType;
    return ElevatedButton(
      onPressed: () => _switchClient(clientType),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? color : Colors.grey[400]!,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// User model for type safety testing
class User {
  final int id;
  final String name;
  final String email;
  final String username;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
    );
  }

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}
