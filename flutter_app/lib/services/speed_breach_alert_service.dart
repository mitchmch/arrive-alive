import 'dart:async';

import 'package:flutter/services.dart';

typedef BreachAlertPulse = FutureOr<void> Function();

/// Owns the short repeating audible/haptic warning used during a live speed
/// breach. Updating to inactive cancels future pulses immediately.
class SpeedBreachAlertService {
  SpeedBreachAlertService({
    BreachAlertPulse? pulse,
    this.interval = const Duration(milliseconds: 1500),
  }) : _pulse = pulse ?? _systemPulse;

  final BreachAlertPulse _pulse;
  final Duration interval;
  Timer? _timer;

  bool get isActive => _timer?.isActive ?? false;

  void update({required bool isRecording, required bool isViolating}) {
    final shouldAlert = isRecording && isViolating;
    if (!shouldAlert) {
      stop();
      return;
    }
    if (isActive) return;
    _emitPulse();
    _timer = Timer.periodic(interval, (_) => _emitPulse());
  }

  void _emitPulse() {
    unawaited(
      Future<void>.sync(_pulse).catchError((_) {
        // Safety UI state must not depend on device sound/haptic availability.
      }),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  static Future<void> _systemPulse() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
  }
}
