import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/widgets/tv_focusable_button.dart';

class TvAntiAddictionLockOverlay extends StatelessWidget {
  const TvAntiAddictionLockOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final TvAntiAddictionController controller =
        Get.find<TvAntiAddictionController>();
    return Obx(
      () {
        if (!controller.isLocked.value) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: Focus(
            autofocus: true,
            onKeyEvent: (FocusNode node, KeyEvent event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.escape ||
                      event.logicalKey == LogicalKeyboardKey.goBack ||
                      event.logicalKey == LogicalKeyboardKey.browserBack)) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: PopScope(
              canPop: false,
              child: Material(
                color: Colors.black.withOpacity(0.92),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.health_and_safety_outlined,
                            color: Color(0xFFFF7BAC),
                            size: 68,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            controller.lockTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            controller.lockSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 19,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _LockCountdown(controller: controller),
                          const SizedBox(height: 30),
                          TvFocusableButton(
                            autofocus: true,
                            icon: Icons.pin_outlined,
                            label: '家长 PIN 解锁',
                            onPressed: () => _showPinDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPinDialog(BuildContext context) async {
    final TvAntiAddictionController controller =
        Get.find<TvAntiAddictionController>();
    final String? pin = await showTvPinDialog(
      context,
      title: '家长 PIN 解锁',
      confirmLabel: '解锁',
    );
    if (pin == null) {
      return;
    }
    if (!controller.verifyPin(pin)) {
      Get.snackbar('PIN 错误', '请重新输入 4 位家长 PIN');
      return;
    }
    await controller.unlockByPin();
  }
}

class _LockCountdown extends StatelessWidget {
  const _LockCountdown({required this.controller});

  final TvAntiAddictionController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.lockReason.value == TvAntiAddictionLockReason.dailyLimit) {
      return const Text(
        '今日已锁定',
        style: TextStyle(
          color: Color(0xFFFF7BAC),
          fontSize: 30,
          fontWeight: FontWeight.w900,
        ),
      );
    }
    final int seconds = controller.remainingLockSeconds.value;
    return Text(
      _formatDuration(seconds),
      style: const TextStyle(
        color: Color(0xFFFF7BAC),
        fontSize: 44,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainSeconds.toString().padLeft(2, '0')}';
  }
}

Future<String?> showTvPinDialog(
  BuildContext context, {
  required String title,
  String confirmLabel = '确认',
}) {
  final TextEditingController textController = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF121A2B),
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: const InputDecoration(
            counterText: '',
            hintText: '请输入 4 位数字',
          ),
          onSubmitted: (_) {
            if (textController.text.length == 4) {
              Navigator.of(context).pop(textController.text);
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (textController.text.length == 4) {
                Navigator.of(context).pop(textController.text);
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
