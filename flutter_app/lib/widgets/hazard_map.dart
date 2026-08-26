import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../controllers/hazard_controller.dart';
import '../models/incident.dart';

/// Builds Google Maps markers for community incidents.
/// Uses colored circle markers since custom asset icons require bundled assets.
Marker buildIncidentMarker(Incident incident, {VoidCallback? onTap}) {
  final color = _getIncidentColor(incident.type);

  return Marker(
    markerId: MarkerId('hazard_${incident.id}'),
    position: LatLng(incident.lat!, incident.lng!),
    icon: BitmapDescriptor.defaultMarkerWithHue(color),
    infoWindow: InfoWindow(
      title: _getIncidentLabel(incident.type),
      snippet: _formatSnippet(incident),
    ),
    onTap: onTap,
  );
}

double _getIncidentColor(String type) {
  switch (type) {
    case 'accident':
      return BitmapDescriptor.hueRed;
    case 'hazard':
    case 'pothole':
      return BitmapDescriptor.hueOrange;
    case 'police':
    case 'speed_camera':
      return BitmapDescriptor.hueBlue;
    case 'roadworks':
      return BitmapDescriptor.hueYellow;
    case 'conduct_phone':
    case 'conduct_drinking':
    case 'conduct_sleeping':
    case 'conduct_distracted':
    case 'conduct_flipflops':
    case 'conduct_smoking':
      return BitmapDescriptor.hueViolet;
    default:
      return BitmapDescriptor.hueRose;
  }
}

String _getIncidentLabel(String type) {
  const labels = {
    'accident': 'Accident',
    'hazard': 'Road Hazard',
    'pothole': 'Pothole',
    'police': 'Police Checkpoint',
    'speed_camera': 'Speed Camera',
    'roadworks': 'Roadworks',
    'conduct_phone': 'Driver on Phone',
    'conduct_drinking': 'Driver Drinking',
    'conduct_sleeping': 'Driver Sleeping',
    'conduct_distracted': 'Distracted Driver',
    'conduct_flipflops': 'Driver in Flip-flops',
    'conduct_smoking': 'Driver Smoking',
  };
  return labels[type] ?? 'Incident';
}

String _formatSnippet(Incident incident) {
  final parts = <String>[];
  if (incident.description != null && incident.description!.isNotEmpty) {
    parts.add(incident.description!);
  }
  try {
    final time = DateTime.parse(incident.timestamp);
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      parts.add('Just now');
    } else if (diff.inMinutes < 60) {
      parts.add('${diff.inMinutes}m ago');
    } else if (diff.inHours < 24) {
      parts.add('${diff.inHours}h ago');
    } else {
      parts.add('${diff.inDays}d ago');
    }
  } catch (_) {}

  return parts.join(' • ');
}

/// A floating hazard toggle button for the map
class HazardToggleButton extends ConsumerStatefulWidget {
  final bool isShowing;
  final VoidCallback onToggle;

  const HazardToggleButton({
    super.key,
    required this.isShowing,
    required this.onToggle,
  });

  @override
  ConsumerState<HazardToggleButton> createState() => _HazardToggleButtonState();
}

class _HazardToggleButtonState extends ConsumerState<HazardToggleButton> {
  @override
  Widget build(BuildContext context) {
    final hazard = ref.watch(hazardProvider);

    return FloatingActionButton.small(
      heroTag: 'hazard_toggle',
      tooltip: widget.isShowing ? 'Hide hazards' : 'Show hazards',
      onPressed: widget.onToggle,
      backgroundColor: widget.isShowing ? AppTheme.primary : AppTheme.surface,
      child: Badge(
        isLabelVisible: hazard.incidents.isNotEmpty && !widget.isShowing,
        label: Text(
          '${hazard.incidents.length}',
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
        child: Icon(
          Icons.warning_amber_rounded,
          color: widget.isShowing ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }
}

/// Hazard info banner showing live status
class HazardInfoBanner extends ConsumerWidget {
  const HazardInfoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazard = ref.watch(hazardProvider);

    if (hazard.incidents.isEmpty && !hazard.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hazard.isFromCache
            ? AppTheme.warning.withValues(alpha: 0.1)
            : AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hazard.isFromCache
              ? AppTheme.warning.withValues(alpha: 0.3)
              : AppTheme.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hazard.isFromCache ? Icons.cloud_off : Icons.cloud_done,
            size: 14,
            color: hazard.isFromCache ? AppTheme.warning : AppTheme.success,
          ),
          const SizedBox(width: 4),
          Text(
            hazard.isFromCache
                ? '${hazard.incidents.length} hazards (offline)'
                : '${hazard.incidents.length} live hazards',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hazard.isFromCache ? AppTheme.warning : AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}
