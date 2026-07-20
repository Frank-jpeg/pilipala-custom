import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/pages/anti_addiction/tv_anti_addiction_lock_page.dart';

class _FakeAntiAddictionController extends TvAntiAddictionController {
  int? grantedExtensionMinutes;

  @override
  void load() {}

  @override
  bool verifyPin(String value) => true;

  @override
  Future<void> unlockByPin(int extensionMinutes) async {
    grantedExtensionMinutes = extensionMinutes;
    isLocked.value = false;
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('lock overlay yields to the PIN dialog and restores focus',
      (WidgetTester tester) async {
    final _FakeAntiAddictionController controller =
        _FakeAntiAddictionController();
    controller.isLocked.value = true;
    controller.lockReason.value = TvAntiAddictionLockReason.rest;
    controller.restMinutes.value = 20;
    controller.remainingLockSeconds.value = 19 * 60 + 43;
    Get.put<TvAntiAddictionController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: SizedBox.expand()),
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: <Widget>[
              Positioned.fill(child: child ?? const SizedBox.shrink()),
              const TvAntiAddictionLockOverlay(),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('该休息一下啦'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tvAntiAddictionUnlock',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('该休息一下啦'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('•'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('该休息一下啦'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('verified PIN asks for a 10, 15, or 20 minute extension',
      (WidgetTester tester) async {
    final _FakeAntiAddictionController controller =
        _FakeAntiAddictionController();
    controller.isLocked.value = true;
    controller.lockReason.value = TvAntiAddictionLockReason.rest;
    controller.restMinutes.value = 20;
    controller.remainingLockSeconds.value = 20 * 60;
    Get.put<TvAntiAddictionController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: SizedBox.expand()),
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: <Widget>[
              Positioned.fill(child: child ?? const SizedBox.shrink()),
              const TvAntiAddictionLockOverlay(),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    for (int i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    }
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    expect(find.text('选择延长观看时间'), findsOneWidget);
    expect(find.text('10 分钟'), findsOneWidget);
    expect(find.text('15 分钟'), findsOneWidget);
    expect(find.text('20 分钟'), findsOneWidget);

    await tester.tap(find.text('15 分钟'));
    await tester.pumpAndSettle();

    expect(controller.grantedExtensionMinutes, 15);
    expect(controller.isLocked.value, isFalse);
  });
}
