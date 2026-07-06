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
              _SettingRow(
                title: '推荐页停留自动全屏',
                subtitle: controller.autoFullscreenEnabled.value
                    ? '开启后，推荐页停留一段时间会自动进入全屏播放'
                    : '关闭后，推荐页只会在按 OK 时播放',
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
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}
