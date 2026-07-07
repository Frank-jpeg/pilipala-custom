import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pilipala/pages/danmaku/view.dart';
import 'package:pilipala/plugin/pl_player/view.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/controllers/tv_player_controller.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/utils/tv_formatters.dart';

class TvPlayerPage extends StatelessWidget {
  const TvPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TvPlayerController controller = Get.put(TvPlayerController());
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          final LogicalKeyboardKey key = event.logicalKey;
          if (key == LogicalKeyboardKey.contextMenu ||
              key == LogicalKeyboardKey.gameButtonStart ||
              key == LogicalKeyboardKey.gameButtonMode) {
            controller.toggleMenu();
            return KeyEventResult.handled;
          }
          if (controller.menuVisible.value) {
            if (key == LogicalKeyboardKey.arrowUp) {
              controller.moveMenuSelection(-1);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowDown) {
              controller.moveMenuSelection(1);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter) {
              controller.activateMenuSelection(
                exitPlayer: () => _exitPlayer(controller),
              );
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.escape ||
                key == LogicalKeyboardKey.goBack ||
                key == LogicalKeyboardKey.browserBack) {
              controller.closeMenu();
              return KeyEventResult.handled;
            }
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.mediaPlayPause) {
            controller.togglePlay();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            controller.seekRelative(-10);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            controller.seekRelative(10);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            if (controller.isRecommendSource) {
              controller.playPreviousRecommend();
              return KeyEventResult.handled;
            }
            controller.adjustVolume(0.05);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            if (controller.isRecommendSource) {
              controller.playNextRecommend();
              return KeyEventResult.handled;
            }
            controller.adjustVolume(-0.05);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.goBack ||
              key == LogicalKeyboardKey.browserBack) {
            _exitPlayer(controller);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) {
            if (!didPop) {
              if (controller.menuVisible.value) {
                controller.closeMenu();
                return;
              }
              _exitPlayer(controller);
            }
          },
          child: Obx(
            () => Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (controller.error.value != null)
                  Center(child: Text(controller.error.value!))
                else if (controller.loading.value)
                  const Center(child: CircularProgressIndicator())
                else
                  PLVideoPlayer(
                    controller: controller.player,
                    danmuWidget: Obx(
                      () => controller.currentCid.value <= 0
                          ? const SizedBox.shrink()
                          : PlDanmaku(
                              key: ValueKey<int>(controller.currentCid.value),
                              cid: controller.currentCid.value,
                              playerController: controller.player,
                            ),
                    ),
                  ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 20,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: controller.controlsVisible.value ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !controller.controlsVisible.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              controller.player.playerStatus.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Obx(
                              () => Text(
                                '${tvFormatDuration(controller.player.positionSeconds.value)} / ${tvFormatDuration(controller.player.durationSeconds.value)}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const Spacer(),
                            Obx(
                              () => Text(
                                '音量 ${(controller.volume.value * 100).round()}%',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Text(
                              controller.isRecommendSource
                                  ? 'OK 播放/暂停  菜单 播放设置  左右 快进快退  上下 切换推荐  返回首页'
                                  : 'OK 播放/暂停  菜单 播放设置  左右 快进快退  上下 音量  返回${controller.isHomeSource ? '首页' : '详情'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (controller.thinProgressEnabled.value)
                  _TvThinProgressBar(controller: controller),
                if (controller.menuVisible.value)
                  _TvPlayerMenu(
                    controller: controller,
                    onExit: () => _exitPlayer(controller),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exitPlayer(TvPlayerController controller) {
    if ((controller.isRecommendSource || controller.isHomeSource) &&
        Get.isRegistered<TvHomeController>()) {
      Get.find<TvHomeController>().suppressNextShellExit();
    }
    if (controller.isRecommendSource) {
      Get.back();
      return;
    }
    if (controller.isHomeSource) {
      Get.back();
      return;
    }
    final String bvid = controller.bvid;
    if (bvid.isEmpty) {
      Get.back();
      return;
    }
    Get.offNamedUntil(
      '${TvRoutes.video}?bvid=$bvid&cid=${controller.cid}&aid=${controller.aid}',
      (route) => route.settings.name == TvRoutes.shell,
    );
  }
}

class _TvPlayerMenu extends StatefulWidget {
  const _TvPlayerMenu({
    required this.controller,
    required this.onExit,
  });

  final TvPlayerController controller;
  final VoidCallback onExit;

  @override
  State<_TvPlayerMenu> createState() => _TvPlayerMenuState();
}

class _TvPlayerMenuState extends State<_TvPlayerMenu> {
  final ScrollController _scrollController = ScrollController();
  Worker? _menuIndexWorker;

  @override
  void initState() {
    super.initState();
    _menuIndexWorker = ever<int>(
      widget.controller.menuIndex,
      (_) => _scrollToCurrentItem(),
    );
  }

  @override
  void dispose() {
    _menuIndexWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentItem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final double target = (widget.controller.menuIndex.value * 70.0) - 80.0;
      final double max = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        target.clamp(0.0, max),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final TvPlayerController controller = widget.controller;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.34),
        alignment: Alignment.centerRight,
        child: Container(
          width: 430,
          margin: const EdgeInsets.only(right: 44),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xEE111827),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '播放设置',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 0,
                          icon: controller.player.isOpenDanmu.value
                              ? Icons.subtitles_rounded
                              : Icons.subtitles_off_rounded,
                          label: controller.player.isOpenDanmu.value
                              ? '弹幕：开'
                              : '弹幕：关',
                          onPressed: controller.toggleDanmaku,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 1,
                          icon: Icons.speed_rounded,
                          label:
                              '倍速：${controller.playbackSpeed.value.toStringAsFixed(controller.playbackSpeed.value % 1 == 0 ? 0 : 2)}x',
                          onPressed: controller.cyclePlaybackSpeed,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 2,
                          icon: controller.thinProgressEnabled.value
                              ? Icons.linear_scale_rounded
                              : Icons.horizontal_rule_rounded,
                          label: controller.thinProgressEnabled.value
                              ? '细进度条：开'
                              : '细进度条：关',
                          onPressed: controller.toggleThinProgress,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _TvPlayerMenuSectionTitle(label: '弹幕设置'),
                      const SizedBox(height: 10),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 3,
                          icon: Icons.crop_free_rounded,
                          label:
                              '显示区域：${_danmakuLabel(controller, controller.danmakuAreaLabel)}',
                          onPressed: controller.cycleDanmakuArea,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 4,
                          icon: Icons.timer_rounded,
                          label:
                              '弹幕速度：${_danmakuLabel(controller, controller.danmakuDurationLabel)}',
                          onPressed: controller.cycleDanmakuDuration,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 5,
                          icon: Icons.format_size_rounded,
                          label:
                              '字体大小：${_danmakuLabel(controller, controller.danmakuFontScaleLabel)}',
                          onPressed: controller.cycleDanmakuFontScale,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 6,
                          icon: Icons.opacity_rounded,
                          label:
                              '不透明度：${_danmakuLabel(controller, controller.danmakuOpacityLabel)}',
                          onPressed: controller.cycleDanmakuOpacity,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 7,
                          icon: Icons.border_color_rounded,
                          label:
                              '描边粗细：${_danmakuLabel(controller, controller.danmakuStrokeLabel)}',
                          onPressed: controller.cycleDanmakuStroke,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _TvPlayerMenuSectionTitle(label: '按类型屏蔽'),
                      const SizedBox(height: 10),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 8,
                          icon: Icons.vertical_align_top_rounded,
                          label: _danmakuBlockLabel(controller, 5, '屏蔽顶部'),
                          onPressed: () => controller.toggleDanmakuBlock(5),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 9,
                          icon: Icons.subject_rounded,
                          label: _danmakuBlockLabel(controller, 2, '屏蔽滚动'),
                          onPressed: () => controller.toggleDanmakuBlock(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 10,
                          icon: Icons.vertical_align_bottom_rounded,
                          label: _danmakuBlockLabel(controller, 4, '屏蔽底部'),
                          onPressed: () => controller.toggleDanmakuBlock(4),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 11,
                          icon: Icons.palette_rounded,
                          label: _danmakuBlockLabel(controller, 6, '屏蔽彩色'),
                          onPressed: () => controller.toggleDanmakuBlock(6),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 12,
                          icon: Icons.close_rounded,
                          label: '关闭菜单',
                          onPressed: controller.closeMenu,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _TvPlayerMenuItem(
                          focused: controller.menuIndex.value == 13,
                          icon: Icons.exit_to_app_rounded,
                          label: '退出播放',
                          onPressed: widget.onExit,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _danmakuBlockLabel(
  TvPlayerController controller,
  int type,
  String label,
) {
  controller.danmakuOptionVersion.value;
  return controller.isDanmakuBlockEnabled(type) ? '$label：开' : '$label：关';
}

String _danmakuLabel(TvPlayerController controller, String value) {
  controller.danmakuOptionVersion.value;
  return value;
}

class _TvPlayerMenuSectionTitle extends StatelessWidget {
  const _TvPlayerMenuSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TvThinProgressBar extends StatelessWidget {
  const _TvThinProgressBar({required this.controller});

  final TvPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: SizedBox(
          height: 3,
          child: Obx(() {
            final int durationMs =
                controller.player.duration.value.inMilliseconds;
            final int positionMs =
                controller.player.position.value.inMilliseconds;
            final double progress =
                durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Container(color: Colors.white.withOpacity(0.16)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: const Color(0xFFFF5AA8)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _TvPlayerMenuItem extends StatelessWidget {
  const _TvPlayerMenuItem({
    required this.focused,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool focused;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: focused ? colorScheme.primary : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? Colors.white : Colors.white12,
          width: focused ? 2 : 1,
        ),
        boxShadow: focused
            ? <BoxShadow>[
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: focused ? Colors.white : colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: focused ? Colors.white : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
