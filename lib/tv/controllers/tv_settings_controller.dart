import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/pages/anti_addiction/tv_anti_addiction_lock_page.dart';
import 'package:pilipala/utils/storage.dart';

class TvSettingsController extends GetxController {
  final RxBool autoFullscreenEnabled = true.obs;
  final RxInt autoFullscreenDelaySeconds = 15.obs;
  final RxBool danmakuEnabled = true.obs;
  late final TvAntiAddictionController antiAddiction;

  static const int minDelaySeconds = 5;
  static const int maxDelaySeconds = 60;
  static const int delayStepSeconds = 5;
  static const List<int> sessionOptions = <int>[15, 30, 45, 60];
  static const List<int> restOptions = <int>[5, 10, 20, 30];
  static const List<int> dailyOptions = <int>[0, 60, 90, 120, 180];

  // 进设置页后防沉迷相关改动只验一次家长 PIN；控制器随路由销毁，下次进入自动重置。
  bool _pinVerifiedForEdit = false;

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
    danmakuEnabled.value = GStrorage.setting.get(
      SettingBoxKey.enableShowDanmaku,
      defaultValue: true,
    ) as bool;
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

  Future<void> toggleDanmaku() async {
    danmakuEnabled.value = !danmakuEnabled.value;
    await GStrorage.setting.put(
      SettingBoxKey.enableShowDanmaku,
      danmakuEnabled.value,
    );
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

  Future<void> selectSessionLimit(BuildContext context) async {
    if (!await _verifyPinIfNeeded(context)) {
      return;
    }
    final int? value = await showTvOptionDialog(
      context: context,
      title: '单次观看时长',
      options: sessionOptions,
      current: antiAddiction.sessionLimitMinutes.value,
      labelBuilder: (int v) => '$v 分钟',
    );
    if (value == null) {
      return;
    }
    await antiAddiction.setSessionLimitMinutes(value);
  }

  Future<void> selectRestMinutes(BuildContext context) async {
    if (!await _verifyPinIfNeeded(context)) {
      return;
    }
    final int? value = await showTvOptionDialog(
      context: context,
      title: '强制休息时长',
      options: restOptions,
      current: antiAddiction.restMinutes.value,
      labelBuilder: (int v) => '$v 分钟',
    );
    if (value == null) {
      return;
    }
    await antiAddiction.setRestMinutes(value);
  }

  Future<void> selectDailyLimit(BuildContext context) async {
    if (!await _verifyPinIfNeeded(context)) {
      return;
    }
    final int? value = await showTvOptionDialog(
      context: context,
      title: '每日总时长',
      options: dailyOptions,
      current: antiAddiction.dailyLimitMinutes.value,
      labelBuilder: (int v) => v == 0 ? '关闭' : '$v 分钟',
    );
    if (value == null) {
      return;
    }
    await antiAddiction.setDailyLimitMinutes(value);
  }

  Future<bool> _verifyPinIfNeeded(BuildContext context) async {
    if (!antiAddiction.enabled.value || !antiAddiction.hasPin) {
      return true;
    }
    if (_pinVerifiedForEdit) {
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
    _pinVerifiedForEdit = true;
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
