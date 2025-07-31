import 'dart:convert';
import 'package:meta/meta.dart';

enum LogLevel {
  none(0),
  error(1),
  warning(2),
  info(3),
  debug(4),
  verbose(5);

  const LogLevel(this.value);
  final int value;

  bool operator >=(LogLevel other) => value >= other.value;
  bool operator <=(LogLevel other) => value <= other.value;
  bool operator >(LogLevel other) => value > other.value;
  bool operator <(LogLevel other) => value < other.value;
}

@immutable
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? correlationId;
  final Map<String, dynamic> metadata;
  final Object? error;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.correlationId,
    this.metadata = const {},
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      if (correlationId != null) 'correlationId': correlationId,
      if (metadata.isNotEmpty) 'metadata': metadata,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('${timestamp.toIso8601String()} ');
    buffer.write('[${level.name.toUpperCase()}] ');
    if (correlationId != null) {
      buffer.write('[$correlationId] ');
    }
    buffer.write(message);
    
    if (metadata.isNotEmpty) {
      buffer.write(' - ${jsonEncode(metadata)}');
    }
    
    if (error != null) {
      buffer.write('\nError: $error');
    }
    
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    
    return buffer.toString();
  }
}

abstract class LogSink {
  void write(LogEntry entry);
  Future<void> flush();
  Future<void> close();
}

class ConsoleLogSink implements LogSink {
  @override
  void write(LogEntry entry) {
    print(entry.toString());
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

class SmartLogger {
  final LogLevel level;
  final List<String> sensitiveHeaders;
  final List<String> sensitiveBodyFields;
  final List<LogSink> sinks;

  SmartLogger({
    this.level = LogLevel.info,
    this.sensitiveHeaders = const [
      'authorization',
      'x-api-key',
      'x-auth-token',
      'cookie',
      'set-cookie',
    ],
    this.sensitiveBodyFields = const [
      'password',
      'token',
      'secret',
      'key',
      'authorization',
    ],
    List<LogSink>? sinks,
  }) : sinks = sinks ?? [ConsoleLogSink()];

  void log(
    LogLevel logLevel,
    String message, {
    String? correlationId,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (logLevel > level) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: logLevel,
      message: message,
      correlationId: correlationId,
      metadata: _sanitizeMetadata(metadata ?? {}),
      error: error,
      stackTrace: stackTrace,
    );

    for (final sink in sinks) {
      sink.write(entry);
    }
  }

  void error(
    String message, {
    String? correlationId,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.error,
      message,
      correlationId: correlationId,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void warning(
    String message, {
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    log(
      LogLevel.warning,
      message,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  void info(
    String message, {
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    log(
      LogLevel.info,
      message,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  void debug(
    String message, {
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    log(
      LogLevel.debug,
      message,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  void verbose(
    String message, {
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    log(
      LogLevel.verbose,
      message,
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> metadata) {
    final sanitized = <String, dynamic>{};

    for (final entry in metadata.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      if (_isSensitiveKey(key)) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (value is Map<String, dynamic>) {
        sanitized[entry.key] = _sanitizeMetadata(value);
      } else if (value is Map) {
        final stringMap = value.map((k, v) => MapEntry(k.toString(), v));
        sanitized[entry.key] = _sanitizeMetadata(stringMap);
      } else {
        sanitized[entry.key] = value;
      }
    }

    return sanitized;
  }

  bool _isSensitiveKey(String key) {
    return sensitiveHeaders.any((header) => key.contains(header.toLowerCase())) ||
           sensitiveBodyFields.any((field) => key.contains(field.toLowerCase()));
  }

  Future<void> flush() async {
    await Future.wait(sinks.map((sink) => sink.flush()));
  }

  Future<void> close() async {
    await Future.wait(sinks.map((sink) => sink.close()));
  }
}