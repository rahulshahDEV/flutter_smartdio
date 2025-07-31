import 'dart:math';
import 'package:meta/meta.dart';
import '../core/smart_dio_response.dart';

/// Defines retry behavior for failed HTTP requests.
/// 
/// This sealed class provides various retry strategies including fixed delay,
/// exponential backoff, and custom retry policies. Each policy determines
/// when and how requests should be retried after failures.
@immutable
sealed class RetryPolicy {
  const RetryPolicy();

  /// Creates a policy that disables all retries.
  const factory RetryPolicy.none() = NoRetryPolicy;
  
  /// Creates a fixed delay retry policy.
  /// 
  /// [maxAttempts] maximum number of retry attempts
  /// [delay] fixed delay between retry attempts
  const factory RetryPolicy.fixed({
    required int maxAttempts,
    required Duration delay,
    Set<int> retryStatusCodes,
    Set<SmartDioErrorType> retryErrorTypes,
  }) = FixedDelayRetryPolicy;

  /// Creates an exponential backoff retry policy.
  /// 
  /// [maxAttempts] maximum number of retry attempts
  /// [initialDelay] initial delay before first retry
  /// [multiplier] factor to multiply delay by for each retry
  const factory RetryPolicy.exponentialBackoff({
    required int maxAttempts,
    required Duration initialDelay,
    double multiplier,
    Duration? maxDelay,
    bool jitter,
    Set<int> retryStatusCodes,
    Set<SmartDioErrorType> retryErrorTypes,
  }) = ExponentialBackoffRetryPolicy;

  const factory RetryPolicy.custom({
    required int maxAttempts,
    required Duration Function(int attempt) delayCalculator,
    required bool Function(SmartDioError error) shouldRetry,
  }) = CustomRetryPolicy;

  bool shouldRetry(SmartDioError error, int attempt);
  Duration getDelay(int attempt);
  int get maxAttempts;
}

@immutable
final class NoRetryPolicy extends RetryPolicy {
  const NoRetryPolicy();

  @override
  bool shouldRetry(SmartDioError error, int attempt) => false;

  @override
  Duration getDelay(int attempt) => Duration.zero;

  @override
  int get maxAttempts => 0;

  @override
  String toString() => 'NoRetryPolicy()';
}

@immutable
final class FixedDelayRetryPolicy extends RetryPolicy {
  @override
  final int maxAttempts;
  final Duration delay;
  final Set<int> retryStatusCodes;
  final Set<SmartDioErrorType> retryErrorTypes;

  const FixedDelayRetryPolicy({
    required this.maxAttempts,
    required this.delay,
    this.retryStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.retryErrorTypes = const {
      SmartDioErrorType.network,
      SmartDioErrorType.timeout,
    },
  });

  @override
  bool shouldRetry(SmartDioError error, int attempt) {
    if (attempt >= maxAttempts) return false;

    if (error.statusCode != null) {
      return retryStatusCodes.contains(error.statusCode);
    }

    return retryErrorTypes.contains(error.type);
  }

  @override
  Duration getDelay(int attempt) => delay;

  @override
  String toString() => 'FixedDelayRetryPolicy(maxAttempts: $maxAttempts, delay: $delay)';
}

@immutable
final class ExponentialBackoffRetryPolicy extends RetryPolicy {
  @override
  final int maxAttempts;
  final Duration initialDelay;
  final double multiplier;
  final Duration? maxDelay;
  final bool jitter;
  final Set<int> retryStatusCodes;
  final Set<SmartDioErrorType> retryErrorTypes;

  const ExponentialBackoffRetryPolicy({
    required this.maxAttempts,
    required this.initialDelay,
    this.multiplier = 2.0,
    this.maxDelay,
    this.jitter = true,
    this.retryStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.retryErrorTypes = const {
      SmartDioErrorType.network,
      SmartDioErrorType.timeout,
    },
  });

  @override
  bool shouldRetry(SmartDioError error, int attempt) {
    if (attempt >= maxAttempts) return false;

    if (error.statusCode != null) {
      return retryStatusCodes.contains(error.statusCode);
    }

    return retryErrorTypes.contains(error.type);
  }

  @override
  Duration getDelay(int attempt) {
    final baseDelay = initialDelay.inMilliseconds * pow(multiplier, attempt);
    var delayMs = baseDelay.toInt();

    if (maxDelay != null && delayMs > maxDelay!.inMilliseconds) {
      delayMs = maxDelay!.inMilliseconds;
    }

    if (jitter) {
      final random = Random();
      delayMs = (delayMs * (0.5 + random.nextDouble() * 0.5)).toInt();
    }

    return Duration(milliseconds: delayMs);
  }

  @override
  String toString() => 'ExponentialBackoffRetryPolicy(maxAttempts: $maxAttempts, initialDelay: $initialDelay, multiplier: $multiplier)';
}

@immutable
final class CustomRetryPolicy extends RetryPolicy {
  @override
  final int maxAttempts;
  final Duration Function(int attempt) delayCalculator;
  final bool Function(SmartDioError error) shouldRetryPredicate;

  const CustomRetryPolicy({
    required this.maxAttempts,
    required this.delayCalculator,
    required bool Function(SmartDioError error) shouldRetry,
  }) : shouldRetryPredicate = shouldRetry;

  @override
  bool shouldRetry(SmartDioError error, int attempt) {
    if (attempt >= maxAttempts) return false;
    return shouldRetryPredicate(error);
  }

  @override
  Duration getDelay(int attempt) => delayCalculator(attempt);

  @override
  String toString() => 'CustomRetryPolicy(maxAttempts: $maxAttempts)';
}