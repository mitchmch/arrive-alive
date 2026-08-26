import 'speed_sample.dart';

class ViolationEpisode {
  final DateTime startedAt;
  final DateTime endedAt;
  final double peakSpeed;
  final double speedLimit;
  final double latitude;
  final double longitude;
  final int sampleCount;

  const ViolationEpisode({
    required this.startedAt,
    required this.endedAt,
    required this.peakSpeed,
    required this.speedLimit,
    required this.latitude,
    required this.longitude,
    required this.sampleCount,
  });

  double get amountOverLimit => peakSpeed - speedLimit;
}

/// Deterministic evidence rule for a speeding episode.
///
/// The client records facts only. An episode starts after [requiredReadings]
/// consecutive moving samples above the configured limit and ends on the first
/// sample at or below that limit. No AI output participates in this rule.
class SpeedEvidenceTracker {
  final int requiredReadings;
  final double toleranceKph;
  final List<SpeedSample> _pending = [];
  final List<ViolationEpisode> _completed = [];
  bool _active = false;
  DateTime? _startedAt;
  double _peakSpeed = 0;
  double _speedLimit = 0;
  double _latitude = 0;
  double _longitude = 0;
  int _sampleCount = 0;

  SpeedEvidenceTracker({
    this.requiredReadings = 3,
    this.toleranceKph = 2,
  }) : assert(requiredReadings > 0);

  bool get hasActiveEpisode => _active;
  int get episodeCount => _completed.length + (_active ? 1 : 0);
  List<ViolationEpisode> get completedEpisodes => List.unmodifiable(_completed);

  ViolationEpisode? add(SpeedSample sample) {
    if (sample.isMoving && sample.speed > sample.speedLimit + toleranceKph) {
      if (!_active) {
        _pending.add(sample);
        if (_pending.length < requiredReadings) return null;
        _active = true;
        _startedAt = _pending.first.recordedAt;
        _sampleCount = _pending.length;
        _setPeak(_pending.first);
        for (final pending in _pending.skip(1)) {
          _setPeak(pending);
        }
        _pending.clear();
      } else {
        _sampleCount++;
        _setPeak(sample);
      }
      return null;
    }

    _pending.clear();
    return _finish(sample.recordedAt);
  }

  ViolationEpisode? finish(DateTime endedAt) {
    _pending.clear();
    return _finish(endedAt);
  }

  void reset() {
    _pending.clear();
    _completed.clear();
    _active = false;
    _startedAt = null;
    _peakSpeed = 0;
    _speedLimit = 0;
    _sampleCount = 0;
  }

  void _setPeak(SpeedSample sample) {
    if (sample.speed >= _peakSpeed) {
      _peakSpeed = sample.speed;
      _speedLimit = sample.speedLimit;
      _latitude = sample.latitude;
      _longitude = sample.longitude;
    }
  }

  ViolationEpisode? _finish(DateTime endedAt) {
    if (!_active || _startedAt == null) return null;
    final episode = ViolationEpisode(
      startedAt: _startedAt!,
      endedAt: endedAt,
      peakSpeed: _peakSpeed,
      speedLimit: _speedLimit,
      latitude: _latitude,
      longitude: _longitude,
      sampleCount: _sampleCount,
    );
    _completed.add(episode);
    _active = false;
    _startedAt = null;
    _peakSpeed = 0;
    _speedLimit = 0;
    _sampleCount = 0;
    return episode;
  }
}
