import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/widgets/first_launch_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('guide renders every feature from the central registry',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: FirstLaunchGuide()),
      ),
    );

    expect(appFeatureGuideItems, hasLength(12));
    expect(
      find.descendant(
        of: find.byKey(const Key('guide-feature-registry')),
        matching: find.byType(InkWell),
      ),
      findsNWidgets(appFeatureGuideItems.length),
    );
    for (final feature in appFeatureGuideItems) {
      expect(find.byKey(Key('guide-feature-${feature.id}')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const Key('guide-feature-navigation')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Navigation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('light and dark themes share the blue family and distinct surfaces', () {
    final light = AppTheme.lightTheme;
    final dark = AppTheme.darkTheme;

    expect(light.colorScheme.primary, AppTheme.primary);
    expect(light.scaffoldBackgroundColor, AppTheme.background);
    expect(dark.colorScheme.primary, AppTheme.darkPrimary);
    expect(dark.scaffoldBackgroundColor, AppTheme.darkBg);
    expect(dark.cardColor, AppTheme.darkCard);
    expect(light.navigationBarTheme.backgroundColor, AppTheme.surface);
    expect(dark.navigationBarTheme.backgroundColor, AppTheme.darkSurface);
  });
}
