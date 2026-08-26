import 'agency_notice.dart';

class Agency {
  final int id;
  final String name;
  final String? region;
  final String? phone;
  final double safetyScore;
  final int violationCount;
  final int totalJourneys;
  final Map<String, int> vehicleBreakdown;
  final AgencyClassification classification;
  final String summaryText;

  Agency({
    required this.id,
    required this.name,
    this.region,
    this.phone,
    this.safetyScore = 100,
    this.violationCount = 0,
    this.totalJourneys = 0,
    this.vehicleBreakdown = const {},
    this.classification = AgencyClassification.unclassified,
    this.summaryText = '',
  });

  bool get isTrusted => classification == AgencyClassification.trusted;
  bool get isWithinLimit =>
      classification == AgencyClassification.withinLimit || isTrusted;
  bool get shouldAvoid => classification == AgencyClassification.avoid;

  String get reportSummary {
    const order = ['car', 'bus', 'lorry', 'motorbike'];
    final vehicles = order
        .map((type) => '${_vehicleLabel(type)}: ${vehicleBreakdown[type] ?? 0}')
        .join(', ');
    return '$name agency safety report\n'
        'Status: ${isTrusted ? 'Trusted' : 'Under review'}\n'
        'Safety score: ${safetyScore.toStringAsFixed(0)}%\n'
        'Journeys: $totalJourneys\n'
        'Violations: $violationCount\n'
        'Vehicles: $vehicles';
  }

  factory Agency.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final score =
        json['safetyScore'] ?? json['safety_score'] ?? json['score'] ?? 0;
    final violations = json['violationCount'] ??
        json['violation_count'] ??
        json['violations'] ??
        0;
    final journeys = json['totalJourneys'] ?? json['total_journeys'] ?? 0;
    final breakdown = _vehicleBreakdown(
      json['vehicleBreakdown'] ??
          json['vehicle_breakdown'] ??
          json['vehiclesByType'] ??
          json['vehicles_by_type'],
    );
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
      vehicleBreakdown: breakdown,
      classification: parseAgencyClassification(
        json['classification'] ?? json['safetyClassification'],
      ),
      summaryText: (json['summaryText'] ?? json['aiSummary'] ?? '').toString(),
    );
  }

  static Map<String, int> _vehicleBreakdown(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, int>{};
    for (final entry in value.entries) {
      final key = _normalizeVehicleType(entry.key.toString());
      final count = entry.value;
      result[key] = count is num ? count.toInt() : int.tryParse('$count') ?? 0;
    }
    return result;
  }

  static String _normalizeVehicleType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'bike' || normalized == 'motorcycle') {
      return 'motorbike';
    }
    return normalized;
  }

  static String _vehicleLabel(String type) {
    return type == 'motorbike'
        ? 'Motorbikes'
        : '${type[0].toUpperCase()}${type.substring(1)}s';
  }
}
