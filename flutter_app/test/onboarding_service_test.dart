import 'package:arrive_alive/services/onboarding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first-launch guide is shown once after its seen flag is stored',
      () async {
    SharedPreferences.setMockInitialValues({});

    expect(await OnboardingService.shouldShowFirstLaunchGuide(), isTrue);

    await OnboardingService.markFirstLaunchGuideSeen();

    expect(await OnboardingService.shouldShowFirstLaunchGuide(), isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(OnboardingService.firstLaunchGuideSeenKey),
      isTrue,
    );
  });
}
