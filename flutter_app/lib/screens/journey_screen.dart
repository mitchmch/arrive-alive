import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme.dart';
import '../core/config.dart';
import '../core/access_policy.dart';
import '../controllers/journey_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/hazard_controller.dart';
import '../controllers/agency_notice_controller.dart';
import '../models/agency_notice.dart';
import '../models/incident.dart';
import '../services/location_service.dart';
import '../services/tts_service.dart';
import '../widgets/speedometer_widget.dart';
import '../widgets/navigation_overlay.dart';
import '../widgets/hazard_map.dart';
import '../widgets/mapbox_map_widget.dart';
import '../widgets/first_launch_guide.dart';
import 'access_screen.dart';
import 'report_screen.dart';
import 'scoreboard_screen.dart';
import 'profile_screen.dart';
import 'travel_flow_screen.dart';
import 'journey_evidence_summary_screen.dart';

class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  GoogleMapController? _mapController;
  CameraPosition? _initialCamera;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _mapReady = false;
  bool _showMap = true;
  bool _showHazards = true;
  bool _showSearchOverlay = false;
  bool _isEndingJourney = false;
  Set<Marker> _hazardMarkers = {};
  LatLng? _currentLocation;
  final HazardAlertTracker _hazardAlertTracker = HazardAlertTracker();
  final List<HazardProximityAlert> _pendingHazardAlerts = [];
  bool _processingHazardAlerts = false;
  bool _hazardSheetOpen = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _initialCamera = const CameraPosition(
      target: LatLng(AppConfig.cameroonCenterLat, AppConfig.cameroonCenterLng),
      zoom: 7,
    );
    _mapReady = true;
    // Hazard visibility does not depend on location permission or account type.
    // Guests start the same polling lifecycle as registered users.
    ref.read(hazardProvider.notifier).startPolling();
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(journeyProvider.notifier).refreshSpeedLimit();
      _showAgencyNotices();
    });
  }

  Future<void> _showAgencyNotices() async {
    final user = ref.read(authProvider).user;
    if (user == null || user.isGuest) return;
    try {
      final notices =
          await ref.read(unseenAgencyNoticesProvider(user.id).future);
      for (final notice in notices) {
        if (!mounted) return;
        final avoid = notice.classification == AgencyClassification.avoid;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              avoid ? Icons.warning_amber_rounded : Icons.verified_outlined,
              color: avoid ? AppTheme.destructive : AppTheme.primary,
            ),
            title: Text(avoid ? 'Agency to avoid' : 'Trusted agency'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.agencyName,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
                if (notice.summaryText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(notice.summaryText),
                ],
                const SizedBox(height: 8),
                Text(
                  'Classification is set from reviewed evidence. Any AI '
                  'summary above is display text only.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
        await ref.read(agencyNoticeServiceProvider).markSeen(user.id, notice);
      }
    } catch (_) {
      // Notices are supplementary and must never block an offline journey.
    }
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _initialCamera = CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 17,
        );
        _mapReady = true;
      });
      // Do not start recording here. Route/destination setup must remain
      // stationary until the customer explicitly taps Start Recording.
    }
  }

  void _updateMap(double lat, double lng) {
    _currentLocation = LatLng(lat, lng);

    // Update navigation and hazard awareness for both Google Maps and Mapbox.
    final journey = ref.read(journeyProvider);
    ref.read(navigationControllerProvider.notifier).updatePosition(
          _currentLocation!,
          isMoving: journey.isMoving,
          accuracyMeters: journey.currentAccuracy,
          activeJourneyTime: journey.duration,
        );
    _checkNearbyHazards();

    if (_mapController == null) return;

    // Smooth camera follow
    _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));

    // Update path polyline
    if (journey.path.isNotEmpty) {
      final points =
          journey.path.map((p) => LatLng(p['lat']!, p['lng']!)).toList();
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: AppTheme.primary,
            width: 5,
            jointType: JointType.round,
            endCap: Cap.roundCap,
            startCap: Cap.roundCap,
          ),
        };
      });
    }
  }

  void _updateHazardMarkers() {
    final hazard = ref.read(hazardProvider);
    final markers = <Marker>{};
    for (final incident in hazard.incidents) {
      if (incident.lat != null && incident.lng != null) {
        markers.add(
          buildIncidentMarker(
            incident,
            onTap: () => _showIncidentDetails(incident),
          ),
        );
      }
    }
    setState(() {
      _hazardMarkers = markers;
      _markers = _showHazards ? markers : {};
    });
  }

  void _checkNearbyHazards() {
    final journey = ref.read(journeyProvider);
    final location = _currentLocation;
    if (!journey.isRecording ||
        !journey.isMoving ||
        location == null ||
        _hazardSheetOpen) {
      return;
    }
    final nearby = ref
        .read(hazardProvider.notifier)
        .incidentsNear(location, radiusMeters: 850);
    if (nearby.isEmpty) return;

    for (final incident in nearby) {
      _pendingHazardAlerts.addAll(
        _hazardAlertTracker.observe(
          incidentId: incident.id,
          distanceMeters: incidentDistanceMeters(location, incident),
          accuracyMeters: journey.currentAccuracy,
        ),
      );
    }
    _processHazardAlerts();
  }

  Future<void> _processHazardAlerts() async {
    if (_processingHazardAlerts) return;
    _processingHazardAlerts = true;
    try {
      while (mounted && _pendingHazardAlerts.isNotEmpty) {
        final alert = _pendingHazardAlerts.removeAt(0);
        final incident =
            ref.read(hazardProvider.notifier).incidentById(alert.incidentId);
        if (incident == null || !incident.isActive) continue;
        final label = HazardColors.labelForType(incident.type);
        if (alert.thresholdMeters == 800) {
          await TtsService().speak('$label ahead in about 800 metres.');
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('$label ahead • 800 m'),
                duration: const Duration(seconds: 3),
              ),
            );
        } else {
          await TtsService().speak('$label ahead in about 500 metres.');
          if (!mounted) return;
          await _showIncidentDetails(
            incident,
            isWarning: true,
            confirmationAlert: true,
          );
        }
      }
    } finally {
      _processingHazardAlerts = false;
    }
  }

  void _fitRouteToBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _updateNavigationRoute() {
    final nav = ref.read(navigationControllerProvider);
    if (nav.route != null && nav.isNavigating) {
      final routePolyline = Polyline(
        polylineId: const PolylineId('navigation'),
        points: nav.route!.polylinePoints,
        color: AppTheme.success,
        width: 6,
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      );

      setState(() {
        // Keep journey path + add navigation route
        final journey = ref.read(journeyProvider);
        final pathPoints =
            journey.path.map((p) => LatLng(p['lat']!, p['lng']!)).toList();
        _polylines = {
          if (pathPoints.isNotEmpty)
            Polyline(
              polylineId: const PolylineId('route'),
              points: pathPoints,
              color: AppTheme.primary,
              width: 4,
              jointType: JointType.round,
            ),
          routePolyline,
        };
      });
    }
  }

  Future<void> _goBack() async {
    final journey = ref.read(journeyProvider);
    if (journey.isRecording) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Leave active journey?'),
          content: const Text(
            'The current journey will be stopped and saved before you go back.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Stop & Go Back'),
            ),
          ],
        ),
      );
      if (shouldLeave != true) return;
      await ref.read(journeyProvider.notifier).stopRecording();
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      final auth = ref.read(authProvider);
      if (auth.user?.isGuest ?? false) {
        await ref.read(authProvider.notifier).logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AccessScreen()),
          (_) => false,
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TravelFlowScreen()),
        );
      }
    }
  }

  Future<void> _endJourney() async {
    if (_isEndingJourney) return;
    setState(() => _isEndingJourney = true);
    try {
      final summary = await ref.read(journeyProvider.notifier).stopRecording();
      if (!mounted) return;
      final auth = ref.read(authProvider);
      final canOpenBoard = AccessPolicy.canAccessScoreboard(auth.user);
      final navigator = Navigator.of(context);
      final authNotifier = ref.read(authProvider.notifier);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => JourneyEvidenceSummaryScreen(
            summary: summary,
            canOpenSpeedBoard: canOpenBoard,
            onOpenSpeedBoard: canOpenBoard
                ? () => navigator.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ScoreboardScreen(),
                      ),
                    )
                : null,
            onDone: () {
              if (auth.user?.isGuest ?? false) {
                authNotifier.logout();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AccessScreen()),
                  (_) => false,
                );
              } else {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const TravelFlowScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isEndingJourney = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the journey. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = ref.watch(journeyProvider);
    final nav = ref.watch(navigationControllerProvider);

    // Listen to journey state changes
    ref.listen<JourneyState>(journeyProvider, (prev, next) {
      if (next.isRecording && prev?.isRecording != true) {
        _hazardAlertTracker.reset();
        _pendingHazardAlerts.clear();
      }
      if (next.path.isNotEmpty && (prev?.path.length ?? 0) < next.path.length) {
        final last = next.path.last;
        _updateMap(last['lat']!, last['lng']!);
      } else if (next.isRecording && next.isMoving) {
        _checkNearbyHazards();
      }
    });

    // Listen to hazard state changes
    ref.listen<HazardState>(hazardProvider, (prev, next) {
      if (prev?.incidents != next.incidents) {
        _updateHazardMarkers();
        _checkNearbyHazards();
      }
    });

    // Listen to navigation state changes
    ref.listen<NavigationState>(navigationControllerProvider, (prev, next) {
      if (prev?.route != next.route ||
          prev?.isNavigating != next.isNavigating) {
        _updateNavigationRoute();
      }
      // Show a newly fetched route once on the Google Maps fallback. Mapbox
      // follows each road-snapped fix below instead.
      if (!AppConfig.useMapbox &&
          prev?.route != next.route &&
          next.isNavigating &&
          next.route != null &&
          next.route!.polylinePoints.isNotEmpty) {
        _fitRouteToBounds(next.route!.polylinePoints);
      }
    });

    final limit = journey.speedLimit;

    return PopScope(
      canPop: _allowPop || !journey.isRecording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Map or Speedometer view
            if (_showMap && _mapReady && _initialCamera != null)
              AppConfig.useMapbox
                  ? MapboxMapWidget(
                      initialLat: nav.snappedPosition?.latitude ??
                          _currentLocation?.latitude ??
                          AppConfig.cameroonCenterLat,
                      initialLng: nav.snappedPosition?.longitude ??
                          _currentLocation?.longitude ??
                          AppConfig.cameroonCenterLng,
                      initialZoom: 17,
                      followUser: true,
                      pitch: nav.isNavigating ? 50 : 30,
                      bearing: nav.isNavigating ? nav.routeBearing : 0,
                      routePoints: _buildMapboxRoute(),
                      markers: _buildMapboxMarkers(),
                      onHazardTap: (marker) {
                        _showHazardDetails(marker);
                      },
                    )
                  : GoogleMap(
                      initialCameraPosition: _initialCamera!,
                      onMapCreated: (c) => _mapController = c,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      trafficEnabled: true,
                      markers: _showHazards
                          ? {..._markers, ..._hazardMarkers}
                          : _markers,
                      polylines: _polylines,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      padding: EdgeInsets.only(
                        top: nav.isNavigating ? 120 : 0,
                        bottom: 200,
                      ),
                    )
            else if (!_mapReady)
              const Center(child: CircularProgressIndicator())
            else
              _fullSpeedometerView(journey, limit),

            // Violation flash overlay
            if (journey.isViolating)
              Container(color: Colors.red.withValues(alpha: 0.15)),

            // Navigation instruction card (top)
            if (_showMap && _mapReady) const NavigationInstructionCard(),

            // A persistent way back that remains available on every map state.
            if (_showMap && _mapReady)
              Positioned(
                top: 8,
                left: 12,
                child: SafeArea(
                  child: FloatingActionButton.small(
                    heroTag: 'go_back',
                    tooltip: 'Go Back',
                    onPressed: _goBack,
                    backgroundColor: AppTheme.surface,
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),

            // Map controls overlay (right side)
            if (_showMap && _mapReady)
              Positioned(
                top: nav.isNavigating ? 140 : 60,
                right: 12,
                child: Column(
                  children: [
                    // Navigate button
                    FloatingActionButton.small(
                      heroTag: 'navigate',
                      tooltip: 'Set destination',
                      onPressed: () {
                        setState(() => _showSearchOverlay = true);
                      },
                      backgroundColor: nav.isNavigating
                          ? AppTheme.success
                          : AppTheme.surface,
                      child: Icon(
                        Icons.navigation,
                        color: nav.isNavigating
                            ? Colors.white
                            : AppTheme.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Hazard toggle
                    HazardToggleButton(
                      isShowing: _showHazards,
                      onToggle: () {
                        setState(() {
                          _showHazards = !_showHazards;
                          if (!_showHazards) {
                            ref.read(hazardProvider.notifier).stopPolling();
                          } else {
                            ref.read(hazardProvider.notifier).startPolling();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'journey_help',
                      tooltip: 'Open quick guide',
                      onPressed: () => FirstLaunchGuide.show(context),
                      backgroundColor: AppTheme.surface,
                      child: const Icon(
                        Icons.help_outline,
                        color: AppTheme.textPrimary,
                        size: 20,
                      ),
                    ),
                    if (AccessPolicy.canAccessProfile(
                      ref.watch(authProvider).user,
                    )) ...[
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'profile',
                        tooltip: 'Open profile',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        backgroundColor: AppTheme.surface,
                        child: const Icon(
                          Icons.person_outline,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Toggle speedometer/map
                    FloatingActionButton.small(
                      heroTag: 'toggle_view',
                      tooltip: _showMap ? 'Show speedometer' : 'Show map',
                      onPressed: () => setState(() => _showMap = !_showMap),
                      backgroundColor: AppTheme.surface,
                      child: Icon(
                        _showMap ? Icons.speed : Icons.map,
                        color: AppTheme.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Report button
                    FloatingActionButton.small(
                      heroTag: 'report_incident',
                      tooltip: 'Report incident',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReportScreen(initialLocation: _currentLocation),
                        ),
                      ),
                      backgroundColor: AppTheme.primary,
                      child: const Icon(
                        Icons.report,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

            // Hazard info banner (top left, below nav card)
            if (_showMap && _mapReady && _showHazards)
              Positioned(
                top: nav.isNavigating ? 130 : 60,
                left: 12,
                child: const HazardInfoBanner(),
              ),

            // Compact live speed instrument. It uses the same filtered journey
            // speed as every other meter and occupies minimal map space.
            if (_showMap && _mapReady)
              Positioned(
                left: 12,
                bottom: nav.isNavigating ? 224 : 188,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: SpeedometerWidget(
                      speed: journey.currentSpeed,
                      speedLimit: limit,
                      isViolating: journey.isViolating,
                      isMoving: journey.isMoving,
                      compact: true,
                    ),
                  ),
                ),
              ),

            // Destination search overlay
            if (_showSearchOverlay && _currentLocation != null)
              DestinationSearchOverlay(
                currentLocation: _currentLocation!,
                onClose: () => setState(() => _showSearchOverlay = false),
              ),

            // Bottom speed sheet
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _bottomSheet(journey, limit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fullSpeedometerView(JourneyState journey, double limit) {
    final nav = ref.watch(navigationControllerProvider);
    return Container(
      color: AppTheme.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _goBack,
                    tooltip: 'Go Back',
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () => FirstLaunchGuide.show(context),
                    tooltip: 'Open quick guide',
                    icon: const Icon(Icons.help_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Navigation instruction in speedometer view
            if (nav.isNavigating && nav.nextInstruction != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getManeuverIcon(nav.nextManeuver),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nav.nextInstruction!,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
            SpeedometerWidget(
              speed: journey.currentSpeed,
              speedLimit: limit,
              isViolating: journey.isViolating,
              isMoving: journey.isMoving,
              size: 280,
            ),
            const Spacer(),
            _statsBar(journey),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _bottomSheet(JourneyState journey, double limit) {
    final nav = ref.watch(navigationControllerProvider);
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Navigation info in compact sheet
              if (nav.isNavigating && nav.route != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.navigation,
                        size: 14,
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${nav.route!.destinationName} • ${(nav.remainingDistanceMeters / 1000).toStringAsFixed(1)} km • ${(nav.remainingDurationSeconds / 60).round()} min',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              _statsBar(journey),
              const SizedBox(height: 12),
              if (!journey.isRecording)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: journey.isSpeedLimitLoading
                        ? null
                        : () async {
                            final auth = ref.read(authProvider);
                            await ref
                                .read(journeyProvider.notifier)
                                .startRecording(auth.user?.id);
                          },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      journey.isSpeedLimitLoading
                          ? 'Loading speed limit…'
                          : 'Start Recording',
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isEndingJourney ? null : _endJourney,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.destructive,
                        ),
                        icon: const Icon(Icons.stop),
                        label: Text(
                          _isEndingJourney ? 'Saving…' : 'Stop & Save',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => setState(() => _showMap = !_showMap),
                      tooltip: _showMap ? 'Show speedometer' : 'Show map',
                      icon: Icon(_showMap ? Icons.speed : Icons.map),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.card,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsBar(JourneyState journey) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _stat('Duration', _formatDuration(journey.duration)),
        _stat('Distance', '${journey.distance.toStringAsFixed(1)} km'),
        _stat('Max Speed', '${journey.maxSpeed.toStringAsFixed(0)} km/h'),
        _stat(
          'Violations',
          '${journey.violationCount}',
          color: journey.violationCount > 0 ? AppTheme.destructive : null,
        ),
      ],
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  IconData _getManeuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-left':
      case 'turn-slight-left':
      case 'turn-sharp-left':
        return Icons.turn_left;
      case 'turn-right':
      case 'turn-slight-right':
      case 'turn-sharp-right':
        return Icons.turn_right;
      case 'uturn':
        return Icons.u_turn_left;
      case 'roundabout-left':
      case 'roundabout-right':
      case 'roundabout':
        return Icons.roundabout_right;
      case 'merge':
        return Icons.merge;
      case 'fork-left':
        return Icons.fork_left;
      case 'fork-right':
        return Icons.fork_right;
      case 'keep-left':
        return Icons.turn_slight_left;
      case 'keep-right':
        return Icons.turn_slight_right;
      case 'ramp-left':
        return Icons.ramp_left;
      case 'ramp-right':
        return Icons.ramp_right;
      default:
        return Icons.straight;
    }
  }

  // --- Mapbox helper methods ---

  /// Show a bottom sheet with hazard details when a marker is tapped.
  void _showHazardDetails(MapMarkerData marker) {
    final incident = marker.incidentId == null
        ? null
        : ref.read(hazardProvider.notifier).incidentById(marker.incidentId!);
    if (incident != null) {
      _showIncidentDetails(incident);
      return;
    }
    // Backward-compatible fallback for marker data without an incident ID.
    _showIncidentDetails(
      Incident(
        id: marker.incidentId ?? 0,
        type: marker.type,
        description: marker.description ?? marker.label,
        lat: marker.lat,
        lng: marker.lng,
        timestamp: marker.timestamp ?? '',
        confirmationCount: marker.confirmationCount,
        isLocal: marker.isLocal,
      ),
    );
  }

  Future<void> _showIncidentDetails(
    Incident incident, {
    bool isWarning = false,
    bool confirmationAlert = false,
  }) async {
    if (_hazardSheetOpen) return;
    _hazardSheetOpen = true;
    if (confirmationAlert) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
    final color = Color(HazardColors.colorForType(incident.type));
    final label = HazardColors.labelForType(incident.type);
    final location = _currentLocation;
    final distance = location == null
        ? null
        : incidentDistanceMeters(location, incident).round();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isWarning
                          ? Icons.warning_amber_rounded
                          : Icons.report_problem_outlined,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isWarning)
                          Text(
                            'HAZARD AHEAD',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 1.2,
                            ),
                          ),
                        Text(
                          label,
                          style: GoogleFonts.dmSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (distance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        distance < 1000
                            ? '$distance m'
                            : '${(distance / 1000).toStringAsFixed(1)} km',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              if (incident.description?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                Text(
                  incident.description!,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${incident.confirmationCount} still-there confirmation'
                '${incident.confirmationCount == 1 ? '' : 's'}'
                '${incident.isLocal ? ' • Pending sync' : ''}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Is it still there?',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        ref
                            .read(hazardProvider.notifier)
                            .confirmIncident(incident.id, true);
                      },
                      icon: const Icon(Icons.thumb_up_alt_outlined),
                      label: const Text('Still there'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        ref
                            .read(hazardProvider.notifier)
                            .confirmIncident(incident.id, false);
                      },
                      icon: const Icon(Icons.not_interested),
                      label: const Text('Not there'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    _hazardSheetOpen = false;
  }

  List<RoutePoint> _buildMapboxRoute() {
    final nav = ref.watch(navigationControllerProvider);
    if (nav.route == null) return [];
    return nav.route!.polylinePoints
        .map((point) => RoutePoint(lat: point.latitude, lng: point.longitude))
        .toList();
  }

  List<MapMarkerData> _buildMapboxMarkers() {
    final nav = ref.watch(navigationControllerProvider);
    final markers = <MapMarkerData>[];

    // Destination marker
    if (nav.destination != null) {
      markers.add(
        MapMarkerData(
          lat: nav.destination!.lat,
          lng: nav.destination!.lng,
          color: AppTheme.primary,
          emoji: '🏁',
          label: 'Destination',
          type: 'destination',
        ),
      );
    }

    // Live hazard markers (Waze-style colored circles)
    if (_showHazards) {
      final hazardState = ref.watch(hazardProvider);
      for (final h in hazardState.incidents) {
        if (h.lat != null && h.lng != null) {
          markers.add(
            MapMarkerData(
              lat: h.lat!,
              lng: h.lng!,
              color: AppTheme.destructive,
              emoji: '',
              label: h.description ?? HazardColors.labelForType(h.type),
              type: h.type, // accident, pothole, police, etc.
              incidentId: h.id,
              description: h.description,
              timestamp: h.timestamp,
              confirmationCount: h.confirmationCount,
              isLocal: h.isLocal,
            ),
          );
        }
      }
    }

    return markers;
  }

  @override
  void dispose() {
    // Stop hazard polling when leaving the screen
    ref.read(hazardProvider.notifier).stopPolling();
    super.dispose();
  }
}
