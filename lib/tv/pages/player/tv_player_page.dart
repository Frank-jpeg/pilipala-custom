import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pilipala/plugin/pl_player/view.dart';
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
          canPop: !controller.isRecommendSource,
          onPopInvoked: (bool didPop) {
            if (!didPop && controller.isRecommendSource) {
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
                  PLVideoPlayer(controller: controller.player),
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
                                  ? 'OK 播放/暂停  左右 快进快退  上下 切换推荐  返回 退出'
                                  : 'OK 播放/暂停  左右 快进快退  上下 音量  返回 退出',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exitPlayer(TvPlayerController controller) {
    if (controller.isRecommendSource) {
      Get.offAllNamed(TvRoutes.shell);
      return;
    }
    Get.back();
  }
}
