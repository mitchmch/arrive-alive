import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A deliberately prominent, one-tap control for reporting the current speed
/// breach. Its icon and label communicate state without relying on colour.
class SpeedBreachReportControl extends StatelessWidget {
  const SpeedBreachReportControl({
    super.key,
    required this.isViolating,
    required this.isReported,
    required this.onReport,
  });

  final bool isViolating;
  final bool isReported;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final reported = isViolating && isReported;
    final enabled = isViolating && !reported && onReport != null;
    final label = reported
        ? 'Speed breach reported'
        : isViolating
            ? 'Report speed breach'
            : 'Speed report available above limit';

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: isViolating ? AppTheme.destructive : Colors.grey.shade600,
          elevation: isViolating ? 8 : 2,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('speed-breach-report-control'),
            customBorder: const CircleBorder(),
            onTap: enabled ? onReport : null,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    reported ? Icons.check_circle : Icons.speed,
                    color: Colors.white,
                    size: 27,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reported ? 'REPORTED' : 'REPORT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
