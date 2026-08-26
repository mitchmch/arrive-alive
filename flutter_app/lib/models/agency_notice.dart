enum AgencyClassification { trusted, withinLimit, avoid, unclassified }

AgencyClassification parseAgencyClassification(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'trusted':
      return AgencyClassification.trusted;
    case 'within_limit':
    case 'withinlimit':
      return AgencyClassification.withinLimit;
    case 'avoid':
      return AgencyClassification.avoid;
    default:
      return AgencyClassification.unclassified;
  }
}

class AgencyNotice {
  final String id;
  final int agencyId;
  final String agencyName;
  final AgencyClassification classification;
  final String summaryText;
  final int version;

  const AgencyNotice({
    required this.id,
    required this.agencyId,
    required this.agencyName,
    required this.classification,
    required this.summaryText,
    required this.version,
  });

  String get deduplicationKey => '$id:$version';

  factory AgencyNotice.fromJson(Map<String, dynamic> json) => AgencyNotice(
        id: json['id'].toString(),
        agencyId: ((json['data'] as Map?)?['agencyId'] as num?)?.toInt() ??
            (json['agencyId'] as num?)?.toInt() ??
            0,
        agencyName:
            json['agencyName']?.toString() ?? json['title']?.toString() ?? '',
        classification: parseAgencyClassification(
          (json['data'] as Map?)?['status'] ??
              (json['type'] == 'agency_trusted'
                  ? 'trusted'
                  : json['type'] == 'agency_avoid'
                      ? 'avoid'
                      : json['classification']),
        ),
        summaryText:
            json['body']?.toString() ?? json['summaryText']?.toString() ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
      );
}
