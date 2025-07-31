import '../lib/flutter_smartdio.dart';

void main() async {
  await basicUsageExample();
  await advancedUsageExample();
  await offlineQueueExample();
}

Future<void> basicUsageExample() async {
  print('=== Basic Usage Example ===');

  final client = SmartDioClient(adapter: HttpClientAdapterImpl());

  final response = await client.get<Map<String, dynamic>>(
    'https://jsonplaceholder.typicode.com/posts/1',
    transformer: (data) => data as Map<String, dynamic>,
  );

  response.fold(
    (success) => print('Success: ${success.data['title']}'),
    (error) => print('Error: ${error.error}'),
  );

  await client.dispose();
}

Future<void> advancedUsageExample() async {
  print('\n=== Advanced Usage Example ===');

  final config = SmartDioConfig(
    defaultTimeout: const Duration(seconds: 10),
    retryPolicy: const RetryPolicy.exponentialBackoff(
      maxAttempts: 3,
      initialDelay: Duration(milliseconds: 500),
    ),
    cachePolicy: const CachePolicy.networkFirst(ttl: Duration(minutes: 5)),
    logLevel: LogLevel.debug,
  );

  final client = SmartDioClient(
    adapter: HttpClientAdapterImpl(),
    config: config,
    cacheStore: MemoryCacheStore(),
    requestQueue: RequestQueue(storage: MemoryQueueStorage()),
  );

  final response = await client.post<Map<String, dynamic>>(
    'https://jsonplaceholder.typicode.com/posts',
    body: {'title': 'foo', 'body': 'bar', 'userId': 1},
    config: const RequestConfig(tags: {'user-action', 'create-post'}),
    transformer: (data) => data as Map<String, dynamic>,
  );

  print('Status: ${response.isSuccess ? 'Success' : 'Error'}');
  print('From cache: ${response.isFromCache}');
  print('Retry count: ${response.retryCount}');

  await client.dispose();
}

Future<void> offlineQueueExample() async {
  print('\n=== Offline Queue Example ===');

  final client = SmartDioClient(
    adapter: HttpClientAdapterImpl(),
    config: const SmartDioConfig(enableRequestQueue: true),
    requestQueue: RequestQueue(storage: MemoryQueueStorage(), maxSize: 50),
  );

  client.connectivity.setManualOfflineMode(true);

  final response = await client.post<Map<String, dynamic>>(
    'https://jsonplaceholder.typicode.com/posts',
    body: {'title': 'Offline post'},
    transformer: (data) => data as Map<String, dynamic>,
  );

  if (response.isError) {
    print('Request queued: ${client.queue.length} items in queue');
  }

  client.connectivity.setManualOfflineMode(false);

  print('Queue status: ${client.queue.status}');
  print('Queue size: ${client.queue.length}');

  await client.dispose();
}

class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(id: json['id'], name: json['name'], email: json['email']);
  }

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}

Future<void> typedResponseExample() async {
  print('\n=== Typed Response Example ===');

  final client = SmartDioClient(adapter: HttpClientAdapterImpl());

  final response = await client.get<User>(
    'https://jsonplaceholder.typicode.com/users/1',
    transformer: (data) => User.fromJson(data as Map<String, dynamic>),
  );

  response.fold(
    (success) => print('User: ${success.data}'),
    (error) => print('Failed to load user: ${error.error}'),
  );

  await client.dispose();
}
