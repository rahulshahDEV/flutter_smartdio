import 'dart:convert';
import 'package:meta/meta.dart';

/// Defines the severity levels for logging messages.
/// 
/// Log levels are ordered from least to most verbose, allowing for
/// filtering of log messages based on their importance.
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

/// Represents a single log entry with metadata and optional error information.
/// 
/// This immutable class captures all the information about a log event,
/// including timing, correlation IDs for request tracking, and error details.
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

/// Enhanced console sink with colors and emojis for better visual output
class ColorfulConsoleLogSink implements LogSink {
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';
  
  // Text colors
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';
  static const String _white = '\x1B[37m';
  static const String _gray = '\x1B[90m';
  
  // Background colors
  static const String _bgRed = '\x1B[41m';
  static const String _bgYellow = '\x1B[43m';
  static const String _bgBlue = '\x1B[44m';
  static const String _bgMagenta = '\x1B[45m';
  static const String _bgCyan = '\x1B[46m';

  final bool enableColors;
  final bool enableEmojis;
  final bool showTimestamp;
  final bool showCorrelationId;
  final bool compactMode;

  ColorfulConsoleLogSink({
    this.enableColors = true,
    this.enableEmojis = true,
    this.showTimestamp = true,
    this.showCorrelationId = true,
    this.compactMode = false,
  });

  @override
  void write(LogEntry entry) {
    final output = _formatLogEntry(entry);
    print(output);
  }

  String _formatLogEntry(LogEntry entry) {
    final buffer = StringBuffer();
    
    // Add emoji and level with colors
    final levelInfo = _getLevelInfo(entry.level);
    
    if (!compactMode) {
      // Full format with colors and styling
      buffer.write(_applyColor(levelInfo.color, '${levelInfo.emoji} ${levelInfo.badge}'));
      
      if (showTimestamp) {
        final timeStr = _formatTime(entry.timestamp);
        buffer.write(' ${_applyColor(_gray, timeStr)}');
      }
      
      if (showCorrelationId && entry.correlationId != null) {
        buffer.write(' ${_applyColor(_cyan, '[${entry.correlationId}]')}');
      }
      
      buffer.write(' ${_applyColor(levelInfo.textColor, entry.message)}');
      
      // Add metadata if present
      if (entry.metadata.isNotEmpty) {
        buffer.write('\n${_formatMetadata(entry.metadata)}');
      }
      
      // Add error if present
      if (entry.error != null) {
        buffer.write('\n${_applyColor(_red, '💥 Error: ${entry.error}')}');
      }
      
      // Add stack trace if present (truncated)
      if (entry.stackTrace != null) {
        final stackLines = entry.stackTrace.toString().split('\n').take(3);
        buffer.write('\n${_applyColor(_dim + _gray, '📚 Stack: ${stackLines.join(' → ')}')}');
      }
    } else {
      // Compact format
      buffer.write('${levelInfo.emoji} ${_applyColor(levelInfo.textColor, entry.message)}');
      
      if (entry.correlationId != null) {
        buffer.write(' ${_applyColor(_dim + _cyan, '[${entry.correlationId}]')}');
      }
    }
    
    return buffer.toString();
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute}';
    }
  }

  String _formatMetadata(Map<String, dynamic> metadata) {
    final buffer = StringBuffer();
    buffer.write('${_applyColor(_cyan, '📋 Metadata:')}');
    
    for (final entry in metadata.entries) {
      final key = entry.key;
      final value = entry.value;
      
      buffer.write('\n  ${_applyColor(_blue, '▪ $key:')} ');
      
      if (value is String && value == '[REDACTED]') {
        buffer.write(_applyColor(_red + _bold, '🔒 [REDACTED]'));
      } else if (value is Map || value is List) {
        buffer.write(_applyColor(_magenta, '${_truncateValue(value.toString())}'));
      } else {
        buffer.write(_applyColor(_green, '${_truncateValue(value.toString())}'));
      }
    }
    
    return buffer.toString();
  }

  String _truncateValue(String value, {int maxLength = 100}) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  _LevelInfo _getLevelInfo(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return _LevelInfo(
          emoji: '🚨',
          badge: '${_bgRed}${_white} ERROR $_reset',
          color: _red,
          textColor: _red + _bold,
        );
      case LogLevel.warning:
        return _LevelInfo(
          emoji: '⚠️',
          badge: '${_bgYellow}${_white} WARN  $_reset',
          color: _yellow,
          textColor: _yellow + _bold,
        );
      case LogLevel.info:
        return _LevelInfo(
          emoji: '💡',
          badge: '${_bgBlue}${_white} INFO  $_reset',
          color: _blue,
          textColor: _blue,
        );
      case LogLevel.debug:
        return _LevelInfo(
          emoji: '🔧',
          badge: '${_bgCyan}${_white} DEBUG $_reset',
          color: _cyan,
          textColor: _cyan,
        );
      case LogLevel.verbose:
        return _LevelInfo(
          emoji: '🔍',
          badge: '${_bgMagenta}${_white} VERBOSE $_reset',
          color: _magenta,
          textColor: _gray,
        );
      case LogLevel.none:
        return _LevelInfo(
          emoji: '⚪',
          badge: '${_white} NONE  $_reset',
          color: _white,
          textColor: _white,
        );
    }
  }

  String _applyColor(String colorCode, String text) {
    if (!enableColors) return text;
    return '$colorCode$text$_reset';
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

class _LevelInfo {
  final String emoji;
  final String badge;
  final String color;
  final String textColor;

  _LevelInfo({
    required this.emoji,
    required this.badge,
    required this.color,
    required this.textColor,
  });
}

class SmartLogger {
  // Color constants for debug logging
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';
  static const String _white = '\x1B[37m';
  static const String _gray = '\x1B[90m';

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
  }) : sinks = sinks ?? [ColorfulConsoleLogSink()];

  /// Creates a logger with basic console output (no colors/emojis)
  SmartLogger.basic({
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

  /// Creates a logger with colorful output but compact format
  SmartLogger.compact({
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
  }) : sinks = [ColorfulConsoleLogSink(compactMode: true)];

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

  // Convenience methods for HTTP-specific logging with emojis

  void httpRequest(
    String method,
    String url, {
    String? correlationId,
    Map<String, String>? headers,
    dynamic body,
  }) {
    final metadata = <String, dynamic>{
      'method': method,
      'url': url,
      if (headers != null) 'headers': _sanitizeHeaders(headers),
      if (body != null) 'body': _sanitizeBody(body),
    };

    info(
      '🚀 HTTP Request: $method $url',
      correlationId: correlationId,
      metadata: metadata,
    );

    if (level >= LogLevel.debug) {
      if (headers != null && headers.isNotEmpty) {
        final sanitizedHeaders = _sanitizeHeaders(headers);
        final headerLines = StringBuffer();
        headerLines.writeln(_applyDebugColor('📋 Request Headers:', _cyan + _bold));
        for (final entry in sanitizedHeaders.entries) {
          final key = _applyDebugColor('  ${entry.key}:', _blue);
          final value = entry.value == '[REDACTED]' 
              ? _applyDebugColor(entry.value, _red + _bold)
              : _applyDebugColor(entry.value, _green);
          headerLines.writeln('$key $value');
        }
        debug(
          headerLines.toString().trimRight(),
          correlationId: correlationId,
        );
      }
      
      if (body != null) {
        final sanitizedBody = _sanitizeBody(body);
        final bodyStr = _formatColorizedJsonForLogging(sanitizedBody);
        debug(
          '${_applyDebugColor('📤 Request Payload:', _cyan + _bold)}\n$bodyStr',
          correlationId: correlationId,
        );
      }
    }
  }

  void httpResponse(
    int statusCode,
    String method,
    String url,
    Duration duration, {
    String? correlationId,
    Map<String, String>? headers,
    dynamic body,
    bool fromCache = false,
  }) {
    final emoji = _getStatusEmoji(statusCode);
    final cacheEmoji = fromCache ? ' 💾' : '';
    final metadata = <String, dynamic>{
      'statusCode': statusCode,
      'method': method,
      'url': url,
      'duration': '${duration.inMilliseconds}ms',
      'fromCache': fromCache,
      if (headers != null) 'headers': _sanitizeHeaders(headers),
      if (body != null) 'body': _sanitizeBody(body),
    };
    
    final logLevel = statusCode >= 400 ? LogLevel.warning : LogLevel.info;
    
    log(
      logLevel,
      '$emoji HTTP Response: $statusCode $method $url (${duration.inMilliseconds}ms)$cacheEmoji',
      correlationId: correlationId,
      metadata: metadata,
    );

    if (level >= LogLevel.debug) {
      if (headers != null && headers.isNotEmpty) {
        final sanitizedHeaders = _sanitizeHeaders(headers);
        final headerLines = StringBuffer();
        headerLines.writeln(_applyDebugColor('📋 Response Headers:', _magenta + _bold));
        for (final entry in sanitizedHeaders.entries) {
          final key = _applyDebugColor('  ${entry.key}:', _blue);
          final value = entry.value == '[REDACTED]' 
              ? _applyDebugColor(entry.value, _red + _bold)
              : _applyDebugColor(entry.value, _green);
          headerLines.writeln('$key $value');
        }
        debug(
          headerLines.toString().trimRight(),
          correlationId: correlationId,
        );
      }
      
      if (body != null) {
        final sanitizedBody = _sanitizeBody(body);
        final bodyStr = _formatColorizedJsonForLogging(sanitizedBody);
        debug(
          '${_applyDebugColor('📥 Response Body:', _magenta + _bold)}\n$bodyStr',
          correlationId: correlationId,
        );
      }
    }
  }

  void httpError(
    String method,
    String url,
    Object error,
    Duration? duration, {
    String? correlationId,
    StackTrace? stackTrace,
  }) {
    final metadata = <String, dynamic>{
      'method': method,
      'url': url,
      if (duration != null) 'duration': '${duration.inMilliseconds}ms',
    };
    
    this.error(
      '💥 HTTP Error: $method $url - $error',
      correlationId: correlationId,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void cacheHit(
    String key, {
    String? correlationId,
    Duration? age,
  }) {
    final metadata = <String, dynamic>{
      'key': key,
      if (age != null) 'age': '${age.inMinutes}min',
    };
    
    debug(
      '🎯 Cache Hit: $key${age != null ? ' (${age.inMinutes}min old)' : ''}',
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  void cacheMiss(
    String key, {
    String? correlationId,
    String? reason,
  }) {
    final metadata = <String, dynamic>{
      'key': key,
      if (reason != null) 'reason': reason,
    };
    
    debug(
      '❌ Cache Miss: $key${reason != null ? ' ($reason)' : ''}',
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  void retry(
    int attempt,
    int maxAttempts,
    String operation, {
    String? correlationId,
    Duration? delay,
  }) {
    final metadata = <String, dynamic>{
      'attempt': attempt,
      'maxAttempts': maxAttempts,
      'operation': operation,
      if (delay != null) 'delay': '${delay.inMilliseconds}ms',
    };
    
    warning(
      '🔄 Retry $attempt/$maxAttempts: $operation${delay != null ? ' (waiting ${delay.inMilliseconds}ms)' : ''}',
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  void queueAdd(
    String operation, {
    String? correlationId,
    int? queueSize,
  }) {
    final metadata = <String, dynamic>{
      'operation': operation,
      if (queueSize != null) 'queueSize': queueSize,
    };
    
    info(
      '📥 Queued: $operation${queueSize != null ? ' (queue: $queueSize)' : ''}',
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  void queueProcess(
    String operation, {
    String? correlationId,
    bool success = true,
  }) {
    final emoji = success ? '✅' : '❌';
    final status = success ? 'Success' : 'Failed';
    
    final metadata = <String, dynamic>{
      'operation': operation,
      'success': success,
    };
    
    info(
      '$emoji Queue Processed: $operation ($status)',
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  String _getStatusEmoji(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return '✅';
    if (statusCode >= 300 && statusCode < 400) return '🔄';
    if (statusCode >= 400 && statusCode < 500) return '⚠️';
    if (statusCode >= 500) return '🚨';
    return '❓';
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

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (_isSensitiveKey(key)) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    
    return sanitized;
  }

  dynamic _sanitizeBody(dynamic body) {
    if (body == null) return null;
    
    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        return _sanitizeBodyData(decoded);
      } catch (e) {
        return body;
      }
    }
    
    return _sanitizeBodyData(body);
  }

  dynamic _sanitizeBodyData(dynamic data) {
    if (data is Map<String, dynamic>) {
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = entry.key.toLowerCase();
        if (_isSensitiveKey(key)) {
          sanitized[entry.key] = '[REDACTED]';
        } else if (entry.value is Map<String, dynamic>) {
          sanitized[entry.key] = _sanitizeBodyData(entry.value);
        } else if (entry.value is List) {
          sanitized[entry.key] = _sanitizeBodyData(entry.value);
        } else {
          sanitized[entry.key] = entry.value;
        }
      }
      return sanitized;
    } else if (data is List) {
      return data.map((item) => _sanitizeBodyData(item)).toList();
    } else if (data is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = entry.key.toString().toLowerCase();
        if (_isSensitiveKey(key)) {
          sanitized[entry.key.toString()] = '[REDACTED]';
        } else {
          sanitized[entry.key.toString()] = _sanitizeBodyData(entry.value);
        }
      }
      return sanitized;
    }
    
    return data;
  }

  String _formatJsonForLogging(dynamic data, {int indent = 0}) {
    const String indentStr = '  ';
    final String currentIndent = indentStr * indent;
    final String nextIndent = indentStr * (indent + 1);

    if (data == null) {
      return 'null';
    } else if (data is String) {
      // Check if it's already a JSON string and try to parse it
      if (data.startsWith('{') || data.startsWith('[')) {
        try {
          final decoded = jsonDecode(data);
          return _formatJsonForLogging(decoded, indent: indent);
        } catch (e) {
          return '"$data"';
        }
      }
      return '"$data"';
    } else if (data is Map) {
      if (data.isEmpty) return '{}';
      
      final buffer = StringBuffer();
      buffer.writeln('{');
      
      final entries = data.entries.toList();
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final isLast = i == entries.length - 1;
        
        buffer.write('$nextIndent"${entry.key}": ');
        final formattedValue = _formatJsonForLogging(entry.value, indent: indent + 1);
        
        if (formattedValue.contains('\n')) {
          buffer.write(formattedValue);
        } else {
          buffer.write(formattedValue);
        }
        
        if (!isLast) buffer.write(',');
        buffer.writeln();
      }
      
      buffer.write('$currentIndent}');
      return buffer.toString();
    } else if (data is List) {
      if (data.isEmpty) return '[]';
      
      final buffer = StringBuffer();
      buffer.writeln('[');
      
      for (int i = 0; i < data.length; i++) {
        final isLast = i == data.length - 1;
        buffer.write(nextIndent);
        
        final formattedValue = _formatJsonForLogging(data[i], indent: indent + 1);
        buffer.write(formattedValue);
        
        if (!isLast) buffer.write(',');
        buffer.writeln();
      }
      
      buffer.write('$currentIndent]');
      return buffer.toString();
    } else if (data is num || data is bool) {
      return data.toString();
    } else {
      return '"${data.toString()}"';
    }
  }

  String _formatColorizedJsonForLogging(dynamic data, {int indent = 0}) {
    const String indentStr = '  ';
    final String currentIndent = indentStr * indent;
    final String nextIndent = indentStr * (indent + 1);

    if (data == null) {
      return _applyDebugColor('null', _gray);
    } else if (data is String) {
      // Check if it's already a JSON string and try to parse it
      if (data.startsWith('{') || data.startsWith('[')) {
        try {
          final decoded = jsonDecode(data);
          return _formatColorizedJsonForLogging(decoded, indent: indent);
        } catch (e) {
          if (data == '[REDACTED]') {
            return _applyDebugColor('"$data"', _red + _bold);
          }
          return _applyDebugColor('"$data"', _green);
        }
      }
      if (data == '[REDACTED]') {
        return _applyDebugColor('"$data"', _red + _bold);
      }
      return _applyDebugColor('"$data"', _green);
    } else if (data is Map) {
      if (data.isEmpty) return _applyDebugColor('{}', _white);
      
      final buffer = StringBuffer();
      buffer.writeln(_applyDebugColor('{', _white));
      
      final entries = data.entries.toList();
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final isLast = i == entries.length - 1;
        
        final keyColor = _applyDebugColor('$nextIndent"${entry.key}":', _blue);
        buffer.write('$keyColor ');
        
        final formattedValue = _formatColorizedJsonForLogging(entry.value, indent: indent + 1);
        
        if (formattedValue.contains('\n')) {
          buffer.write(formattedValue);
        } else {
          buffer.write(formattedValue);
        }
        
        if (!isLast) buffer.write(_applyDebugColor(',', _white));
        buffer.writeln();
      }
      
      buffer.write('$currentIndent${_applyDebugColor('}', _white)}');
      return buffer.toString();
    } else if (data is List) {
      if (data.isEmpty) return _applyDebugColor('[]', _white);
      
      final buffer = StringBuffer();
      buffer.writeln(_applyDebugColor('[', _white));
      
      for (int i = 0; i < data.length; i++) {
        final isLast = i == data.length - 1;
        buffer.write(nextIndent);
        
        final formattedValue = _formatColorizedJsonForLogging(data[i], indent: indent + 1);
        buffer.write(formattedValue);
        
        if (!isLast) buffer.write(_applyDebugColor(',', _white));
        buffer.writeln();
      }
      
      buffer.write('$currentIndent${_applyDebugColor(']', _white)}');
      return buffer.toString();
    } else if (data is num) {
      return _applyDebugColor(data.toString(), _yellow);
    } else if (data is bool) {
      return _applyDebugColor(data.toString(), _magenta);
    } else {
      return _applyDebugColor('"${data.toString()}"', _green);
    }
  }

  String _applyDebugColor(String text, String colorCode) {
    // Check if we're using a colorful sink
    final hasColorfulSink = sinks.any((sink) => sink is ColorfulConsoleLogSink);
    if (hasColorfulSink) {
      return '$colorCode$text$_reset';
    }
    return text;
  }

  Future<void> flush() async {
    await Future.wait(sinks.map((sink) => sink.flush()));
  }

  Future<void> close() async {
    await Future.wait(sinks.map((sink) => sink.close()));
  }
}