import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/pages/anti_addiction/tv_anti_addiction_lock_page.dart';
import 'package:pilipala/utils/storage.dart';

class TvSettingsController extends GetxController {
  final RxBool autoFullscreenEnabled = true.obs;
  final RxInt autoFullscreenDelaySeconds = 15.obs;
  late final TvAntiAddictionController antiAddiction;

  static const int minDelaySeconds = 5;
  static const int maxDelaySeconds = 60;
  static const int delayStepSeconds = 5;
  static const List<int> sessionOptions = <int>[15, 30, 45, 60];
  static const List<int> restOptions = <int>[5, 10, 20, 30];
  static const List<int> dailyOptions = <int>[0, 60, 90, 120, 180];

  void load() {
    antiAddiction = Get.find<TvAntiAddictionController>();
    antiAddiction.load();
    autoFullscreenEnabled.value = GStrorage.setting.get(
      SettingBoxKey.tvAutoFullscreenEnable,
      defaultValue: true,
    ) as bool;
    final int delay = GStrorage.setting.get(
      SettingBoxKey.tvAutoFullscreenDelay,
      defaultValue: 15,
    ) as int;
    autoFullscreenDelaySeconds.value =
        delay.clamp(minDelaySeconds, maxDelaySeconds);
  }

  Future<void> toggleAutoFullscreen() async {
    autoFullscreenEnabled.value = !autoFullscreenEnabled.value;
    await GStrorage.setting.put(
      SettingBoxKey.tvAutoFullscreenEnable,
      autoFullscreenEnabled.value,
    );
    _applyHomeSettings();
  }

  Future<void> decreaseDelay() async {
    await _setDelay(autoFullscreenDelaySeconds.value - delayStepSeconds);
  }

  Future<void> increaseDelay() async {
    await _setDelay(autoFullscreenDelaySeconds.value + delayStepSeconds);
  }

  String get dailyLimitLabel {
    final int value = antiAddiction.dailyLimitMinutes.value;
    return value == 0 ? '已关闭' : '$value 分钟';
  }

  String get antiAddictionStatus => antiAddiction.enabled.value ? '已开启' : '已关闭';

  String get pinStatus => antiAddiction.hasPin ? '已设置' : '未设置';

  Future<void> toggleAntiAddiction(BuildContext context) async {
    if (antiAddiction.enabled.value) {
      if (!await _verifyPinIfNeeded(context)) {
        return;
      }
      await antiAddiction.setEnabled(false);
      return;
    }
    if (!antiAddiction.hasPin) {
      final bool created = await setOrChangePin(context);
      if (!created) {
        return;
      }
    }
    await antiAddiction.setEnabled(true);
  }

  Future<bool> setOrChangePin(BuildContext context) async {
    if (antiAddiction.hasPin) {
      final String? oldPin = await showTvPinDialog(
        context,
        title: '验证当前 PIN',
        confirmLabel: '下一步',
      );
      if (oldPin == null) {
        return false;
      }
      if (!antiAddiction.verifyPin(oldPin)) {
        Get.snackbar('PIN 错误', '当前 PIN 不正确');
        return false;
      }
      return _promptAndSavePin(
        title: '设置新 PIN',
        confirmLabel: '保存',
      );
    }
    return _promptAndSavePin(
      title: '设置家长 PIN',
      confirmLabel: '保存',
    );
  }

  Future<bool> _promptAndSavePin({
    required String title,
    required String confirmLabel,
  }) async {
    final BuildContext? context = Get.context;
    if (context == null) {
      return false;
    }
    final String? pin = await showTvPinDialog(
      context,
      title: title,
      confirmLabel: confirmLabel,
    );
    if (pin == null) {
      return false;
    }
    await antiAddiction.setPin(pin);
    antiAddiction.load();
    return true;
  }

  Future<void> cycleSessionLimit(BuildContext context) async {
    if (!await _verifyPinIfNeeded(context)) {
      return;
    }
    await antiAddiction.setSessionLimitMinutes(
      _nextValue(sessionOptions, antiAddiction.sessionLimitMinutes.value),
    );
  }

  Future<void> cycleRestMinutes(BuildContext context) async {
    if (!await _verifyPinIfNeeded(context)) {
      return;
    }
    await antiAddiction.setRestMinutes(
      _nextValue(restOptions, antiAddiction.restMinutes.value),
    );
  }

  Future<void> cycleDailyLimit(BuildContext context) async {
    if (!await _verifyPinIfNeeded(context)) {
      return;
    }
    await antiAddiction.setDailyLimitMinutes(
      _nextValue(dailyOptions, antiAddiction.dailyLimitMinutes.value),
    );
  }

  int _nextValue(List<int> options, int current) {
    final int index = options.indexOf(current);
    if (index < 0 || index == options.length - 1) {
      return options.first;
    }
    return options[index + 1];
  }

  Future<bool> _verifyPinIfNeeded(BuildContext context) async {
    if (!antiAddiction.enabled.value || !antiAddiction.hasPin) {
      return true;
    }
    final String? pin = await showTvPinDialog(
      context,
      title: '家长 PIN 验证',
      confirmLabel: '确认',
    );
    if (pin == null) {
      return false;
    }
    if (!antiAddiction.verifyPin(pin)) {
      Get.snackbar('PIN 错误', '请重新输入 4 位家长 PIN');
      return false;
    }
    return true;
  }

  Future<void> _setDelay(int value) async {
    autoFullscreenDelaySeconds.value =
        value.clamp(minDelaySeconds, maxDelaySeconds);
    await GStrorage.setting.put(
      SettingBoxKey.tvAutoFullscreenDelay,
      autoFullscreenDelaySeconds.value,
    );
    _applyHomeSettings();
  }

  void _applyHomeSettings() {
    if (Get.isRegistered<TvHomeController>()) {
      Get.find<TvHomeController>().applyAutoFullscreenSettings();
    }
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }
}
