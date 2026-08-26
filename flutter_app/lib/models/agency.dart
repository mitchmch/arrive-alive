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

  factory Agency.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final score =
        json['safetyScore'] ?? json['safety_score'] ?? json['score'] ?? 0;
    final violations = json['violationCount'] ??
        json['violation_count'] ??
        json['violations'] ??
        0;
    final journeys = json['totalJourneys'] ?? json['total_journeys'] ?? 0;
    return Agency(
      id: idValue is num ? idValue.toInt() : int.tryParse('$idValue') ?? 0,
      name: json['name'] ?? '',
      region: json['region'],
      phone: json['phone'],
      safetyScore:
          score is num ? score.toDouble() : double.tryParse('$score') ?? 0,
      violationCount: violations is num
          ? violations.toInt()
          : int.tryParse('$violations') ?? 0,
      totalJourneys:
          journeys is num ? journeys.toInt() : int.tryParse('$journeys') ?? 0,
    );
  }
}
