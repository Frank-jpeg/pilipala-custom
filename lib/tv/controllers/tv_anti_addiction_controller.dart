import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pilipala/utils/storage.dart';

enum TvAntiAddictionLockReason {
  rest,
  dailyLimit,
}

class TvAntiAddictionController extends GetxController
    with WidgetsBindingObserver {
  static const int defaultSessionLimitMinutes = 30;
  static const int defaultRestMinutes = 20;
  static const int dailyUnlockExtraSeconds = 30 * 60;

  final RxBool enabled = false.obs;
  final RxInt sessionLimitMinutes = defaultSessionLimitMinutes.obs;
  final RxInt restMinutes = defaultRestMinutes.obs;
  final RxInt dailyLimitMinutes = 0.obs;
  final RxInt dailyUsedSeconds = 0.obs;
  final RxBool isLocked = false.obs;
  final Rxn<TvAntiAddictionLockReason> lockReason =
      Rxn<TvAntiAddictionLockReason>();
  final RxInt remainingLockSeconds = 0.obs;
  final RxInt sessionUsedSeconds = 0.obs;

  Timer? _watchTimer;
  Timer? _lockTimer;
  VoidCallback? _pausePlayback;
  VoidCallback? _resumePlayback;
  bool _isCounting = false;
  bool _pausedByLifecycle = false;
  int _lastTickMs = 0;

  String get pin =>
      GStrorage.setting.get(SettingBoxKey.tvAntiAddictionPin, defaultValue: '')
          as String;

  bool get hasPin => pin.length == 4;

  bool get isDailyLimited =>
      enabled.value &&
      dailyLimitMinutes.value > 0 &&
      dailyUsedSeconds.value >= dailyLimitMinutes.value * 60;

  int get sessionLimitSeconds => sessionLimitMinutes.value * 60;

  int get sessionRemainingSeconds =>
      (sessionLimitSeconds - sessionUsedSeconds.value)
          .clamp(0, sessionLimitSeconds)
          .toInt();

  double get sessionRemainingProgress => sessionLimitSeconds <= 0
      ? 0
      : (sessionRemainingSeconds / sessionLimitSeconds).clamp(0.0, 1.0);

  bool get hasDailyLimit => dailyLimitMinutes.value > 0;

  int get dailyLimitSeconds => dailyLimitMinutes.value * 60;

  int get dailyRemainingSeconds => !hasDailyLimit
      ? 0
      : (dailyLimitSeconds - dailyUsedSeconds.value)
          .clamp(0, dailyLimitSeconds)
          .toInt();

  double get dailyRemainingProgress => !hasDailyLimit || dailyLimitSeconds <= 0
      ? 0
      : (dailyRemainingSeconds / dailyLimitSeconds).clamp(0.0, 1.0);

  String get lockTitle {
    switch (lockReason.value) {
      case TvAntiAddictionLockReason.dailyLimit:
        return '今日观看已达上限';
      case TvAntiAddictionLockReason.rest:
      default:
        return '该休息一下啦';
    }
  }

  String get lockSubtitle {
    switch (lockReason.value) {
      case TvAntiAddictionLockReason.dailyLimit:
        return '输入家长 PIN 可追加 30 分钟，或明天再继续观看';
      case TvAntiAddictionLockReason.rest:
      default:
        return '休息倒计时结束后可以继续观看，也可输入家长 PIN 临时解锁';
    }
  }

  void load() {
    _rollDailyIfNeeded();
    enabled.value = GStrorage.setting.get(
      SettingBoxKey.tvAntiAddictionEnabled,
      defaultValue: false,
    ) as bool;
    sessionLimitMinutes.value = GStrorage.setting.get(
      SettingBoxKey.tvAntiAddictionSessionLimitMinutes,
      defaultValue: defaultSessionLimitMinutes,
    ) as int;
    restMinutes.value = GStrorage.setting.get(
      SettingBoxKey.tvAntiAddictionRestMinutes,
      defaultValue: defaultRestMinutes,
    ) as int;
    dailyLimitMinutes.value = GStrorage.setting.get(
      SettingBoxKey.tvAntiAddictionDailyLimitMinutes,
      defaultValue: 0,
    ) as int;
    dailyUsedSeconds.value = GStrorage.setting.get(
      SettingBoxKey.tvAntiAddictionDailyUsedSeconds,
      defaultValue: 0,
    ) as int;
    final int restUntil = GStrorage.setting.get(
      SettingBoxKey.tvAntiAddictionRestUntil,
      defaultValue: 0,
    ) as int;
    if (enabled.value && restUntil > DateTime.now().millisecondsSinceEpoch) {
      _lock(TvAntiAddictionLockReason.rest, restUntilMs: restUntil);
    }
  }

  Future<bool> setEnabled(bool value) async {
    if (value && !hasPin) {
      return false;
    }
    enabled.value = value;
    await GStrorage.setting.put(SettingBoxKey.tvAntiAddictionEnabled, value);
    if (!value) {
      unlock(resume: false);
      resetSession();
    }
    return true;
  }

  Future<void> setSessionLimitMinutes(int value) async {
    sessionLimitMinutes.value = value;
    await GStrorage.setting.put(
      SettingBoxKey.tvAntiAddictionSessionLimitMinutes,
      value,
    );
    resetSession();
  }

  Future<void> setRestMinutes(int value) async {
    restMinutes.value = value;
    await GStrorage.setting
        .put(SettingBoxKey.tvAntiAddictionRestMinutes, value);
  }

  Future<void> setDailyLimitMinutes(int value) async {
    _rollDailyIfNeeded();
    dailyLimitMinutes.value = value;
    await GStrorage.setting.put(
      SettingBoxKey.tvAntiAddictionDailyLimitMinutes,
      value,
    );
  }

  Future<void> setPin(String value) async {
    await GStrorage.setting.put(SettingBoxKey.tvAntiAddictionPin, value);
  }

  bool verifyPin(String value) => hasPin && value == pin;

  void startCounting({
    required VoidCallback pausePlayback,
    VoidCallback? resumePlayback,
  }) {
    if (!enabled.value || isLocked.value || _isCounting) {
      return;
    }
    _rollDailyIfNeeded();
    if (isDailyLimited) {
      _pausePlayback = pausePlayback;
      _resumePlayback = resumePlayback;
      _lock(TvAntiAddictionLockReason.dailyLimit);
      return;
    }
    _pausePlayback = pausePlayback;
    _resumePlayback = resumePlayback;
    _isCounting = true;
    _lastTickMs = DateTime.now().millisecondsSinceEpoch;
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void stopCounting({bool keepCallbacks = false}) {
    if (_isCounting) {
      _tick();
    }
    _isCounting = false;
    _watchTimer?.cancel();
    _watchTimer = null;
    if (!isLocked.value && !keepCallbacks) {
      _pausePlayback = null;
      _resumePlayback = null;
    }
  }

  void resetSession() {
    sessionUsedSeconds.value = 0;
  }

  void unlock({bool resume = true}) {
    _lockTimer?.cancel();
    _lockTimer = null;
    isLocked.value = false;
    lockReason.value = null;
    remainingLockSeconds.value = 0;
    sessionUsedSeconds.value = 0;
    GStrorage.setting.put(SettingBoxKey.tvAntiAddictionRestUntil, 0);
    if (resume) {
      _resumePlayback?.call();
    }
  }

  Future<void> unlockByPin() async {
    if (lockReason.value == TvAntiAddictionLockReason.dailyLimit) {
      final int next =
          (dailyUsedSeconds.value - dailyUnlockExtraSeconds).clamp(0, 1 << 30);
      dailyUsedSeconds.value = next;
      await GStrorage.setting.put(
        SettingBoxKey.tvAntiAddictionDailyUsedSeconds,
        next,
      );
    }
    unlock();
  }

  void _tick() {
    if (!_isCounting || !enabled.value || isLocked.value) {
      return;
    }
    _rollDailyIfNeeded();
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTickMs == 0) {
      _lastTickMs = now;
      return;
    }
    final int delta = ((now - _lastTickMs) / 1000).floor();
    if (delta <= 0) {
      return;
    }
    _lastTickMs = now;
    sessionUsedSeconds.value += delta;
    dailyUsedSeconds.value += delta;
    GStrorage.setting.put(
      SettingBoxKey.tvAntiAddictionDailyUsedSeconds,
      dailyUsedSeconds.value,
    );
    if (isDailyLimited) {
      _lock(TvAntiAddictionLockReason.dailyLimit);
      return;
    }
    if (sessionUsedSeconds.value >= sessionLimitMinutes.value * 60) {
      final int restUntil = now + restMinutes.value * 60 * 1000;
      _lock(TvAntiAddictionLockReason.rest, restUntilMs: restUntil);
    }
  }

  void _lock(
    TvAntiAddictionLockReason reason, {
    int? restUntilMs,
  }) {
    _isCounting = false;
    _watchTimer?.cancel();
    _watchTimer = null;
    isLocked.value = true;
    lockReason.value = reason;
    _pausePlayback?.call();
    if (reason == TvAntiAddictionLockReason.rest) {
      final int until = restUntilMs ??
          DateTime.now().millisecondsSinceEpoch + restMinutes.value * 60 * 1000;
      GStrorage.setting.put(SettingBoxKey.tvAntiAddictionRestUntil, until);
      _startLockCountdown(until);
      return;
    }
    remainingLockSeconds.value = 0;
    _lockTimer?.cancel();
    // 每日上限锁定期间挂一个定时器，跨天时自动解锁；否则会一直锁到 App 重启或家长 PIN。
    _lockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _rollDailyIfNeeded(),
    );
  }

  void _startLockCountdown(int untilMs) {
    _lockTimer?.cancel();
    void update() {
      final int leftMs = untilMs - DateTime.now().millisecondsSinceEpoch;
      final int leftSeconds = (leftMs / 1000).ceil();
      remainingLockSeconds.value = leftSeconds > 0 ? leftSeconds : 0;
      if (leftSeconds <= 0) {
        unlock();
      }
    }

    update();
    if (remainingLockSeconds.value > 0) {
      _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) => update());
    }
  }

  void _rollDailyIfNeeded() {
    final String today = _dateKey(DateTime.now());
    final String stored = GStrorage.setting.get(
      SettingBoxKey.tvAntiAddictionDailyDate,
      defaultValue: '',
    ) as String;
    if (stored == today) {
      return;
    }
    dailyUsedSeconds.value = 0;
    GStrorage.setting.put(SettingBoxKey.tvAntiAddictionDailyDate, today);
    GStrorage.setting.put(SettingBoxKey.tvAntiAddictionDailyUsedSeconds, 0);
    if (lockReason.value == TvAntiAddictionLockReason.dailyLimit) {
      unlock(resume: false);
    }
  }

  String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台且此前因切后台/瞬时失焦而停表，则继续计时（回调已保留）。
      if (_pausedByLifecycle) {
        _pausedByLifecycle = false;
        final VoidCallback? pause = _pausePlayback;
        if (pause != null && enabled.value && !isLocked.value) {
          startCounting(pausePlayback: pause, resumePlayback: _resumePlayback);
        }
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // 只在正计时时记标记，并保留回调，避免瞬时 inactive 后计时永久停止（防沉迷被绕过）。
      if (_isCounting) {
        _pausedByLifecycle = true;
        stopCounting(keepCallbacks: true);
      }
    }
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchTimer?.cancel();
    _lockTimer?.cancel();
    super.onClose();
  }
}
