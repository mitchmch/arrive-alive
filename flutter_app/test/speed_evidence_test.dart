import 'package:arrive_alive/models/speed_sample.dart';
import 'package:arrive_alive/models/violation_episode.dart';
import 'package:flutter_test/flutter_test.dart';

SpeedSample sample(int second, double speed, {double limit = 60}) {
  return SpeedSample(
    localId: 'sample-$second',
    journeyLocalId: 'journey-1',
    recordedAt: DateTime.utc(2026, 8, 26, 12, 0, second),
    speed: speed,
    speedLimit: limit,
    latitude: 4,
    longitude: 9,
    accuracy: 4,
    isMoving: true,
  );
}

void main() {
  test('one sustained speeding period is one violation episode', () {
    final tracker = SpeedEvidenceTracker(requiredReadings: 3);

    tracker.add(sample(1, 63));
    tracker.add(sample(2, 64));
    tracker.add(sample(3, 67));
    tracker.add(sample(4, 70));
    final episode = tracker.add(sample(5, 60));

    expect(tracker.episodeCount, 1);
    expect(episode, isNotNull);
    expect(episode!.startedAt, sample(1, 63).recordedAt);
    expect(episode.endedAt, sample(5, 60).recordedAt);
    expect(episode.peakSpeed, 70);
    expect(episode.speedLimit, 60);
    expect(episode.sampleCount, 4);
  });

  test('short GPS spike does not become an episode', () {
    final tracker = SpeedEvidenceTracker(requiredReadings: 3);
    tracker.add(sample(1, 80));
    tracker.add(sample(2, 55));

    expect(tracker.episodeCount, 0);
    expect(tracker.completedEpisodes, isEmpty);
  });

  test('finishing a journey closes an active episode exactly once', () {
    final tracker = SpeedEvidenceTracker(requiredReadings: 2);
    tracker.add(sample(1, 65));
    tracker.add(sample(2, 68));

    expect(tracker.episodeCount, 1);
    expect(tracker.finish(DateTime.utc(2026, 8, 26, 12, 0, 3)), isNotNull);
    expect(tracker.finish(DateTime.utc(2026, 8, 26, 12, 0, 4)), isNull);
    expect(tracker.episodeCount, 1);
  });
}
