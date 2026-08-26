class Journey {
  final int id;
  final String? localId;
  final int? userId;
  final String mode;
  final String vehicleDetails;
  final String? assets;
  final String? defects;
  final String? driverName;
  final int passengerCount;
  final int? agencyId;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final String startTime;
  final String? endTime;
  final String status;
  final double maxSpeed;
  final double avgSpeed;
  final int violationCount;
  final double distance;
  final int score;
  final String? updatedAt;
  final int version;
  final bool isSynced;

  Journey({
    required this.id,
    this.localId,
    this.userId,
    required this.mode,
    required this.vehicleDetails,
    this.assets,
    this.defects,
    this.driverName,
    this.passengerCount = 1,
    this.agencyId,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    required this.startTime,
    this.endTime,
    this.status = 'active',
    this.maxSpeed = 0,
    this.avgSpeed = 0,
    this.violationCount = 0,
    this.distance = 0,
    this.score = 100,
    this.updatedAt,
    this.version = 1,
    this.isSynced = true,
  });

  factory Journey.fromJson(Map<String, dynamic> json) => Journey(
        id: json['id'] ?? 0,
        localId: json['localId']?.toString(),
        userId: json['userId'],
        mode: json['mode'] ?? 'car',
        vehicleDetails: json['vehicleDetails'] ?? '{}',
        assets: json['assets'],
        defects: json['defects'],
        driverName: json['driverName'],
        passengerCount: json['passengerCount'] ?? 1,
        agencyId: json['agencyId'],
        startLat: json['startLat']?.toDouble(),
        startLng: json['startLng']?.toDouble(),
        endLat: json['endLat']?.toDouble(),
        endLng: json['endLng']?.toDouble(),
        startTime: json['startTime'] ?? DateTime.now().toIso8601String(),
        endTime: json['endTime'],
        status: json['status'] ?? 'active',
        maxSpeed: (json['maxSpeed'] ?? 0).toDouble(),
        avgSpeed: (json['avgSpeed'] ?? 0).toDouble(),
        violationCount: json['violationCount'] ?? 0,
        distance: (json['distance'] ?? 0).toDouble(),
        score: json['score'] ?? 100,
        updatedAt: json['updatedAt']?.toString(),
        version: json['version'] ?? 1,
        isSynced: (json['synced'] ?? 1) == 1,
      );
}
