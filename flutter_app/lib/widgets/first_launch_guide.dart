import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class FirstLaunchGuide extends StatefulWidget {
  const FirstLaunchGuide({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstLaunchGuide(),
    );
  }

  @override
  State<FirstLaunchGuide> createState() => _FirstLaunchGuideState();
}

class _FirstLaunchGuideState extends State<FirstLaunchGuide> {
  int _step = 0;

  static const _steps = [
    (
      icon: Icons.play_circle_outline,
      title: 'Start and record',
      body:
          'Tap Start Recording when the vehicle moves. Your live speed and journey stats stay together.',
    ),
    (
      icon: Icons.navigation_outlined,
      title: 'Navigate',
      body:
          'Use Navigate to choose a destination while the map keeps your route and speed guidance in view.',
    ),
    (
      icon: Icons.warning_amber_rounded,
      title: 'Check hazards',
      body:
          'Tap any active hazard for details, then confirm Still there or Not there for other road users.',
    ),
    (
      icon: Icons.report_outlined,
      title: 'Report and review',
      body:
          'Use Report to pin a road issue. Registered users can also open Speed Board.',
    ),
  ];

  void _next() {
    SystemSound.play(SystemSoundType.click);
    if (_step == _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step++);
  }

  void _previous() {
    if (_step == 0) return;
    SystemSound.play(SystemSoundType.click);
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quick guide',
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close guide',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Semantics(
                image: true,
                label: 'Current step: ${step.title}',
                child: ExcludeSemantics(
                  child: Icon(
                    step.icon,
                    color: colors.onPrimaryContainer,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              step.title,
              key: const Key('guide-step-title'),
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.body,
              style: GoogleFonts.dmSans(
                height: 1.45,
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              container: true,
              label:
                  'Guide progress. Step ${_step + 1} of ${_steps.length}: ${step.title}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _steps.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Semantics(
                      label: 'Step ${index + 1}: ${_steps[index].title}',
                      selected: index == _step,
                      child: ExcludeSemantics(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: index == _step
                                ? colors.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _steps[index].icon,
                            size: 20,
                            color: index == _step
                                ? colors.onPrimaryContainer
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_step > 0)
                  TextButton(onPressed: _previous, child: const Text('Back')),
                const Spacer(),
                FilledButton(
                  key: const Key('guide-next'),
                  onPressed: _next,
                  child: Text(_step == _steps.length - 1 ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
