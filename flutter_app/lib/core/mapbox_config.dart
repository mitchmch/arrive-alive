import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'config.dart';

/// Applies the public Mapbox configuration before a native map is created.
///
/// Calling this more than once is intentional and safe. It lets an independently
/// mounted map (for example after a hot restart or lifecycle resume) restore the
/// process-wide SDK token without changing the configured style.
abstract final class MapboxConfig {
  static bool ensureInitialized() {
    final token = AppConfig.mapboxAccessToken.trim();
    if (token.isEmpty) return false;

    MapboxOptions.setAccessToken(token);
    return true;
  }
}
