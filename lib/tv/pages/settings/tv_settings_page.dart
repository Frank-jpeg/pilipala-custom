import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_settings_controller.dart';
import 'package:pilipala/tv/widgets/tv_focusable_button.dart';

class TvSettingsPage extends StatelessWidget {
  const TvSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TvSettingsController controller = Get.put(TvSettingsController());
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(56, 42, 56, 42),
        child: Obx(
          () => ListView(
            children: <Widget>[
              Row(
                children: <Widget>[
                  TvFocusableButton(
                    autofocus: true,
                    icon: Icons.arrow_back,
                    label: '返回',
                    onPressed: () => Get.back(),
                  ),
                  const SizedBox(width: 22),
                  Text(
                    'TV 设置',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              _WatchTimeProgressPanel(controller: controller),
              const SizedBox(height: 18),
              _VersionInfoRow(version: controller.appVersionLabel.value),
              const SizedBox(height: 18),
              _SettingRow(
                title: '推荐页自动预览/连播',
                subtitle: controller.recommendPreviewAutoplayEnabled.value
                    ? '开启后，推荐页焦点停留会自动播放预览'
                    : '关闭后，推荐页默认暂停，只显示封面，按 OK 才播放',
                value: controller.recommendPreviewAutoplayEnabled.value
                    ? '已开启'
                    : '已关闭',
                actions: <Widget>[
                  TvFocusableButton(
                    label: controller.recommendPreviewAutoplayEnabled.value
                        ? '关闭'
                        : '开启',
                    icon: controller.recommendPreviewAutoplayEnabled.value
                        ? Icons.toggle_on
                        : Icons.toggle_off,
                    onPressed: controller.toggleRecommendPreviewAutoplay,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '推荐页停留自动全屏',
                subtitle: controller.autoFullscreenEnabled.value
                    ? '仅在推荐页自动预览已开启且正在播放时生效'
                    : '关闭后，推荐页不会自动进入全屏',
                value: controller.autoFullscreenEnabled.value ? '已开启' : '已关闭',
                actions: <Widget>[
                  TvFocusableButton(
                    label: controller.autoFullscreenEnabled.value ? '关闭' : '开启',
                    icon: controller.autoFullscreenEnabled.value
                        ? Icons.toggle_on
                        : Icons.toggle_off,
                    onPressed: controller.toggleAutoFullscreen,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '自动全屏等待时间',
                subtitle: '用于推荐页停留自动全屏，范围 5 到 60 秒',
                value: '${controller.autoFullscreenDelaySeconds.value} 秒',
                actions: <Widget>[
                  TvFocusableButton(
                    label: '-5 秒',
                    icon: Icons.remove,
                    onPressed: controller.decreaseDelay,
                  ),
                  const SizedBox(width: 14),
                  TvFocusableButton(
                    label: '+5 秒',
                    icon: Icons.add,
                    onPressed: controller.increaseDelay,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '播放器弹幕',
                subtitle: controller.danmakuEnabled.value
                    ? '播放视频时默认显示弹幕'
                    : '播放视频时默认隐藏弹幕',
                value: controller.danmakuEnabled.value ? '已开启' : '已关闭',
                actions: <Widget>[
                  TvFocusableButton(
                    label: controller.danmakuEnabled.value ? '关闭' : '开启',
                    icon: controller.danmakuEnabled.value
                        ? Icons.toggle_on
                        : Icons.toggle_off,
                    onPressed: controller.toggleDanmaku,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const _SectionTitle(title: '弹幕设置'),
              const SizedBox(height: 18),
              _SettingRow(
                title: '显示区域',
                subtitle: '控制弹幕覆盖屏幕的高度范围',
                value: controller.danmakuAreaLabel,
                actions: <Widget>[
                  TvFocusableButton(
                    label: '切换',
                    icon: Icons.crop_free_rounded,
                    onPressed: controller.cycleDanmakuArea,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '弹幕速度',
                subtitle: '数字越小滚动越快，数字越大滚动越慢',
                value: controller.danmakuDurationLabel,
                actions: <Widget>[
                  TvFocusableButton(
                    label: '切换',
                    icon: Icons.timer_rounded,
                    onPressed: controller.cycleDanmakuDuration,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '字体大小',
                subtitle: '调整弹幕文字相对默认大小的比例',
                value: controller.danmakuFontScaleLabel,
                actions: <Widget>[
                  TvFocusableButton(
                    label: '切换',
                    icon: Icons.format_size_rounded,
                    onPressed: controller.cycleDanmakuFontScale,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '不透明度',
                subtitle: '控制弹幕文字透明度',
                value: controller.danmakuOpacityLabel,
                actions: <Widget>[
                  TvFocusableButton(
                    label: '切换',
                    icon: Icons.opacity_rounded,
                    onPressed: controller.cycleDanmakuOpacity,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '描边粗细',
                subtitle: '控制弹幕文字描边宽度',
                value: controller.danmakuStrokeLabel,
                actions: <Widget>[
                  TvFocusableButton(
                    label: '切换',
                    icon: Icons.border_color_rounded,
                    onPressed: controller.cycleDanmakuStroke,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '按类型屏蔽',
                subtitle: '开关顶部、滚动、底部和彩色弹幕屏蔽',
                value: '自定义',
                actions: <Widget>[
                  TvFocusableButton(
                    label: _danmakuBlockLabel(controller, 5, '顶部'),
                    icon: Icons.vertical_align_top_rounded,
                    onPressed: () => controller.toggleDanmakuBlock(5),
                  ),
                  TvFocusableButton(
                    label: _danmakuBlockLabel(controller, 2, '滚动'),
                    icon: Icons.subject_rounded,
                    onPressed: () => controller.toggleDanmakuBlock(2),
                  ),
                  TvFocusableButton(
                    label: _danmakuBlockLabel(controller, 4, '底部'),
                    icon: Icons.vertical_align_bottom_rounded,
                    onPressed: () => controller.toggleDanmakuBlock(4),
                  ),
                  TvFocusableButton(
                    label: _danmakuBlockLabel(controller, 6, '彩色'),
                    icon: Icons.palette_rounded,
                    onPressed: () => controller.toggleDanmakuBlock(6),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const _SectionTitle(title: '防沉迷'),
              const SizedBox(height: 18),
              _SettingRow(
                title: 'TV 防沉迷',
                subtitle: controller.antiAddiction.enabled.value
                    ? '已开启，观看会按单次和每日规则计时'
                    : '默认关闭，不影响当前观看体验',
                value: controller.antiAddictionStatus,
                actions: <Widget>[
                  TvFocusableButton(
                    label: controller.antiAddiction.enabled.value ? '关闭' : '开启',
                    icon: controller.antiAddiction.enabled.value
                        ? Icons.toggle_on
                        : Icons.toggle_off,
                    onPressed: () => controller.toggleAntiAddiction(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '单次观看时长',
                subtitle: '到点后进入强制休息锁页',
                value:
                    '${controller.antiAddiction.sessionLimitMinutes.value} 分钟',
                actions: <Widget>[
                  TvFocusableButton(
                    label: '选择',
                    icon: Icons.timer_outlined,
                    onPressed: () => controller.selectSessionLimit(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '强制休息时长',
                subtitle: '休息倒计时结束后自动解锁',
                value: '${controller.antiAddiction.restMinutes.value} 分钟',
                actions: <Widget>[
                  TvFocusableButton(
                    label: '选择',
                    icon: Icons.self_improvement_outlined,
                    onPressed: () => controller.selectRestMinutes(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '每日总时长',
                subtitle: '关闭时只按单次观看和强制休息计时',
                value: controller.dailyLimitLabel,
                actions: <Widget>[
                  TvFocusableButton(
                    label: '选择',
                    icon: Icons.today_outlined,
                    onPressed: () => controller.selectDailyLimit(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '解锁方式',
                subtitle: controller.unlockUsesMath
                    ? '答题解锁时始终保留家长 PIN 备用入口'
                    : '使用 4 位家长 PIN 验证后解锁',
                value: controller.unlockModeLabel,
                actions: <Widget>[
                  TvFocusableButton(
                    label: '选择',
                    icon: Icons.quiz_outlined,
                    onPressed: () => controller.selectUnlockMode(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingRow(
                title: '家长 PIN',
                subtitle: '用于关闭/修改防沉迷，以及锁页临时解锁',
                value: controller.pinStatus,
                actions: <Widget>[
                  TvFocusableButton(
                    label: controller.antiAddiction.hasPin ? '修改' : '设置',
                    icon: Icons.pin_outlined,
                    onPressed: () => controller.setOrChangePin(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionInfoRow extends StatelessWidget {
  const _VersionInfoRow({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.white70,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '当前版本',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            version,
            style: const TextStyle(
              color: Color(0xFFFF7BAC),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchTimeProgressPanel extends StatelessWidget {
  const _WatchTimeProgressPanel({required this.controller});

  static const Color _activeColor = Color(0xFFFF7BAC);
  static const Color _warningColor = Color(0xFFFFB04A);
  static const Color _exhaustedColor = Color(0xFFFF5B67);
  static const Color _disabledColor = Color(0xFF667085);

  final TvSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final bool enabled = controller.antiAddiction.enabled.value;
    final bool hasDailyLimit = controller.antiAddiction.hasDailyLimit;
    final double sessionProgress =
        controller.antiAddiction.sessionRemainingProgress;
    final double dailyProgress =
        controller.antiAddiction.dailyRemainingProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '观看时间',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                enabled ? '防沉迷已开启' : '防沉迷未开启',
                style: TextStyle(
                  color: enabled ? _activeColor : Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _WatchTimeProgressRow(
            label: '本次剩余观看时间',
            value: enabled
                ? _remainingLabel(
                    remainingSeconds:
                        controller.antiAddiction.sessionRemainingSeconds,
                    limitSeconds: controller.antiAddiction.sessionLimitSeconds,
                    exhaustedText: '本次额度已用完',
                  )
                : '防沉迷未开启',
            progress: enabled ? sessionProgress : 0,
            color: enabled ? _progressColor(sessionProgress) : _disabledColor,
          ),
          const SizedBox(height: 18),
          _WatchTimeProgressRow(
            label: hasDailyLimit ? '今日剩余观看时间' : '今日已观看',
            value: !enabled
                ? '防沉迷未开启'
                : hasDailyLimit
                    ? _remainingLabel(
                        remainingSeconds:
                            controller.antiAddiction.dailyRemainingSeconds,
                        limitSeconds:
                            controller.antiAddiction.dailyLimitSeconds,
                        exhaustedText: '今日额度已用完',
                      )
                    : '今日已观看 ${_formatWatchTime(controller.antiAddiction.dailyUsedSeconds.value)}',
            progress: enabled && hasDailyLimit ? dailyProgress : 0,
            color: enabled && hasDailyLimit
                ? _progressColor(dailyProgress)
                : _disabledColor,
          ),
        ],
      ),
    );
  }

  static Color _progressColor(double progress) {
    if (progress <= 0) {
      return _exhaustedColor;
    }
    if (progress <= 0.2) {
      return _warningColor;
    }
    return _activeColor;
  }

  static String _remainingLabel({
    required int remainingSeconds,
    required int limitSeconds,
    required String exhaustedText,
  }) {
    if (remainingSeconds <= 0) {
      return exhaustedText;
    }
    return '剩余 ${_formatWatchTime(remainingSeconds)} / ${_formatWatchTime(limitSeconds)}';
  }
}

class _WatchTimeProgressRow extends StatelessWidget {
  const _WatchTimeProgressRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              color: color,
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatWatchTime(int totalSeconds) {
  final int seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  final int remainderSeconds = seconds % 60;
  if (hours > 0) {
    return minutes > 0 ? '$hours小时$minutes分钟' : '$hours小时';
  }
  if (minutes > 0) {
    return remainderSeconds > 0 ? '$minutes分$remainderSeconds秒' : '$minutes分钟';
  }
  return '$remainderSeconds秒';
}

String _danmakuBlockLabel(
  TvSettingsController controller,
  int type,
  String label,
) {
  controller.danmakuBlockTypes.length;
  return controller.isDanmakuBlockEnabled(type) ? '$label：开' : '$label：关';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 110,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFFF7BAC),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Flexible(
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: actions,
            ),
          ),
        ],
      ),
    );
  }
}
