import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppFeatureGuideItem {
  const AppFeatureGuideItem({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

/// The single registry for customer-facing key features.
///
/// Add a feature here and the first-launch guide, progress controls, semantics,
/// and profile-opened guide all update together.
const List<AppFeatureGuideItem> appFeatureGuideItems = [
  AppFeatureGuideItem(
    id: 'start',
    icon: Icons.play_circle_outline,
    color: Color(0xFF1565C0),
    title: 'Start and record',
    body:
        'Tap Start Recording only when you are ready. Your live speed and journey evidence stay together.',
  ),
  AppFeatureGuideItem(
    id: 'vehicle-limit',
    icon: Icons.signpost_outlined,
    color: Color(0xFFE65100),
    title: 'Vehicle speed limit',
    body:
        'The map loads the admin-set limit for your selected car, bus, lorry, or bike before recording and keeps it fixed for that journey.',
  ),
  AppFeatureGuideItem(
    id: 'navigation',
    icon: Icons.navigation_outlined,
    color: Color(0xFF6A1B9A),
    title: 'Navigation',
    body:
        'Set a destination while the map keeps route guidance, live speed, and the selected limit in view.',
  ),
  AppFeatureGuideItem(
    id: 'voice',
    icon: Icons.record_voice_over_outlined,
    color: Color(0xFF00695C),
    title: 'Voice guidance',
    body:
        'ElevenLabs provides an African cloud voice for navigation and shared-hazard warnings. If cloud audio is unavailable, your device voice takes over automatically.',
  ),
  AppFeatureGuideItem(
    id: 'hazard-800',
    icon: Icons.radar_outlined,
    color: Color(0xFF6D4C41),
    title: 'Shared hazard at 800 m',
    body:
        'Each shared active hazard gives one early warning at about 800 metres during a journey.',
  ),
  AppFeatureGuideItem(
    id: 'hazard-500',
    icon: Icons.warning_amber_rounded,
    color: Color(0xFFB71C1C),
    title: 'Hazard check at 500 m',
    body:
        'At about 500 metres, a second alert opens the community confirmation for that hazard once.',
  ),
  AppFeatureGuideItem(
    id: 'haptic',
    icon: Icons.vibration,
    color: Color(0xFF283593),
    title: 'Buzz and sound',
    body:
        'A sound and haptic buzz accompany the hazard confirmation so it is less likely to be missed.',
  ),
  AppFeatureGuideItem(
    id: 'confirmation',
    icon: Icons.fact_check_outlined,
    color: Color(0xFF2E7D32),
    title: 'Confirm a hazard',
    body:
        'Choose Still there or Not there to keep shared hazard information useful for other road users.',
  ),
  AppFeatureGuideItem(
    id: 'report',
    icon: Icons.report_outlined,
    color: Color(0xFF006064),
    title: 'Report',
    body:
        'Use Report to pin a road issue at its GPS location and share it with the community.',
  ),
  AppFeatureGuideItem(
    id: 'speed-breach-report',
    icon: Icons.speed,
    color: Color(0xFFC62828),
    title: 'Report a speed breach',
    body:
        'The bottom-right control activates automatically when speed exceeds the fixed journey limit. Tap the red control once to save a report; it stays marked Reported until speed drops below the limit.',
  ),
  AppFeatureGuideItem(
    id: 'map-speedometer',
    icon: Icons.speed_outlined,
    color: Color(0xFF4527A0),
    title: 'Map and speedometer',
    body:
        'Switch between the live map and the full speedometer without interrupting your journey.',
  ),
  AppFeatureGuideItem(
    id: 'profile',
    icon: Icons.person_outline,
    color: Color(0xFF880E4F),
    title: 'Profile',
    body:
        'Registered users can review their profile, journey history, settings, and this guide.',
  ),
  AppFeatureGuideItem(
    id: 'scoreboard',
    icon: Icons.leaderboard_outlined,
    color: Color(0xFF795500),
    title: 'Speed Board',
    body:
        'Registered users can review published safety results and agency performance on the Speed Board.',
  ),
];

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

  void _select(int index) {
    if (index == _step) return;
    SystemSound.play(SystemSoundType.click);
    setState(() => _step = index);
  }

  void _next() {
    SystemSound.play(SystemSoundType.click);
    if (_step == appFeatureGuideItems.length - 1) {
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
    final step = appFeatureGuideItems[_step];
    final colors = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: screen.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Key features',
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
              const SizedBox(height: 12),
              Wrap(
                key: const Key('guide-feature-registry'),
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var index = 0;
                      index < appFeatureGuideItems.length;
                      index++)
                    Semantics(
                      button: true,
                      label:
                          'Feature ${index + 1}: ${appFeatureGuideItems[index].title}',
                      selected: index == _step,
                      child: Tooltip(
                        message: appFeatureGuideItems[index].title,
                        child: InkWell(
                          key: Key(
                            'guide-feature-${appFeatureGuideItems[index].id}',
                          ),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _select(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: appFeatureGuideItems[index]
                                  .color
                                  .withValues(
                                      alpha: index == _step ? 0.22 : 0.12),
                              border: Border.all(
                                color: index == _step
                                    ? appFeatureGuideItems[index].color
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              appFeatureGuideItems[index].icon,
                              size: 21,
                              color: appFeatureGuideItems[index].color,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Semantics(
                  image: true,
                  label: 'Current feature: ${step.title}',
                  child: ExcludeSemantics(
                    child: Icon(
                      step.icon,
                      color: step.color,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                  height: 1.4,
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label:
                    'Guide progress. Feature ${_step + 1} of ${appFeatureGuideItems.length}: ${step.title}',
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _previous,
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('guide-next'),
                      onPressed: _next,
                      child: Text(
                        _step == appFeatureGuideItems.length - 1
                            ? 'Done'
                            : 'Next',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
