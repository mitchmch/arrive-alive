class JourneyEvidenceSummary {
  final String journeyLocalId;
  final int violationCount;
  final int sampleCount;
  final double maxSpeed;
  final double speedLimit;
  final double distanceMeters;
  final Duration duration;
  final int score;
  final bool queuedForSync;

  const JourneyEvidenceSummary({
    required this.journeyLocalId,
    required this.violationCount,
    required this.sampleCount,
    required this.maxSpeed,
    required this.speedLimit,
    required this.distanceMeters,
    required this.duration,
    required this.score,
    required this.queuedForSync,
  });

  bool get stayedWithinLimit => violationCount == 0;
}
