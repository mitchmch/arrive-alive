import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity and provides stream-based online/offline detection.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  bool _initialized = false;
  final _controller = StreamController<bool>.broadcast();

  /// Stream of online/offline state changes
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current online state
  bool get isOnline => _isOnline;

  /// Initialize and start listening to connectivity changes (idempotent)
  void init() {
    if (_initialized) return;
    _initialized = true;

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _hasConnection(result);
      if (wasOnline != _isOnline) {
        _controller.add(_isOnline);
      }
    });

    // Check initial state
    _connectivity.checkConnectivity().then((result) {
      _isOnline = _hasConnection(result);
      _controller.add(_isOnline);
    });
  }

  /// Check connectivity right now
  Future<bool> checkOnline() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    return _isOnline;
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  void dispose() {
    _subscription?.cancel();
    _controller.close();
    _initialized = false;
  }
}
