class Incident {
  final int id;
  final String type;
  final String? description;
  final double? lat;
  final double? lng;
  final String? vehicleReg;
  final String? driverName;
  final String timestamp;
  final String status;
  final int confirmationCount;
  final int notThereCount;
  final String? lastConfirmedAt;
  final String? resolvedAt;
  final bool? userConfirmedStillThere;
  final bool isLocal;

  const Incident({
    required this.id,
    required this.type,
    this.description,
    this.lat,
    this.lng,
    this.vehicleReg,
    this.driverName,
    required this.timestamp,
    this.status = 'active',
    this.confirmationCount = 0,
    this.notThereCount = 0,
    this.lastConfirmedAt,
    this.resolvedAt,
    this.userConfirmedStillThere,
    this.isLocal = false,
  });

  /// Treat legacy/unknown statuses as active, while honouring common resolved
  /// values returned by current and older API versions.
  bool get isActive {
    final normalized = status.toLowerCase().trim();
    return normalized != 'resolved' &&
        normalized != 'closed' &&
        normalized != 'inactive' &&
        normalized != 'removed';
  }

  Incident copyWith({
    int? id,
    String? type,
    String? description,
    double? lat,
    double? lng,
    String? vehicleReg,
    String? driverName,
    String? timestamp,
    String? status,
    int? confirmationCount,
    int? notThereCount,
    String? lastConfirmedAt,
    String? resolvedAt,
    bool? userConfirmedStillThere,
    bool? isLocal,
  }) {
    return Incident(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      vehicleReg: vehicleReg ?? this.vehicleReg,
      driverName: driverName ?? this.driverName,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      confirmationCount: confirmationCount ?? this.confirmationCount,
      notThereCount: notThereCount ?? this.notThereCount,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      userConfirmedStillThere:
          userConfirmedStillThere ?? this.userConfirmedStillThere,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  /// Applies an optimistic community confirmation.
  Incident withConfirmation(bool stillThere, {DateTime? at}) {
    final confirmedAt = (at ?? DateTime.now()).toIso8601String();
    return copyWith(
      status: stillThere ? 'active' : 'resolved',
      confirmationCount: stillThere ? confirmationCount + 1 : confirmationCount,
      notThereCount: stillThere ? notThereCount : notThereCount + 1,
      lastConfirmedAt: confirmedAt,
      resolvedAt: stillThere ? resolvedAt : confirmedAt,
      userConfirmedStillThere: stillThere,
    );
  }

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: _asInt(json['id']) ?? 0,
        type: json['type']?.toString() ?? '',
        description: json['description']?.toString(),
        lat: _asDouble(json['lat'] ?? json['latitude']),
        lng: _asDouble(json['lng'] ?? json['longitude']),
        vehicleReg: (json['vehicleReg'] ?? json['vehicle_reg'])?.toString(),
        driverName: (json['driverName'] ?? json['driver_name'])?.toString(),
        timestamp:
            (json['timestamp'] ?? json['createdAt'] ?? json['created_at'] ?? '')
                .toString(),
        status: _statusFromJson(json),
        confirmationCount: _asInt(
              json['confirmationCount'] ??
                  json['confirmation_count'] ??
                  json['stillThereCount'] ??
                  json['still_there_count'],
            ) ??
            0,
        notThereCount:
            _asInt(json['notThereCount'] ?? json['not_there_count']) ?? 0,
        lastConfirmedAt:
            (json['lastConfirmedAt'] ?? json['last_confirmed_at'])?.toString(),
        resolvedAt: (json['resolvedAt'] ?? json['resolved_at'])?.toString(),
        userConfirmedStillThere: _asBool(
          json['userConfirmedStillThere'] ?? json['user_confirmed_still_there'],
        ),
        isLocal: _asBool(json['isLocal'] ?? json['is_local']) ?? false,
      );

  /// Parses the deliberately limited public hazard shape. Reporter identity
  /// and vehicle registration are ignored even if a malformed server response
  /// includes them.
  factory Incident.fromPublicJson(Map<String, dynamic> json) {
    final incident = Incident.fromJson({
      ...json,
      // The public ID is intentionally opaque. Mutations still use the numeric
      // remote ID supplied by the contract.
      'id': json['remoteId'] ?? json['remote_id'] ?? json['id'],
      'timestamp': json['updatedAt'] ??
          json['updated_at'] ??
          json['lastConfirmedAt'] ??
          json['last_confirmed_at'] ??
          '',
      'confirmationCount': json['stillThere'] ??
          json['still_there'] ??
          json['confirmationCount'],
      'notThereCount':
          json['notThere'] ?? json['not_there'] ?? json['notThereCount'],
    });
    return incident.copyWith(vehicleReg: '', driverName: '');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'description': description,
        'lat': lat,
        'lng': lng,
        'vehicleReg': vehicleReg,
        'driverName': driverName,
        'timestamp': timestamp,
        'status': status,
        'confirmationCount': confirmationCount,
        'notThereCount': notThereCount,
        'lastConfirmedAt': lastConfirmedAt,
        'resolvedAt': resolvedAt,
        'userConfirmedStillThere': userConfirmedStillThere == null
            ? null
            : (userConfirmedStillThere! ? 1 : 0),
        'isLocal': isLocal ? 1 : 0,
      };

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return null;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }

  static String _statusFromJson(Map<String, dynamic> json) {
    if (json['status'] != null) return json['status'].toString();
    if (_asBool(json['resolved']) == true ||
        _asBool(json['active'] ?? json['isActive']) == false) {
      return 'resolved';
    }
    return 'active';
  }
}
