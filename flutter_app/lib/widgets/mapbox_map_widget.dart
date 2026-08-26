import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../core/config.dart';
import '../core/mapbox_config.dart';

/// Data class for map markers.
class MapMarkerData {
  final double lat;
  final double lng;
  final Color color;
  final String emoji;
  final String label;
  final String type;
  final int? incidentId;
  final String? description;
  final String? timestamp;
  final int confirmationCount;
  final bool isLocal;

  const MapMarkerData({
    required this.lat,
    required this.lng,
    required this.color,
    this.emoji = '',
    this.label = '',
    this.type = 'hazard',
    this.incidentId,
    this.description,
    this.timestamp,
    this.confirmationCount = 0,
    this.isLocal = false,
  });
}

/// Data class for route polyline points.
class RoutePoint {
  final double lat;
  final double lng;

  const RoutePoint({required this.lat, required this.lng});
}

/// Hazard type colors (Waze-style). ARGB int values for Mapbox annotations.
/// Uses the new color scheme:
/// - Primary blue (#4361ee) for police
/// - Secondary lavender (#b8b8ff) for speed cameras
/// - Caution orange (#eb6424) for potholes/hazards
/// - Alert amber (#f9c784) for roadworks
/// - Warning red (#dd2d4a) for accidents
class HazardColors {
  static int accident = 0xFFdd2d4a; // Warning red
  static int pothole = 0xFFeb6424; // Caution orange
  static int police = 0xFF4361ee; // Primary blue
  static int speedCamera = 0xFFb8b8ff; // Secondary lavender
  static int roadworks = 0xFFf9c784; // Alert amber
  static int hazard = 0xFFeb6424; // Caution orange
  static int conduct = 0xFFdd2d4a; // Warning red

  /// Returns the ARGB int color for a given hazard type.
  static int colorForType(String type) {
    switch (type) {
      case 'accident':
        return accident;
      case 'pothole':
        return pothole;
      case 'police':
        return police;
      case 'speed_camera':
        return speedCamera;
      case 'roadworks':
        return roadworks;
      case 'hazard':
        return hazard;
      default:
        if (type.startsWith('conduct')) return conduct;
        return hazard;
    }
  }

  /// Returns a human-readable label for a hazard type.
  static String labelForType(String type) {
    switch (type) {
      case 'accident':
        return 'Accident';
      case 'pothole':
        return 'Pothole';
      case 'police':
        return 'Police Checkpoint';
      case 'speed_camera':
        return 'Speed Camera';
      case 'roadworks':
        return 'Roadworks';
      case 'hazard':
        return 'Road Hazard';
      default:
        if (type.startsWith('conduct_phone')) return 'Driver on Phone';
        if (type.startsWith('conduct')) return 'Driver Conduct';
        return 'Hazard';
    }
  }
}

/// Mapbox-powered map widget with dark navigation style (Waze-like).
/// Features:
/// - Mapbox navigation-night-v1 style with built-in traffic
/// - Additional traffic vector source + line layers for non-traffic styles
/// - 3D camera with pitch and bearing during navigation
/// - Waze-style colored hazard markers using CircleAnnotations
/// - Tap interactions on hazard markers (callback)
/// - Route polyline with glow effect (double layer)
/// - Follows user location
class MapboxMapWidget extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final Function(MapboxMap)? onMapCreated;
  final List<MapMarkerData> markers;
  final List<RoutePoint>? routePoints;
  final bool followUser;
  final double? bearing;
  final double? pitch;

  /// Called when a hazard marker is tapped.
  /// Returns the marker data that was tapped.
  final Function(MapMarkerData)? onHazardTap;

  const MapboxMapWidget({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialZoom = 13,
    this.onMapCreated,
    this.markers = const [],
    this.routePoints,
    this.followUser = false,
    this.bearing,
    this.pitch,
    this.onHazardTap,
  });

  @override
  State<MapboxMapWidget> createState() => _MapboxMapWidgetState();
}

class _MapboxMapWidgetState extends State<MapboxMapWidget>
    with WidgetsBindingObserver {
  MapboxMap? _map;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _lineManager;
  CircleAnnotationManager? _circleManager;
  bool _initialized = false;
  bool _styleLoaded = false;

  /// Maps annotation IDs to marker data for tap handling.
  final Map<String, MapMarkerData> _annotationToMarker = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MapboxConfig.ensureInitialized();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A theme change rebuilds this wrapper, but the stable MapWidget key and
    // explicit style URI preserve the native map and its navigation style.
    MapboxConfig.ensureInitialized();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Restore the process-wide setting whenever the app resumes.
      MapboxConfig.ensureInitialized();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _map = null;
    _pointManager = null;
    _lineManager = null;
    _circleManager = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.mapboxAccessToken.isEmpty) {
      return _buildNoTokenPlaceholder();
    }

    return MapWidget(
      key: const ValueKey('mapbox-map'),
      // Keep one explicit app-configured style across rebuilds, lifecycle
      // resumes, and light/dark theme changes.
      styleUri: AppConfig.mapboxStyleUri,
      // ignore: deprecated_member_use
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(widget.initialLng, widget.initialLat),
        ),
        zoom: widget.initialZoom,
        bearing: widget.bearing ?? 0,
        pitch: widget.pitch ?? 0,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }

  void _onMapCreated(MapboxMap map) {
    MapboxConfig.ensureInitialized();
    _map = map;
    _initialized = true;

    // Initialize all annotation managers
    map.annotations.createPointAnnotationManager().then((mgr) {
      if (!mounted || !identical(_map, map)) return;
      _pointManager = mgr;
      if (_styleLoaded) _addMarkers();
    });
    map.annotations.createPolylineAnnotationManager().then((mgr) {
      if (!mounted || !identical(_map, map)) return;
      _lineManager = mgr;
      if (_styleLoaded) _addRoute();
    });
    map.annotations.createCircleAnnotationManager().then((mgr) {
      if (!mounted || !identical(_map, map)) return;
      _circleManager = mgr;
      // Register tap handler for hazard markers
      mgr.tapEvents(onTap: _onCircleTap);
      if (_styleLoaded) _addHazardMarkers();
    });

    widget.onMapCreated?.call(map);
  }

  /// Handle tap on a hazard circle annotation.
  void _onCircleTap(CircleAnnotation annotation) {
    final marker = _annotationToMarker[annotation.id];
    if (marker != null && widget.onHazardTap != null) {
      widget.onHazardTap!(marker);
    }
  }

  void _onStyleLoaded(StyleLoadedEventData data) {
    _styleLoaded = true;

    // Add traffic layers for non-navigation styles
    if (AppConfig.enableTraffic) {
      _addTrafficLayer();
    }

    // Now that the style is loaded, add all annotations
    _addMarkers();
    _addRoute();
    _addHazardMarkers();
  }

  /// Add a Mapbox traffic vector source and line layers for real-time
  /// congestion display. This is automatically included in navigation styles
  /// but can be added separately for other styles (dark, streets, etc.).
  void _addTrafficLayer() async {
    if (_map == null) return;

    try {
      final style = _map!.style;

      // Check if traffic source already exists (navigation styles include it)
      final existing = await style.getSource('mapbox-traffic');
      if (existing != null) return; // Traffic already in the style

      // Add the Mapbox traffic vector source
      await style.addSource(
        VectorSource(
          id: 'mapbox-traffic',
          url: 'mapbox://mapbox.mapbox-traffic-v1',
        ),
      );

      // Traffic congestion line layer (low zoom — secondary roads)
      await style.addLayer(
        LineLayer(
          id: 'traffic-line-low',
          sourceId: 'mapbox-traffic',
          sourceLayer: 'traffic',
          minZoom: 14,
          lineColor: 0xFF33CC33, // Green (free flow)
          lineWidth: 2.0,
          lineOpacity: 0.7,
          filter: [
            '==',
            ['get', 'congestion'],
            'low',
          ],
        ),
      );

      // Moderate congestion (yellow)
      await style.addLayer(
        LineLayer(
          id: 'traffic-line-moderate',
          sourceId: 'mapbox-traffic',
          sourceLayer: 'traffic',
          minZoom: 14,
          lineColor: 0xFFFFCC00,
          lineWidth: 2.5,
          lineOpacity: 0.8,
          filter: [
            '==',
            ['get', 'congestion'],
            'moderate',
          ],
        ),
      );

      // Heavy congestion (red)
      await style.addLayer(
        LineLayer(
          id: 'traffic-line-heavy',
          sourceId: 'mapbox-traffic',
          sourceLayer: 'traffic',
          minZoom: 12,
          lineColor: 0xFFFF3333,
          lineWidth: 3.0,
          lineOpacity: 0.85,
          filter: [
            '==',
            ['get', 'congestion'],
            'heavy',
          ],
        ),
      );

      // Severe congestion (dark red)
      await style.addLayer(
        LineLayer(
          id: 'traffic-line-severe',
          sourceId: 'mapbox-traffic',
          sourceLayer: 'traffic',
          minZoom: 12,
          lineColor: 0xFFCC0000,
          lineWidth: 3.5,
          lineOpacity: 0.9,
          filter: [
            '==',
            ['get', 'congestion'],
            'severe',
          ],
        ),
      );
    } catch (e) {
      // Traffic layer is optional — fail silently if style doesn't support it
      debugPrint('Traffic layer setup skipped: $e');
    }
  }

  /// Add destination and point markers (using PointAnnotationManager).
  void _addMarkers() async {
    if (_pointManager == null || _map == null) return;
    await _pointManager!.deleteAll();

    for (final m in widget.markers) {
      if (m.type == 'destination') {
        final options = PointAnnotationOptions(
          geometry: Point(coordinates: Position(m.lng, m.lat)),
          iconSize: 1.5,
          symbolSortKey: 10,
        );
        await _pointManager!.create(options);
      }
    }
  }

  /// Add route polyline with glow effect (double layer).
  void _addRoute() async {
    if (_lineManager == null || widget.routePoints == null) return;
    if (widget.routePoints!.length < 2) return;

    final coords =
        widget.routePoints!.map((p) => Position(p.lng, p.lat)).toList();

    await _lineManager!.deleteAll();

    // Glow layer (wider, semi-transparent)
    await _lineManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: coords),
        lineColor: 0x334361ee, // Primary blue glow
        lineWidth: 12.0,
        lineOpacity: 0.4,
      ),
    );

    // Main route line
    await _lineManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: coords),
        lineColor: 0xFF4361ee, // Primary blue
        lineWidth: 5.0,
        lineOpacity: 0.9,
      ),
    );
  }

  /// Add Waze-style hazard markers as colored circles with tap handling.
  /// Each hazard type gets a distinct color:
  /// - Accident: Red, Pothole: Amber, Police: Blue
  /// - Speed Camera: Purple, Roadworks: Orange, Hazard: Yellow
  /// Markers store customData for tap identification.
  void _addHazardMarkers() async {
    if (_circleManager == null || _map == null) return;
    await _circleManager!.deleteAll();
    _annotationToMarker.clear();

    for (final m in widget.markers) {
      if (m.type == 'destination') continue;

      final color = HazardColors.colorForType(m.type);
      const strokeColor = 0xFFFFFFFF;

      final annotation = await _circleManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(m.lng, m.lat)),
          circleColor: color,
          circleRadius: 8.0,
          circleOpacity: 0.85,
          circleStrokeColor: strokeColor,
          circleStrokeWidth: 2.0,
          circleStrokeOpacity: 0.9,
          circleSortKey: 20,
          customData: {
            'type': m.type,
            'label': m.label,
            'lat': m.lat,
            'lng': m.lng,
            if (m.incidentId != null) 'incidentId': m.incidentId!,
            if (m.description != null) 'description': m.description!,
            if (m.timestamp != null) 'timestamp': m.timestamp!,
            'confirmationCount': m.confirmationCount,
            'isLocal': m.isLocal,
          },
        ),
      );

      // Map annotation ID to marker data for tap handling
      _annotationToMarker[annotation.id] = m;
    }
  }

  @override
  void didUpdateWidget(MapboxMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_initialized || _map == null) return;

    // Follow only when the snapped navigation camera actually changes. Marker
    // refreshes must not restart a camera animation.
    final cameraChanged = oldWidget.initialLat != widget.initialLat ||
        oldWidget.initialLng != widget.initialLng ||
        oldWidget.bearing != widget.bearing ||
        oldWidget.pitch != widget.pitch;
    if (widget.followUser && cameraChanged) {
      _map!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(widget.initialLng, widget.initialLat),
          ),
          zoom: widget.initialZoom,
          bearing: widget.bearing ?? 0,
          pitch: widget.pitch ?? 30,
        ),
        MapAnimationOptions(duration: 400),
      );
    }

    // Update markers and hazards
    if (oldWidget.markers != widget.markers) {
      _addMarkers();
      _addHazardMarkers();
    }

    // Update route
    if (oldWidget.routePoints != widget.routePoints) {
      _addRoute();
    }
  }

  Widget _buildNoTokenPlaceholder() {
    return Container(
      color: const Color(0xFF1a1a2e),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'Mapbox Token Required',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Run with --dart-define=MAPBOX_ACCESS_TOKEN=your_token',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
