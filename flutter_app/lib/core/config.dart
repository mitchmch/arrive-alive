/// App configuration constants
class AppConfig {
  /// Backend API base URL. Override with --dart-define=API_BASE_URL=https://...
  // Public Edge Function URL, for example https://PROJECT.supabase.co/functions/v1/app-api.
  // This is not a secret; authentication is an opaque per-user bearer token.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://otbbyvdhqbnjvswrwzft.supabase.co/functions/v1/app-api',
  );

  /// True when the configured public API endpoint is usable.
  static bool get hasBackend =>
      apiBaseUrl.trim().isNotEmpty &&
      (apiBaseUrl.startsWith('https://') || apiBaseUrl.startsWith('http://'));

  // Mapbox access token (public pk. token) - get from https://account.mapbox.com/
  // Can also be overridden via --dart-define=MAPBOX_ACCESS_TOKEN=your_token
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  // Mapbox style URI for navigation (dark theme like Waze)
  // The navigation-night-v1 style includes real-time traffic by default.
  // Alternatives:
  //   mapbox://styles/mapbox/navigation-day-v1  (light with traffic)
  //   mapbox://styles/mapbox/standard            (3D standard)
  //   mapbox://styles/mapbox/dark-v11            (dark, no traffic)
  static const String mapboxStyleUri = String.fromEnvironment(
    'MAPBOX_STYLE_URI',
    defaultValue: 'mapbox://styles/mapbox/navigation-night-v1',
  );

  // Enable real-time traffic layer (requires navigation style or Mapbox Traffic API)
  static const bool enableTraffic = bool.fromEnvironment(
    'ENABLE_TRAFFIC',
    defaultValue: true,
  );

  // Google Maps API key - kept as fallback if Mapbox token is not set
  // Android: android/app/src/main/AndroidManifest.xml
  // iOS: ios/Runner/AppDelegate.swift
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // Whether to use Mapbox as the default map provider
  static bool get useMapbox => mapboxAccessToken.isNotEmpty;

  // Cameroon center coordinates (Yaoundé)
  static const double cameroonCenterLat = 3.8480;
  static const double cameroonCenterLng = 11.5021;
  static const double cameroonDefaultZoom = 6.5;

  // Incident map auto-refresh interval
  static const int hazardRefreshSeconds = 30;
  static const String publicActiveHazardsPath = '/api/public-hazards';
  static const String publicSpeedLimitsPath = '/api/public-speed-limits';

  // Major Cameroon cities for destination search bias
  static const List<String> cameroonCities = [
    'Douala',
    'Yaoundé',
    'Bamenda',
    'Bafoussam',
    'Garoua',
    'Maroua',
    'Buea',
    'Limbe',
    'Kumba',
    'Bamenda',
    'Ngaoundéré',
    'Bertoua',
    'Ebolowa',
    'Kribi',
    'Tiko',
    'Dschang',
    'Mbouda',
    'Loum',
    'Nkongsamba',
    'Bafang',
  ];

  // Speed limits (km/h) - default 70, managed by admin backend
  static const double defaultSpeedLimit = 70;
  static const Map<String, double> speedLimits = {
    'car': 70,
    'bus': 70,
    'lorry': 70,
    'bike': 70,
  };

  // Violation detection threshold
  static const int violationReadingsThreshold =
      5; // readings above limit in 60s
  static const int violationWindowSeconds = 60;

  // Vehicle types - Cameroon-specific per mode
  static const Map<String, List<String>> vehicleTypes = {
    'car': [
      'Saloon',
      'SUV',
      'Pickup',
      'Hatchback',
      'Station Wagon',
      'Crossover',
    ],
    'bus': [
      'Toyota Coaster',
      'Minibus (Hiace)',
      'Coach',
      'Van',
      'Double-decker',
    ],
    'lorry': [
      'Flatbed',
      'Tipper',
      'Tanker',
      'Box truck',
      'Refrigerated',
      'Container',
      'Lowbed',
    ],
    'bike': [
      'Haojue',
      'Jincheng',
      'Honda CG125',
      'Bajaj Boxer',
      'TVS Star',
      'Keke (Tricycle)',
    ],
  };

  static const Map<String, List<String>> assets = {
    'car': [
      'Seatbelts',
      'Fire Extinguisher',
      'Comfortable Seats',
      'Windows Lifter',
    ],
    'bus': [
      'Seatbelts',
      'Fire Extinguisher',
      'Comfortable Seats',
      'Child Seat',
      'Disabled Seats',
      'Windows Working',
      'Air Conditioning',
      'WiFi',
      'Television',
    ],
    'lorry': [
      'Seatbelts',
      'Fire Extinguisher',
      'Comfortable Seats',
      'Windows Lifter',
    ],
    'bike': ['Driver Helmet', 'Comfortable Seats', 'Passenger Helmets'],
  };

  static const Map<String, List<String>> defects = {
    'car': [
      'Broken Mirrors',
      'Broken Windscreen',
      'Broken Seats',
      'No Seatbelts',
      'No Window Handles',
      'Driver in Flip-flops',
      'Driver Smoking',
      'Driver with Phone',
    ],
    'bus': [
      'No Seatbelts',
      'Damaged Windows',
      'Damaged Windscreen',
      'Driver in Flip-flops',
      'Driver No Uniform',
      'Driver with Phone',
    ],
    'lorry': [
      'Broken Mirrors',
      'Broken Windscreen',
      'Broken Seats',
      'No Seatbelts',
      'No Window Handles',
      'Driver in Flip-flops',
      'Driver Smoking',
      'Driver with Phone',
    ],
    'bike': [
      'Broken Mirrors',
      'Broken Seats',
      'Driver in Flip-flops',
      'Driver Smoking',
      'Driver with Phone',
    ],
  };

  static const List<Map<String, String>> incidentTypes = [
    {'id': 'accident', 'label': 'Accident', 'icon': '⚠️'},
    {'id': 'hazard', 'label': 'Road Hazard', 'icon': '🚧'},
    {'id': 'pothole', 'label': 'Pothole', 'icon': '🕳️'},
    {'id': 'police', 'label': 'Police Checkpoint', 'icon': '👮'},
    {'id': 'speed_camera', 'label': 'Speed Camera', 'icon': '📷'},
    {'id': 'roadworks', 'label': 'Roadworks', 'icon': '🔧'},
  ];

  static const List<Map<String, String>> conductTypes = [
    {'id': 'conduct_phone', 'label': 'Driver on Phone', 'icon': '📱'},
    {'id': 'conduct_drinking', 'label': 'Driver Drinking', 'icon': '🍺'},
    {'id': 'conduct_sleeping', 'label': 'Driver Sleeping', 'icon': '😴'},
    {'id': 'conduct_distracted', 'label': 'Distracted Driver', 'icon': '👀'},
    {'id': 'conduct_flipflops', 'label': 'Driver in Flip-flops', 'icon': '🩴'},
    {'id': 'conduct_smoking', 'label': 'Driver Smoking', 'icon': '🚬'},
  ];
}
