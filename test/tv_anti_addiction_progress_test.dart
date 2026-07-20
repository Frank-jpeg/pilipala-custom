import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';

void main() {
  group('TV anti-addiction progress', () {
    late TvAntiAddictionController controller;

    setUp(() {
      controller = TvAntiAddictionController();
    });

    test('session remaining time and progress shrink with usage', () {
      controller.sessionLimitMinutes.value = 30;
      controller.sessionUsedSeconds.value = 10 * 60;

      expect(controller.sessionLimitSeconds, 30 * 60);
      expect(controller.sessionRemainingSeconds, 20 * 60);
      expect(controller.sessionRemainingProgress, closeTo(2 / 3, 0.0001));
    });

    test('session remaining values clamp at zero', () {
      controller.sessionLimitMinutes.value = 15;
      controller.sessionUsedSeconds.value = 20 * 60;

      expect(controller.sessionRemainingSeconds, 0);
      expect(controller.sessionRemainingProgress, 0);
    });

    test('daily remaining values are available only with a daily limit', () {
      controller.dailyLimitMinutes.value = 120;
      controller.dailyUsedSeconds.value = 30 * 60;

      expect(controller.hasDailyLimit, isTrue);
      expect(controller.dailyRemainingSeconds, 90 * 60);
      expect(controller.dailyRemainingProgress, 0.75);

      controller.dailyLimitMinutes.value = 0;

      expect(controller.hasDailyLimit, isFalse);
      expect(controller.dailyRemainingSeconds, 0);
      expect(controller.dailyRemainingProgress, 0);
      expect(controller.dailyUsedSeconds.value, 30 * 60);
    });

    test('daily remaining values clamp after the limit is reached', () {
      controller.dailyLimitMinutes.value = 60;
      controller.dailyUsedSeconds.value = 75 * 60;

      expect(controller.dailyRemainingSeconds, 0);
      expect(controller.dailyRemainingProgress, 0);
    });
  });
}
