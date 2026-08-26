class Agency {
  final int id;
  final String name;
  final String? region;
  final String? phone;
  final double safetyScore;
  final int violationCount;
  final int totalJourneys;

  Agency({
    required this.id,
    required this.name,
    this.region,
    this.phone,
    this.safetyScore = 100,
    this.violationCount = 0,
    this.totalJourneys = 0,
  });

  factory Agency.fromJson(Map<String, dynamic> json) => Agency(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        region: json['region'],
        phone: json['phone'],
        safetyScore: (json['safetyScore'] ?? 100).toDouble(),
        violationCount: json['violationCount'] ?? 0,
        totalJourneys: json['totalJourneys'] ?? 0,
      );
}
