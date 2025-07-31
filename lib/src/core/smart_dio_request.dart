import 'package:meta/meta.dart';

@immutable
class SmartDioRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final dynamic body;
  final Duration? timeout;
  final Map<String, dynamic> extra;
  final String correlationId;
  final Set<String> tags;

  const SmartDioRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.body,
    this.timeout,
    this.extra = const {},
    required this.correlationId,
    this.tags = const {},
  });

  SmartDioRequest copyWith({
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
    Map<String, dynamic>? extra,
    String? correlationId,
    Set<String>? tags,
  }) {
    return SmartDioRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      timeout: timeout ?? this.timeout,
      extra: extra ?? this.extra,
      correlationId: correlationId ?? this.correlationId,
      tags: tags ?? this.tags,
    );
  }

  String get signature {
    final bodyHash = body?.hashCode ?? 0;
    final headersHash = headers.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|')
        .hashCode;
    return '$method:${uri.toString()}:$headersHash:$bodyHash';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartDioRequest &&
          runtimeType == other.runtimeType &&
          method == other.method &&
          uri == other.uri &&
          headers.length == other.headers.length &&
          _mapEquals(headers, other.headers) &&
          body == other.body &&
          timeout == other.timeout &&
          correlationId == other.correlationId;

  @override
  int get hashCode =>
      method.hashCode ^
      uri.hashCode ^
      headers.hashCode ^
      body.hashCode ^
      timeout.hashCode ^
      correlationId.hashCode;

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'SmartDioRequest(method: $method, uri: $uri, correlationId: $correlationId, tags: $tags)';
  }
}