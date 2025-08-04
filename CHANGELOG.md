# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2024-01-15

### Added
- **Persistent Queue Storage**: Hive-based queue storage that survives app restarts
  - New `QueueStorageType` enum with options: `persistent`, `memory`, `none`
  - Default to persistent storage for better offline experience
  - Configurable queue limits and automatic cleanup
  - Visual test examples in Flutter app
- **Enhanced Response Logging**: Intelligent object serialization in debug logs
  - Display actual response data instead of "Instance of Object"
  - Smart detection and serialization of custom objects with `toJson()` methods
  - Dual logging: raw JSON response + transformed object data
  - Fallback extraction for non-serializable objects
  - Added `rawData` field to `SmartDioSuccess` for comprehensive logging

### Changed
- Request queue now defaults to persistent storage instead of memory-only
- Logger shows both raw server response and transformed object data
- Enhanced debug console output with better object representation

### Improved
- Better offline request handling with persistent queue storage
- Debugging experience with detailed response data logging
- Queue storage examples and visual testing in example app

## [1.0.0] - 2024-01-01

### Added
- Initial release of Flutter SmartDio
- Transport-agnostic HTTP wrapper architecture
- HttpClientAdapter interface for client abstraction
- SmartDioClient with comprehensive request/response handling
- Unified response system with SmartDioSuccess/SmartDioError
- Never-crash philosophy with structured error handling
- Intelligent retry policies:
  - Exponential backoff with jitter
  - Fixed delay retry
  - Custom retry logic
- Offline-first caching system:
  - Network-first, cache-first strategies
  - TTL-based cache expiration
  - Memory and pluggable storage backends
- Request queuing for offline scenarios:
  - Persistent queue storage
  - Automatic sync when connectivity returns
  - Queue management and monitoring
- Native logging system:
  - Sensitive data redaction
  - Configurable log levels
  - Multiple output sinks
- Connectivity management:
  - Real-time network status monitoring
  - Connection quality detection
  - Manual offline mode for testing
- Performance metrics collection:
  - Request timing and success rates
  - Cache hit rates and storage usage
  - Queue processing statistics
- Request deduplication:
  - Signature-based duplicate detection
  - Configurable time windows
  - In-flight request protection
- Interceptor architecture:
  - Pre-request modification
  - Post-response transformation
  - Error handling and recovery
- Built-in implementations:
  - HttpClient adapter for dart:io
  - Memory-based cache store
  - Memory-based queue storage
- Type-safe response transformation
- Comprehensive configuration system
- Request tagging and bulk operations
- Correlation ID tracking
- Rich metadata and debugging information

### Security
- Automatic sensitive header redaction
- Configurable sensitive field detection
- Secure credential handling in logs
- No sensitive data exposure in error messages

### Performance
- Minimal memory footprint
- Efficient request deduplication
- Smart cache cleanup and eviction
- Connection pooling through underlying clients
- Lazy initialization of optional components

### Developer Experience
- Comprehensive documentation and examples
- Type-safe APIs with full generic support
- Rich error messages with context
- Easy testing with mock adapters
- Detailed logging for debugging
- Real-time event streaming for monitoring

### Documentation
- Complete API documentation
- Usage examples for all features
- Architecture overview and design principles
- Migration guides and best practices
- Performance tuning recommendations