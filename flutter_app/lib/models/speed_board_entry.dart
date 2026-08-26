class SpeedBoardEntry {
  final String id;
  final String resultType;
  final String agencyName;
  final String? region;
  final String mode;
  final String vehicleReg;
  final DateTime? publishedAt;
  final Map<String, dynamic> evidence;
  final String summary;

  const SpeedBoardEntry({
    required this.id,
    required this.resultType,
    required this.agencyName,
    this.region,
    required this.mode,
    required this.vehicleReg,
    this.publishedAt,
    required this.evidence,
    required this.summary,
  });

  bool get isViolation => resultType == 'violator';
  bool get isWithinLimit => resultType == 'within_limit';
  int get episodeCount => _integer(evidence['episodeCount']);
  int get sampleCount => _integer(evidence['sampleCount']);
  double get peakSpeed => _number(evidence['peakSpeedKph']);
  double get speedLimit => _number(evidence['speedLimitKph']);

  factory SpeedBoardEntry.fromJson(Map<String, dynamic> json) {
    final agency = _map(json['agencies']);
    final journey = _map(json['journeys']);
    final vehicle = _map(journey['vehicleDetails']);
    return SpeedBoardEntry(
      id: json['id'].toString(),
      resultType: json['resultType']?.toString() ?? '',
      agencyName: agency['name']?.toString() ?? 'Independent journey',
      region: agency['region']?.toString(),
      mode: journey['mode']?.toString() ?? 'vehicle',
      vehicleReg: (vehicle['reg'] ?? vehicle['registration'] ?? '').toString(),
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
      evidence: _map(json['evidence']),
      summary: json['summary']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class AgencySafetyRollup {
  final String id;
  final String agencyName;
  final String? region;
  final String status;
  final double confidence;
  final int journeyCount;
  final int violationJourneyCount;
  final String deterministicSummary;
  final String? aiSummary;

  const AgencySafetyRollup({
    required this.id,
    required this.agencyName,
    this.region,
    required this.status,
    required this.confidence,
    required this.journeyCount,
    required this.violationJourneyCount,
    required this.deterministicSummary,
    this.aiSummary,
  });

  bool get isTrusted => status == 'trusted';
  bool get shouldAvoid => status == 'avoid';
  String get displaySummary =>
      aiSummary?.trim().isNotEmpty == true ? aiSummary! : deterministicSummary;

  factory AgencySafetyRollup.fromJson(Map<String, dynamic> json) {
    final agency = SpeedBoardEntry._map(json['agencies']);
    return AgencySafetyRollup(
      id: json['id'].toString(),
      agencyName: agency['name']?.toString() ?? 'Agency',
      region: agency['region']?.toString(),
      status: json['status']?.toString() ?? 'insufficient_evidence',
      confidence: SpeedBoardEntry._number(json['confidence']),
      journeyCount: SpeedBoardEntry._integer(json['journeyCount']),
      violationJourneyCount:
          SpeedBoardEntry._integer(json['violationJourneyCount']),
      deterministicSummary: json['deterministicSummary']?.toString() ?? '',
      aiSummary: json['aiSummary']?.toString(),
    );
  }
}
