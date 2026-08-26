class Violation {
  final int id;
  final int journeyId;
  final String vehicleReg;
  final String mode;
  final int? agencyId;
  final double speed;
  final double speedLimit;
  final double lat;
  final double lng;
  final String timestamp;
  final int reportCount;
  final int validated;
  final int published;
  final String? episodeStartedAt;
  final String? episodeEndedAt;
  final int sampleCount;

  Violation({
    required this.id,
    required this.journeyId,
    required this.vehicleReg,
    required this.mode,
    this.agencyId,
    required this.speed,
    required this.speedLimit,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.reportCount = 1,
    this.validated = 0,
    this.published = 0,
    this.episodeStartedAt,
    this.episodeEndedAt,
    int? sampleCount,
  }) : sampleCount = sampleCount ?? reportCount;

  factory Violation.fromJson(Map<String, dynamic> json) => Violation(
        id: json['id'] ?? 0,
        journeyId: json['journeyId'] ?? 0,
        vehicleReg: json['vehicleReg'] ?? '',
        mode: json['mode'] ?? 'car',
        agencyId: json['agencyId'],
        speed: (json['speed'] ?? 0).toDouble(),
        speedLimit: (json['speedLimit'] ?? 0).toDouble(),
        lat: (json['lat'] ?? 0).toDouble(),
        lng: (json['lng'] ?? 0).toDouble(),
        timestamp: json['timestamp'] ?? '',
        reportCount: json['reportCount'] ?? 1,
        validated: json['validated'] ?? 0,
        published: json['published'] ?? 0,
        episodeStartedAt: json['episodeStartedAt']?.toString(),
        episodeEndedAt: json['episodeEndedAt']?.toString(),
        sampleCount: (json['sampleCount'] ?? json['reportCount'] ?? 1) as int,
      );
}
