import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/pages/anti_addiction/tv_anti_addiction_lock_page.dart';
import 'package:pilipala/utils/global_data_cache.dart';
import 'package:pilipala/utils/storage.dart';

class TvSettingsController extends GetxController {
  final RxBool recommendPreviewAutoplayEnabled = false.obs;
  final RxBool autoFullscreenEnabled = true.obs;
  final RxInt autoFullscreenDelaySeconds = 5.obs;
  final RxBool danmakuEnabled = true.obs;
  final RxDouble danmakuShowArea = 0.5.obs;
  final RxDouble danmakuDuration = 4.0.obs;
  final RxDouble danmakuFontScale = 1.0.obs;
  final RxDouble danmakuOpacity = 1.0.obs;
  final RxDouble danmakuStrokeWidth = 1.5.obs;
  final RxList<dynamic> danmakuBlockTypes = <dynamic>[].obs;
  late final TvAntiAddictionController antiAddiction;

  static const int minDelaySeconds = 5;
  static const int maxDelaySeconds = 60;
  static const int delayStepSeconds = 5;
  static const List<double> danmakuAreaOptions = <double>[0.25, 0.5, 0.75, 1.0];
  static const List<double> danmakuDurationOptions = <double>[
    2,
    4,
    6,
    8,
    12,
    16
  ];
  static const List<double> danmakuFontScaleOptions = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
    2.5,
  ];
  static const List<double> danmakuOpacityOptions = <double>[
    0.25,
    0.5,
    0.75,
    1.0
  ];
  static const List<double> danmakuStrokeOptions = <double>[
    0,
    0.5,
    1,
    1.5,
    2,
    3
  ];
  static const List<int> sessionOptions = <int>[15, 30, 45, 60];
  static const List<int> restOptions = <int>[5, 10, 20, 30];
  static const List<int> dailyOptions = <int>[0, 60, 90, 120, 180];

  // 进设置页后防沉迷相关改动只验一次家长 PIN；控制器随路由销毁，下次进入自动重置。
  bool _pinVerifiedForEdit = false;

  void load() {
    antiAddiction = Get.find<TvAntiAddictionController>();
    antiAddiction.load();
    recommendPreviewAutoplayEnabled.value = GStrorage.setting.get(
      SettingBoxKey.tvRecommendPreviewAutoplayEnable,
      defaultValue: false,
    ) as bool;
    autoFullscreenEnabled.value = GStrorage.setting.get(
      SettingBoxKey.tvAutoFullscreenEnable,
      defaultValue: true,
    ) as bool;
    final int delay = GStrorage.setting.get(
      SettingBoxKey.tvAutoFullscreenDelay,
      defaultValue: 5,
    ) as int;
    autoFullscreenDelaySeconds.value =
        delay.clamp(minDelaySeconds, maxDelaySeconds);
    danmakuEnabled.value = GStrorage.setting.get(
      SettingBoxKey.enableShowDanmaku,
      defaultValue: true,
    ) as bool;
    danmakuShowArea.value = _readDouble(
      LocalCacheKey.danmakuShowArea,
      defaultValue: 0.5,
    );
    danmakuDuration.value = _readDouble(
      LocalCacheKey.danmakuDuration,
      defaultValue: 4.0,
    );
    danmakuFontScale.value = _readDouble(
      LocalCacheKey.danmakuFontScale,
      defaultValue: 1.0,
    );
    danmakuOpacity.value = _readDouble(
      LocalCacheKey.danmakuOpacity,
      defaultValue: 1.0,
    );
    danmakuStrokeWidth.value = _readDouble(
      LocalCacheKey.strokeWidth,
      defaultValue: 1.5,
    );
    danmakuBlockTypes.value = List<dynamic>.from(
      GStrorage.localCache.get(
        LocalCacheKey.danmakuBlockType,
        defaultValue: <dynamic>[],
      ) as List,
    );
    _syncDanmakuGlobalCache();
  }

  Future<void> toggleRecommendPreviewAutoplay() async {
    recommendPreviewAutoplayEnabled.value =
        !recommendPreviewAutoplayEnabled.value;
    await GStrorage.setting.put(
      SettingBoxKey.tvRecommendPreviewAutoplayEnable,
      recommendPreviewAutoplayEnabled.value,
    );
    _applyHomeSettings();
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
    _syncDanmakuGlobalCache();
  }

  String get danmakuAreaLabel {
    final double area = danmakuShowArea.value;
    if ((area - 0.25).abs() < 0.01) {
      return '1/4屏';
    }
    if ((area - 0.5).abs() < 0.01) {
      return '半屏';
    }
    if ((area - 0.75).abs() < 0.01) {
      return '3/4屏';
    }
    return '满屏';
  }

  String get danmakuDurationLabel =>
      '${danmakuDuration.value.toStringAsFixed(0)} 秒';

  String get danmakuFontScaleLabel =>
      '${(danmakuFontScale.value * 100).round()}%';

  String get danmakuOpacityLabel => '${(danmakuOpacity.value * 100).round()}%';

  String get danmakuStrokeLabel {
    final double stroke = danmakuStrokeWidth.value;
    return stroke % 1 == 0
        ? stroke.toStringAsFixed(0)
        : stroke.toStringAsFixed(1);
  }

  bool isDanmakuBlockEnabled(int type) => danmakuBlockTypes.contains(type);

  Future<void> cycleDanmakuArea() async {
    await _cycleDouble(
      values: danmakuAreaOptions,
      current: danmakuShowArea,
      key: LocalCacheKey.danmakuShowArea,
    );
  }

  Future<void> cycleDanmakuDuration() async {
    await _cycleDouble(
      values: danmakuDurationOptions,
      current: danmakuDuration,
      key: LocalCacheKey.danmakuDuration,
    );
  }

  Future<void> cycleDanmakuFontScale() async {
    await _cycleDouble(
      values: danmakuFontScaleOptions,
      current: danmakuFontScale,
      key: LocalCacheKey.danmakuFontScale,
    );
  }

  Future<void> cycleDanmakuOpacity() async {
    await _cycleDouble(
      values: danmakuOpacityOptions,
      current: danmakuOpacity,
      key: LocalCacheKey.danmakuOpacity,
    );
  }

  Future<void> cycleDanmakuStroke() async {
    await _cycleDouble(
      values: danmakuStrokeOptions,
      current: danmakuStrokeWidth,
      key: LocalCacheKey.strokeWidth,
    );
  }

  Future<void> toggleDanmakuBlock(int type) async {
    final List<dynamic> next = List<dynamic>.from(danmakuBlockTypes);
    if (next.contains(type)) {
      next.remove(type);
    } else {
      next.add(type);
    }
    danmakuBlockTypes.value = next;
    await GStrorage.localCache.put(LocalCacheKey.danmakuBlockType, next);
    _syncDanmakuGlobalCache();
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
    final int? value = await _showIntOptionDialog(
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
    final int? value = await _showIntOptionDialog(
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
    final int? value = await _showIntOptionDialog(
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

  Future<int?> _showIntOptionDialog({
    required String title,
    required List<int> options,
    required int current,
    required String Function(int) labelBuilder,
  }) {
    final BuildContext? context = Get.context;
    if (context == null) {
      return Future<int?>.value();
    }
    return showTvOptionDialog(
      context: context,
      title: title,
      options: options,
      current: current,
      labelBuilder: labelBuilder,
    );
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

  double _readDouble(String key, {required double defaultValue}) {
    final dynamic value =
        GStrorage.localCache.get(key, defaultValue: defaultValue);
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  Future<void> _cycleDouble({
    required List<double> values,
    required RxDouble current,
    required String key,
  }) async {
    final int index = _nearestDoubleIndex(values, current.value);
    current.value = values[(index + 1) % values.length];
    await GStrorage.localCache.put(key, current.value);
    _syncDanmakuGlobalCache();
  }

  void _syncDanmakuGlobalCache() {
    final GlobalDataCache cache = GlobalDataCache();
    cache.isOpenDanmu = danmakuEnabled.value;
    cache.blockTypes = List<dynamic>.from(danmakuBlockTypes);
    cache.showArea = danmakuShowArea.value;
    cache.danmakuDurationVal = danmakuDuration.value;
    cache.fontSizeVal = danmakuFontScale.value;
    cache.opacityVal = danmakuOpacity.value;
    cache.strokeWidth = danmakuStrokeWidth.value;
  }

  int _nearestDoubleIndex(List<double> values, double current) {
    int bestIndex = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < values.length; i++) {
      final double distance = (values[i] - current).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }
}
