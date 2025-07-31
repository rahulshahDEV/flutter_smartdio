import 'package:meta/meta.dart';

@immutable
sealed class CachePolicy {
  const CachePolicy();

  const factory CachePolicy.none() = NoCachePolicy;
  
  const factory CachePolicy.networkFirst({
    Duration? ttl,
    Set<String> cacheMethods,
    Set<int> cacheStatusCodes,
  }) = NetworkFirstCachePolicy;
  
  const factory CachePolicy.cacheFirst({
    Duration? ttl,
    Set<String> cacheMethods,
    Set<int> cacheStatusCodes,
  }) = CacheFirstCachePolicy;
  
  const factory CachePolicy.cacheOnly() = CacheOnlyCachePolicy;
  
  const factory CachePolicy.networkOnly() = NetworkOnlyCachePolicy;

  bool shouldCache(String method, int statusCode);
  bool shouldUseCache(String method);
  Duration? get ttl;
}

@immutable
final class NoCachePolicy extends CachePolicy {
  const NoCachePolicy();

  @override
  bool shouldCache(String method, int statusCode) => false;

  @override
  bool shouldUseCache(String method) => false;

  @override
  Duration? get ttl => null;

  @override
  String toString() => 'NoCachePolicy()';
}

@immutable
final class NetworkFirstCachePolicy extends CachePolicy {
  @override
  final Duration? ttl;
  final Set<String> cacheMethods;
  final Set<int> cacheStatusCodes;

  const NetworkFirstCachePolicy({
    this.ttl = const Duration(minutes: 5),
    this.cacheMethods = const {'GET', 'HEAD'},
    this.cacheStatusCodes = const {200, 201, 204, 300, 301, 302, 404, 410},
  });

  @override
  bool shouldCache(String method, int statusCode) {
    return cacheMethods.contains(method.toUpperCase()) &&
           cacheStatusCodes.contains(statusCode);
  }

  @override
  bool shouldUseCache(String method) => cacheMethods.contains(method.toUpperCase());

  @override
  String toString() => 'NetworkFirstCachePolicy(ttl: $ttl)';
}

@immutable
final class CacheFirstCachePolicy extends CachePolicy {
  @override
  final Duration? ttl;
  final Set<String> cacheMethods;
  final Set<int> cacheStatusCodes;

  const CacheFirstCachePolicy({
    this.ttl = const Duration(minutes: 5),
    this.cacheMethods = const {'GET', 'HEAD'},
    this.cacheStatusCodes = const {200, 201, 204, 300, 301, 302, 404, 410},
  });

  @override
  bool shouldCache(String method, int statusCode) {
    return cacheMethods.contains(method.toUpperCase()) &&
           cacheStatusCodes.contains(statusCode);
  }

  @override
  bool shouldUseCache(String method) => cacheMethods.contains(method.toUpperCase());

  @override
  String toString() => 'CacheFirstCachePolicy(ttl: $ttl)';
}

@immutable
final class CacheOnlyCachePolicy extends CachePolicy {
  const CacheOnlyCachePolicy();

  @override
  bool shouldCache(String method, int statusCode) => false;

  @override
  bool shouldUseCache(String method) => true;

  @override
  Duration? get ttl => null;

  @override
  String toString() => 'CacheOnlyCachePolicy()';
}

@immutable
final class NetworkOnlyCachePolicy extends CachePolicy {
  const NetworkOnlyCachePolicy();

  @override
  bool shouldCache(String method, int statusCode) => false;

  @override
  bool shouldUseCache(String method) => false;

  @override
  Duration? get ttl => null;

  @override
  String toString() => 'NetworkOnlyCachePolicy()';
}

abstract class CacheStore {
  Future<CacheEntry?> get(String key);
  Future<void> set(String key, CacheEntry entry);
  Future<void> remove(String key);
  Future<void> clear();
  Future<List<String>> keys();
  Future<void> cleanup();
}

@immutable
class CacheEntry {
  final dynamic data;
  final DateTime createdAt;
  final Duration? ttl;
  final Map<String, String> headers;

  const CacheEntry({
    required this.data,
    required this.createdAt,
    this.ttl,
    this.headers = const {},
  });

  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().isAfter(createdAt.add(ttl!));
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'ttl': ttl?.inMilliseconds,
      'headers': headers,
    };
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'],
      createdAt: DateTime.parse(json['createdAt']),
      ttl: json['ttl'] != null ? Duration(milliseconds: json['ttl']) : null,
      headers: Map<String, String>.from(json['headers'] ?? {}),
    );
  }
}