class SpeedSample {
  final String localId;
  final String journeyLocalId;
  final int? journeyId;
  final DateTime recordedAt;
  final double speed;
  final double speedLimit;
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isMoving;

  const SpeedSample({
    required this.localId,
    required this.journeyLocalId,
    this.journeyId,
    required this.recordedAt,
    required this.speed,
    required this.speedLimit,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMoving,
  });

  bool get isOverLimit => isMoving && speed > speedLimit;

  Map<String, dynamic> toApiJson() => {
        'localId': localId,
        'journeyId': journeyId,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'speed': speed,
        'speedLimit': speedLimit,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'isMoving': isMoving,
      };
}
