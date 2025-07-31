import 'dart:async';
import 'dart:io';
import 'package:meta/meta.dart';

enum ConnectivityStatus {
  connected,
  disconnected,
  unknown,
}

enum ConnectionQuality {
  excellent,
  good,
  poor,
  none,
}

@immutable
class ConnectivityInfo {
  final ConnectivityStatus status;
  final ConnectionQuality quality;
  final DateTime timestamp;
  final String? endpoint;
  final Duration? latency;

  const ConnectivityInfo({
    required this.status,
    required this.quality,
    required this.timestamp,
    this.endpoint,
    this.latency,
  });

  bool get isConnected => status == ConnectivityStatus.connected;
  bool get isDisconnected => status == ConnectivityStatus.disconnected;

  @override
  String toString() {
    return 'ConnectivityInfo(status: $status, quality: $quality, latency: $latency)';
  }
}

class ConnectivityManager {
  final List<String> checkEndpoints;
  final Duration checkInterval;
  final Duration timeout;
  final bool manualOverride;
  
  final StreamController<ConnectivityInfo> _statusController;
  Timer? _checkTimer;
  ConnectivityInfo _lastInfo;
  bool _manualOfflineMode = false;

  ConnectivityManager({
    this.checkEndpoints = const [
      'https://www.google.com',
      'https://www.cloudflare.com',
      '1.1.1.1',
    ],
    this.checkInterval = const Duration(seconds: 10),
    this.timeout = const Duration(seconds: 5),
    this.manualOverride = true,
  }) : _statusController = StreamController<ConnectivityInfo>.broadcast(),
       _lastInfo = ConnectivityInfo(
         status: ConnectivityStatus.unknown,
         quality: ConnectionQuality.none,
         timestamp: DateTime.now(),
       ) {
    _startPeriodicCheck();
  }

  Stream<ConnectivityInfo> get statusStream => _statusController.stream;
  
  ConnectivityInfo get currentStatus => _lastInfo;
  
  bool get isConnected => !_manualOfflineMode && _lastInfo.isConnected;
  
  bool get isOffline => _manualOfflineMode || _lastInfo.isDisconnected;

  Future<ConnectivityInfo> checkConnectivity() async {
    if (_manualOfflineMode) {
      return ConnectivityInfo(
        status: ConnectivityStatus.disconnected,
        quality: ConnectionQuality.none,
        timestamp: DateTime.now(),
      );
    }

    final results = await Future.wait(
      checkEndpoints.map(_checkEndpoint),
      eagerError: false,
    );

    final successfulChecks = results.where((r) => r.isConnected).toList();
    
    if (successfulChecks.isEmpty) {
      return ConnectivityInfo(
        status: ConnectivityStatus.disconnected,
        quality: ConnectionQuality.none,
        timestamp: DateTime.now(),
      );
    }

    final bestResult = successfulChecks.reduce((a, b) => 
        (a.latency?.inMilliseconds ?? double.infinity) < 
        (b.latency?.inMilliseconds ?? double.infinity) ? a : b);

    final quality = _determineQuality(bestResult.latency);

    final info = ConnectivityInfo(
      status: ConnectivityStatus.connected,
      quality: quality,
      timestamp: DateTime.now(),
      endpoint: bestResult.endpoint,
      latency: bestResult.latency,
    );

    _updateStatus(info);
    return info;
  }

  Future<ConnectivityInfo> _checkEndpoint(String endpoint) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      if (endpoint.contains('://')) {
        final client = HttpClient();
        client.connectionTimeout = timeout;
        
        final uri = Uri.parse(endpoint);
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(timeout);
        
        stopwatch.stop();
        client.close();

        return ConnectivityInfo(
          status: response.statusCode < 400 
              ? ConnectivityStatus.connected 
              : ConnectivityStatus.disconnected,
          quality: _determineQuality(stopwatch.elapsed),
          timestamp: DateTime.now(),
          endpoint: endpoint,
          latency: stopwatch.elapsed,
        );
      } else {
        final result = await Process.run(
          'ping',
          ['-c', '1', '-W', timeout.inMilliseconds.toString(), endpoint],
        ).timeout(timeout);

        stopwatch.stop();

        return ConnectivityInfo(
          status: result.exitCode == 0 
              ? ConnectivityStatus.connected 
              : ConnectivityStatus.disconnected,
          quality: _determineQuality(stopwatch.elapsed),
          timestamp: DateTime.now(),
          endpoint: endpoint,
          latency: stopwatch.elapsed,
        );
      }
    } catch (e) {
      stopwatch.stop();
      
      return ConnectivityInfo(
        status: ConnectivityStatus.disconnected,
        quality: ConnectionQuality.none,
        timestamp: DateTime.now(),
        endpoint: endpoint,
      );
    }
  }

  ConnectionQuality _determineQuality(Duration? latency) {
    if (latency == null) return ConnectionQuality.none;
    
    final ms = latency.inMilliseconds;
    if (ms < 100) return ConnectionQuality.excellent;
    if (ms < 300) return ConnectionQuality.good;
    if (ms < 1000) return ConnectionQuality.poor;
    return ConnectionQuality.none;
  }

  void _startPeriodicCheck() {
    _checkTimer = Timer.periodic(checkInterval, (_) async {
      await checkConnectivity();
    });
    
    checkConnectivity();
  }

  void _updateStatus(ConnectivityInfo info) {
    if (_lastInfo.status != info.status || 
        _lastInfo.quality != info.quality) {
      _lastInfo = info;
      if (!_statusController.isClosed) {
        _statusController.add(info);
      }
    }
  }

  void setManualOfflineMode(bool offline) {
    if (!manualOverride) return;
    
    _manualOfflineMode = offline;
    
    final info = ConnectivityInfo(
      status: offline 
          ? ConnectivityStatus.disconnected 
          : ConnectivityStatus.unknown,
      quality: offline 
          ? ConnectionQuality.none 
          : ConnectionQuality.good,
      timestamp: DateTime.now(),
    );
    
    _updateStatus(info);
    
    if (!offline) {
      checkConnectivity();
    }
  }

  void dispose() {
    _checkTimer?.cancel();
    _statusController.close();
  }
}