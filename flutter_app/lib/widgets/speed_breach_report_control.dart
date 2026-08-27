import 'package:flutter/material.dart';

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
          color: Colors.white,
          elevation: isViolating ? 8 : 2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('speed-breach-report-control'),
            customBorder: const CircleBorder(),
            onTap: enabled ? onReport : null,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: isViolating
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          )
                        : const ColorFilter.matrix(<double>[
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0.52,
                            0,
                          ]),
                    child: Image.asset(
                      'assets/images/warning.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (reported)
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF16794A),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
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
