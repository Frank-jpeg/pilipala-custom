import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/short_video/item.dart';
import 'package:pilipala/pages/home/controller.dart';

import 'controller.dart';

class ShortVideoPage extends StatefulWidget {
  const ShortVideoPage({super.key});

  @override
  State<ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<ShortVideoPage>
    with AutomaticKeepAliveClientMixin {
  final ShortVideoController _controller = Get.put(ShortVideoController());
  late final HomeController _homeController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _homeController = Get.find<HomeController>();
    _homeController.tabController.addListener(_syncTabActive);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTabActive());
  }

  void _syncTabActive() {
    final int index = _homeController.tabController.index;
    if (index < 0 || index >= _homeController.tabs.length) {
      _controller.setTabActive(false);
      return;
    }
    final bool active =
        _homeController.tabs[index]['type']?.toString() == 'TabType.story';
    _controller.setTabActive(active);
  }

  @override
  void dispose() {
    _homeController.tabController.removeListener(_syncTabActive);
    _controller.pauseCurrent();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.black,
      child: Obx(
        () {
          if (_controller.videoList.isEmpty) {
            return _EmptyState(controller: _controller);
          }
          return PageView.builder(
            controller: _controller.pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _controller.onPageChanged,
            itemCount: _controller.videoList.length,
            itemBuilder: (context, index) {
              return _ShortVideoItemView(
                item: _controller.videoList[index],
                index: index,
                controller: _controller,
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller});

  final ShortVideoController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Obx(
        () => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (controller.isLoading.value) ...[
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              const Text('正在寻找竖屏视频', style: TextStyle(color: Colors.white)),
            ] else ...[
              Icon(
                Icons.video_collection_outlined,
                size: 48,
                color: Colors.white.withOpacity(0.75),
              ),
              const SizedBox(height: 12),
              Text(
                controller.errorMessage.value.isEmpty
                    ? '暂无竖屏推荐'
                    : controller.errorMessage.value,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: controller.onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShortVideoItemView extends StatelessWidget {
  const _ShortVideoItemView({
    required this.item,
    required this.index,
    required this.controller,
  });

  final ShortVideoItem item;
  final int index;
  final ShortVideoController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
            child: _VideoSurface(
                item: item, index: index, controller: controller)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 88,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
          child: _VideoMeta(item: item),
        ),
        Positioned(
          right: 14,
          bottom: 34 + MediaQuery.of(context).padding.bottom,
          child: _ActionRail(item: item, controller: controller),
        ),
        Obx(
          () => controller.currentIndex.value == index &&
                  controller.isPreparing.value
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.item,
    required this.index,
    required this.controller,
  });

  final ShortVideoItem item;
  final int index;
  final ShortVideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => controller.plPlayerController.togglePlay(),
      child: Obx(
        () {
          final bool isCurrent = controller.currentIndex.value == index;
          final VideoController? videoController =
              controller.plPlayerController.videoController;
          if (isCurrent &&
              controller.activeBvid.value == item.bvid &&
              videoController != null) {
            return Video(
              controller: videoController,
              controls: NoVideoControls,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              return NetworkImgLayer(
                src: item.pic,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                type: 'emote',
                quality: 50,
              );
            },
          );
        },
      ),
    );
  }
}

class _VideoMeta extends StatelessWidget {
  const _VideoMeta({required this.item});

  final ShortVideoItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '@${item.owner?.name ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.item,
    required this.controller,
  });

  final ShortVideoItem item;
  final ShortVideoController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(
          () => _RoundIconButton(
            icon: controller.plPlayerController.playerStatus.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            onPressed: controller.plPlayerController.togglePlay,
          ),
        ),
        const SizedBox(height: 14),
        _RoundIconButton(
          icon: Icons.open_in_new_rounded,
          onPressed: () => controller.openDetail(item),
        ),
        const SizedBox(height: 14),
        _RoundIconButton(
          icon: Icons.refresh_rounded,
          onPressed: controller.onRefresh,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
