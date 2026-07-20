import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/pages/anti_addiction/tv_anti_addiction_lock_page.dart';

class _FakeAntiAddictionController extends TvAntiAddictionController {
  @override
  void load() {}
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
}
