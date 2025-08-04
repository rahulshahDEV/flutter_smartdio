import 'package:dio/dio.dart';
import 'package:flutter_smartdio/flutter_smartdio.dart';

/// Example demonstrating enhanced logging with custom transformers
/// This shows how the logger now displays actual response data instead of "Instance of User"

// Example User model with toJson method
class User {
  final int id;
  final String name;
  final String email;
  final String username;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
    };
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, username: $username)';
  }
}

// Example Post model without toJson method
class Post {
  final int id;
  final int userId;
  final String title;
  final String body;

  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  // Note: No toJson() method - this will test the logger's fallback behavior
}

Future<void> main() async {
  print('=== Enhanced Logging Examples ===\n');

  // Create client with debug logging
  final client = SmartDioClient(
    adapter: DioClientAdapter(dioInstance: Dio()),
    config: const SmartDioConfig(
      logLevel: LogLevel.debug, // Enable debug logging to see response bodies
      enableMetrics: true,
    ),
    logger: SmartLogger(level: LogLevel.debug),
  );

  await _testUserTransformer(client);
  await _testPostTransformer(client);
  await _testRawDataLogging(client);
  await _testComplexObjectLogging(client);

  await client.dispose();
  print('\n=== Enhanced Logging Examples Completed ===');
}

/// Test logging with User model that has toJson() method
Future<void> _testUserTransformer(SmartDioClient client) async {
  print('🧑 Testing User Transformer Logging...');
  print('Expected: Should show both raw JSON data and transformed User object');

  try {
    final response = await client.get<User>(
      'https://jsonplaceholder.typicode.com/users/1',
      transformer: (data) => User.fromJson(data as Map<String, dynamic>),
    );

    response.fold(
      (success) => print('✅ User fetched: ${success.data.name}'),
      (error) => print('❌ Error: ${error.error}'),
    );
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('');
}

/// Test logging with Post model that lacks toJson() method
Future<void> _testPostTransformer(SmartDioClient client) async {
  print('📝 Testing Post Transformer Logging...');
  print('Expected: Should show raw JSON data and attempt to extract Post info');

  try {
    final response = await client.get<Post>(
      'https://jsonplaceholder.typicode.com/posts/1',
      transformer: (data) => Post.fromJson(data as Map<String, dynamic>),
    );

    response.fold(
      (success) => print('✅ Post fetched: ${success.data.title}'),
      (error) => print('❌ Error: ${error.error}'),
    );
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('');
}

/// Test logging with raw data (no transformation)
Future<void> _testRawDataLogging(SmartDioClient client) async {
  print('📊 Testing Raw Data Logging...');
  print('Expected: Should show raw JSON response data');

  try {
    final response = await client.get<Map<String, dynamic>>(
      'https://jsonplaceholder.typicode.com/users/2',
      transformer: (data) => data as Map<String, dynamic>,
    );

    response.fold(
      (success) => print('✅ Raw data fetched: ${success.data['name']}'),
      (error) => print('❌ Error: ${error.error}'),
    );
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('');
}

/// Test logging with complex nested objects
Future<void> _testComplexObjectLogging(SmartDioClient client) async {
  print('🔄 Testing Complex Object Logging...');
  print('Expected: Should show raw JSON data and transformed list of objects');

  try {
    final response = await client.get<List<User>>(
      'https://jsonplaceholder.typicode.com/users?_limit=3',
      transformer: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );

    response.fold(
      (success) => print('✅ Users fetched: ${success.data.length} users'),
      (error) => print('❌ Error: ${error.error}'),
    );
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('');
}

