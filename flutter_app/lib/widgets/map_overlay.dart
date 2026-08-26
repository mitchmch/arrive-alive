import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Legacy map overlay — kept for backward compatibility.
/// The JourneyScreen now handles its own overlay controls.
class MapOverlay extends StatelessWidget {
  final VoidCallback onToggleView;
  final VoidCallback onReport;

  const MapOverlay({
    super.key,
    required this.onToggleView,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 48,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FloatingActionButton.small(
            heroTag: 'toggle',
            onPressed: onToggleView,
            backgroundColor: AppTheme.surface,
            child: const Icon(Icons.speed, color: AppTheme.textPrimary),
          ),
          FloatingActionButton(
            heroTag: 'report',
            onPressed: onReport,
            backgroundColor: AppTheme.primary,
            child: const Icon(Icons.report, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
