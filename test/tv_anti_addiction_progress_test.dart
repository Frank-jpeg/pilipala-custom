import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/pages/anti_addiction/tv_anti_addiction_lock_page.dart';

void main() {
  group('TV anti-addiction progress', () {
    late TvAntiAddictionController controller;

    setUp(() {
      controller = TvAntiAddictionController();
    });

    test('session remaining time and progress shrink with usage', () {
      controller.sessionLimitMinutes.value = 75;
      controller.sessionUsedSeconds.value = 15 * 60;

      expect(controller.sessionLimitSeconds, 75 * 60);
      expect(controller.sessionRemainingSeconds, 60 * 60);
      expect(controller.sessionRemainingProgress, 0.8);
    });

    test('session remaining values clamp at zero', () {
      controller.sessionLimitMinutes.value = 15;
      controller.sessionUsedSeconds.value = 20 * 60;

      expect(controller.sessionRemainingSeconds, 0);
      expect(controller.sessionRemainingProgress, 0);
    });

    test('temporary PIN extension overrides the configured session limit', () {
      controller.sessionLimitMinutes.value = 1;
      controller.temporarySessionLimitSeconds.value = 15 * 60;
      controller.sessionUsedSeconds.value = 4 * 60;
      controller.enabled.value = true;

      expect(controller.hasTemporarySessionLimit, isTrue);
      expect(controller.sessionLimitSeconds, 15 * 60);
      expect(controller.sessionRemainingSeconds, 11 * 60);
      expect(controller.sessionRemainingProgress, closeTo(11 / 15, 0.0001));
      expect(controller.isSessionLimited, isFalse);

      controller.sessionUsedSeconds.value = 15 * 60;

      expect(controller.isSessionLimited, isTrue);

      controller.resetSession();

      expect(controller.hasTemporarySessionLimit, isFalse);
      expect(controller.sessionLimitSeconds, 60);
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

  testWidgets('custom session minutes replace the current value and save',
      (WidgetTester tester) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showTvNumberInputDialog(
                context,
                title: '自定义单次观看时长',
                initialValue: 30,
                minValue: 1,
                maxValue: 720,
                unit: '分钟',
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(result, 15);
  });
}
