import 'package:flutter/material.dart';
import 'package:flutter_smartdio/flutter_smartdio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartDio Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SmartDioDemo(),
    );
  }
}

// Data Models
class User {
  final int id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String website;

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.website,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      website: json['website'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'website': website,
    };
  }
}

class Post {
  final int id;
  final int userId;
  final String title;
  final String body;

  Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'userId': userId, 'title': title, 'body': body};
  }
}

class Comment {
  final int id;
  final int postId;
  final String name;
  final String email;
  final String body;

  Comment({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      postId: json['postId'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      body: json['body'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'name': name,
      'email': email,
      'body': body,
    };
  }
}

// API Service
class ApiService {
  late SmartDioClient _client;
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  Future<void> initialize() async {
    const config = SmartDioConfig(
      defaultTimeout: Duration(seconds: 30),
      retryPolicy: RetryPolicy.exponentialBackoff(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 500),
      ),
      cachePolicy: CachePolicy.networkOnly(),
      logLevel: LogLevel.debug,
      enableMetrics: true,
      enableRequestQueue: true,
    );

    _client = SmartDioClient(
      adapter: HttpClientAdapterImpl(),
      config: config,
      cacheStore: HiveCacheStore(),
      requestQueue: RequestQueue(storage: MemoryQueueStorage(), maxSize: 100),
    );
  }

  // GET Requests
  Future<SmartDioResponse<List<User>>> getUsers() async {
    return await _client.get<List<User>>(
      '$baseUrl/users',
      transformer: (data) {
        if (data is List) {
          return data
              .map((item) => User.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        throw Exception('Expected List but got ${data.runtimeType}');
      },
    );
  }

  Future<SmartDioResponse<User>> getUser(int id) async {
    return await _client.get<User>(
      '$baseUrl/users/$id',
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
    );
  }

  Future<SmartDioResponse<List<Post>>> getPosts() async {
    return await _client.get<List<Post>>(
      '$baseUrl/posts',
      transformer: (data) {
        if (data is List) {
          return data
              .map((item) => Post.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        throw Exception('Expected List but got ${data.runtimeType}');
      },
    );
  }

  Future<SmartDioResponse<Post>> getPost(int id) async {
    return await _client.get<Post>(
      '$baseUrl/posts/$id',
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return Post.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
    );
  }

  Future<SmartDioResponse<List<Comment>>> getComments() async {
    return await _client.get<List<Comment>>(
      '$baseUrl/comments',
      transformer: (data) {
        if (data is List) {
          return data
              .map((item) => Comment.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        throw Exception('Expected List but got ${data.runtimeType}');
      },
    );
  }

  Future<SmartDioResponse<List<Comment>>> getPostComments(int postId) async {
    return await _client.get<List<Comment>>(
      '$baseUrl/posts/$postId/comments',
      transformer: (data) {
        if (data is List) {
          return data
              .map((item) => Comment.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        throw Exception('Expected List but got ${data.runtimeType}');
      },
    );
  }

  // POST Requests
  Future<SmartDioResponse<Post>> createPost(Post post) async {
    return await _client.post<Post>(
      '$baseUrl/posts',
      body: post.toJson(),
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return Post.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
      config: const RequestConfig(cachePolicy: CachePolicy.networkOnly()),
    );
  }

  Future<SmartDioResponse<User>> createUser(User user) async {
    return await _client.post<User>(
      '$baseUrl/users',
      body: user.toJson(),
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
      config: const RequestConfig(cachePolicy: CachePolicy.networkOnly()),
    );
  }

  Future<SmartDioResponse<Comment>> createComment(Comment comment) async {
    return await _client.post<Comment>(
      '$baseUrl/comments',
      body: comment.toJson(),
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return Comment.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
      config: const RequestConfig(cachePolicy: CachePolicy.networkOnly()),
    );
  }

  // PUT Requests
  Future<SmartDioResponse<Post>> updatePost(int id, Post post) async {
    return await _client.put<Post>(
      '$baseUrl/posts/$id',
      body: post.toJson(),
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return Post.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
    );
  }

  Future<SmartDioResponse<User>> updateUser(int id, User user) async {
    return await _client.put<User>(
      '$baseUrl/users/$id',
      body: user.toJson(),
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
    );
  }

  // PATCH Requests
  Future<SmartDioResponse<Post>> patchPost(
    int id,
    Map<String, dynamic> updates,
  ) async {
    return await _client.patch<Post>(
      '$baseUrl/posts/$id',
      body: updates,
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return Post.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
    );
  }

  Future<SmartDioResponse<User>> patchUser(
    int id,
    Map<String, dynamic> updates,
  ) async {
    return await _client.patch<User>(
      '$baseUrl/users/$id',
      body: updates,
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
    );
  }

  // DELETE Requests
  Future<SmartDioResponse<Map<String, dynamic>>> deletePost(int id) async {
    return await _client.delete<Map<String, dynamic>>(
      '$baseUrl/posts/$id',
      transformer: (data) => data as Map<String, dynamic>? ?? {},
    );
  }

  Future<SmartDioResponse<Map<String, dynamic>>> deleteUser(int id) async {
    return await _client.delete<Map<String, dynamic>>(
      '$baseUrl/users/$id',
      transformer: (data) => data as Map<String, dynamic>? ?? {},
    );
  }

  Future<SmartDioResponse<Map<String, dynamic>>> deleteComment(int id) async {
    return await _client.delete<Map<String, dynamic>>(
      '$baseUrl/comments/$id',
      transformer: (data) => data as Map<String, dynamic>? ?? {},
    );
  }

  // Cache Examples
  Future<SmartDioResponse<User>> getUserWithCacheFirst(int id) async {
    return await _client.get<User>(
      '$baseUrl/users/$id',
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
      config: const RequestConfig(
        cachePolicy: CachePolicy.cacheFirst(ttl: Duration(minutes: 10)),
      ),
    );
  }

  Future<SmartDioResponse<User>> getUserNetworkOnly(int id) async {
    return await _client.get<User>(
      '$baseUrl/users/$id',
      transformer: (data) {
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
        throw Exception(
          'Expected Map<String, dynamic> but got ${data.runtimeType}',
        );
      },
      config: const RequestConfig(cachePolicy: CachePolicy.networkOnly()),
    );
  }

  // Get metrics
  double getSuccessRate() {
    return _client.metrics.getSuccessRate();
  }

  CacheMetrics getCacheMetrics() {
    return _client.metrics.getCacheMetrics();
  }

  int getQueueSize() {
    return _client.queue.length;
  }

  Future<void> dispose() async {
    await _client.dispose();
  }
}

// Demo UI
class SmartDioDemo extends StatefulWidget {
  const SmartDioDemo({super.key});

  @override
  State<SmartDioDemo> createState() => _SmartDioDemoState();
}

class _SmartDioDemoState extends State<SmartDioDemo> {
  final ApiService _apiService = ApiService();
  String _result = 'Tap buttons to test API calls';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeApi();
  }

  Future<void> _initializeApi() async {
    setState(() {
      _isLoading = true;
      _result = 'Initializing SmartDio...';
    });

    try {
      await _apiService.initialize();
      setState(() {
        _result = '✅ SmartDio initialized successfully!';
      });
    } catch (e) {
      setState(() {
        _result = '❌ Failed to initialize: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeRequest(
    String operation,
    Future<void> Function() request,
  ) async {
    setState(() {
      _isLoading = true;
      _result = 'Executing $operation...';
    });

    try {
      await request();
    } catch (e) {
      setState(() {
        _result = '❌ Error in $operation: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testGetUsers() async {
    await _executeRequest('GET Users', () async {
      final response = await _apiService.getUsers();
      response.fold(
        (success) {
          setState(() {
            _result = '✅ GET Users Success!\n'
                'Found ${success.data.length} users\n'
                'First user: ${success.data.first.name}\n'
                'From cache: ${success.isFromCache}\n'
                'Status: ${success.statusCode}';
          });
        },
        (error) {
          setState(() {
            _result = '❌ GET Users Error: ${error.error}';
          });
        },
      );
    });
  }

  Future<void> _testGetUser() async {
    await _executeRequest('GET User', () async {
      final response = await _apiService.getUserWithCacheFirst(1);
      response.fold(
        (success) {
          setState(() {
            _result = '✅ GET User Success!\n'
                'User: ${success.data.name}\n'
                'Email: ${success.data.email}\n'
                'From cache: ${success.isFromCache}\n'
                'Status: ${success.statusCode}';
          });
        },
        (error) {
          setState(() {
            _result = '❌ GET User Error: ${error.error}';
          });
        },
      );
    });
  }

  Future<void> _testCreatePost() async {
    await _executeRequest('POST Create Post', () async {
      final newPost = Post(
        id: 0,
        userId: 1,
        title: 'SmartDio Test Post',
        body: 'This is a test post created with SmartDio',
      );

      final response = await _apiService.createPost(newPost);
      response.fold(
        (success) {
          setState(() {
            _result = '✅ POST Create Post Success!\n'
                'Created Post ID: ${success.data.id}\n'
                'Title: ${success.data.title}\n'
                'Status: ${success.statusCode}';
          });
        },
        (error) {
          setState(() {
            _result = '❌ POST Create Post Error: ${error.error}';
          });
        },
      );
    });
  }

  Future<void> _testUpdatePost() async {
    await _executeRequest('PUT Update Post', () async {
      final updatedPost = Post(
        id: 1,
        userId: 1,
        title: 'Updated Post Title',
        body: 'This post was updated using SmartDio PUT request',
      );

      final response = await _apiService.updatePost(1, updatedPost);
      response.fold(
        (success) {
          setState(() {
            _result = '✅ PUT Update Post Success!\n'
                'Updated Post ID: ${success.data.id}\n'
                'New Title: ${success.data.title}\n'
                'Status: ${success.statusCode}';
          });
        },
        (error) {
          setState(() {
            _result = '❌ PUT Update Post Error: ${error.error}';
          });
        },
      );
    });
  }

  Future<void> _testPatchPost() async {
    await _executeRequest('PATCH Post', () async {
      final updates = {'title': 'Patched Title via SmartDio'};

      final response = await _apiService.patchPost(1, updates);
      response.fold(
        (success) {
          setState(() {
            _result = '✅ PATCH Post Success!\n'
                'Patched Post ID: ${success.data.id}\n'
                'New Title: ${success.data.title}\n'
                'Status: ${success.statusCode}';
          });
        },
        (error) {
          setState(() {
            _result = '❌ PATCH Post Error: ${error.error}';
          });
        },
      );
    });
  }

  Future<void> _testDeletePost() async {
    await _executeRequest('DELETE Post', () async {
      final response = await _apiService.deletePost(1);
      response.fold(
        (success) {
          setState(() {
            _result = '✅ DELETE Post Success!\n'
                'Status: ${success.statusCode}\n'
                'Response: ${success.data}';
          });
        },
        (error) {
          setState(() {
            _result = '❌ DELETE Post Error: ${error.error}';
          });
        },
      );
    });
  }

  Future<void> _testCacheFirst() async {
    await _executeRequest('Cache First Request', () async {
      final response = await _apiService.getUserWithCacheFirst(1);
      response.fold(
        (success) {
          setState(() {
            _result = '✅ Cache First Success!\n'
                'User: ${success.data.name}\n'
                'From cache: ${success.isFromCache}\n'
                'Status: ${success.statusCode}';
          });
        },
        (error) {
          setState(() {
            _result = '❌ Cache First Error: ${error.error}';
          });
        },
      );
    });
  }

  Future<void> _showMetrics() async {
    final successRate = _apiService.getSuccessRate();
    final cacheMetrics = _apiService.getCacheMetrics();
    final queueSize = _apiService.getQueueSize();

    setState(() {
      _result = '📊 SmartDio Metrics\n'
          'Success Rate: ${(successRate * 100).toStringAsFixed(1)}%\n'
          'Cache Hit Rate: ${(cacheMetrics.hitRate * 100).toStringAsFixed(1)}%\n'
          'Cache Hits: ${cacheMetrics.hitCount}\n'
          'Cache Misses: ${cacheMetrics.missCount}\n'
          'Queue Size: $queueSize';
    });
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartDio API Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Text(
                          _result,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testGetUsers,
                  child: const Text('GET Users'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testGetUser,
                  child: const Text('GET User'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testCreatePost,
                  child: const Text('POST Create'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testUpdatePost,
                  child: const Text('PUT Update'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testPatchPost,
                  child: const Text('PATCH'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testDeletePost,
                  child: const Text('DELETE'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testCacheFirst,
                  child: const Text('Cache First'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _showMetrics,
                  child: const Text('Show Metrics'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
