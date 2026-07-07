import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/utils/tv_formatters.dart';
import 'package:pilipala/tv/widgets/tv_left_nav.dart';

class TvShellPage extends StatefulWidget {
  const TvShellPage({super.key});

  @override
  State<TvShellPage> createState() => _TvShellPageState();
}

class _TvShellPageState extends State<TvShellPage> {
  static const int _navItemCount = 8;

  final TvHomeController _controller = Get.put(TvHomeController());
  final FocusNode _homeFocusNode = FocusNode();
  final List<FocusNode> _navFocusNodes =
      List<FocusNode>.generate(_navItemCount, (_) => FocusNode());

  int _selectedNavIndex = 0;
  bool _homeFocused = true;

  @override
  Widget build(BuildContext context) {
    final TvSessionController session = Get.find<TvSessionController>();
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (!didPop) {
          _handleShellBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07101E),
        body: Row(
          children: <Widget>[
            Obx(
              () => TvLeftNav(
                selectedIndex: _selectedNavIndex,
                focusNodes: _navFocusNodes,
                items: <TvNavItem>[
                  TvNavItem(
                    label: '推荐',
                    icon: Icons.home_outlined,
                    onTap: () {
                      setState(() {
                        _selectedNavIndex = 0;
                      });
                      unawaited(_switchHomeTab(TvHomeTab.recommend));
                    },
                  ),
                  TvNavItem(
                    label: '历史',
                    icon: Icons.history,
                    onTap: () {
                      setState(() {
                        _selectedNavIndex = 1;
                      });
                      unawaited(_switchHomeTab(TvHomeTab.history));
                    },
                  ),
                  TvNavItem(
                    label: '收藏',
                    icon: Icons.star_border,
                    onTap: () {
                      setState(() {
                        _selectedNavIndex = 2;
                      });
                      unawaited(_switchHomeTab(TvHomeTab.favorite));
                    },
                  ),
                  TvNavItem(
                    label: '稍后再看',
                    icon: Icons.watch_later_outlined,
                    onTap: () {
                      setState(() {
                        _selectedNavIndex = 3;
                      });
                      unawaited(_switchHomeTab(TvHomeTab.watchLater));
                    },
                  ),
                  TvNavItem(
                    label: '搜索',
                    icon: Icons.search,
                    onTap: () => unawaited(
                      _openNamed(TvRoutes.search, returnFocusIndex: 4),
                    ),
                  ),
                  TvNavItem(
                    label: '媒体库',
                    icon: Icons.video_library_outlined,
                    onTap: () => unawaited(
                      _openNamed(TvRoutes.library, returnFocusIndex: 5),
                    ),
                  ),
                  TvNavItem(
                    label: session.isLogin.value ? '我的' : '登录',
                    icon: Icons.account_circle_outlined,
                    onTap: () => unawaited(
                      _openNamed(TvRoutes.login, returnFocusIndex: 6),
                    ),
                  ),
                  TvNavItem(
                    label: '设置',
                    icon: Icons.settings_outlined,
                    onTap: () => unawaited(
                      _openNamed(TvRoutes.settings, returnFocusIndex: 7),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Focus(
                focusNode: _homeFocusNode,
                autofocus: true,
                onFocusChange: (bool value) {
                  if (_homeFocused != value && mounted) {
                    setState(() {
                      _homeFocused = value;
                    });
                  }
                },
                onKeyEvent: _handleHomeKey,
                child: Obx(
                  () {
                    // _HomeStage 在子 widget build 内读取 currentTab / 当前列表 / selectedIndex 等 Rx，
                    // 这些读取不在本 Obx 闭包内。显式订阅它们：既避免 GetX “improper use” 抛错，
                    // 也让首页在切换 Tab / 数据刷新 / 选中项变化时正确重建。
                    _controller.currentVideos;
                    _controller.selectedVideo;
                    return _HomeStage(
                      controller: _controller,
                      contentFocused: _homeFocused,
                      onSelectContent: (int index) {
                        _homeFocusNode.requestFocus();
                        _controller.selectIndex(index);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleHomeKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    return _handleContentKey(event.logicalKey);
  }

  KeyEventResult _handleContentKey(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        if (_controller.currentVideos.isNotEmpty &&
            _controller.selectedIndex.value > 0) {
          _controller.selectPrevious();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (_controller.currentVideos.isNotEmpty &&
            _controller.selectedIndex.value <
                _controller.currentVideos.length - 1) {
          _controller.selectNext();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        unawaited(_openSelectedDetail());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _controller.markRecommendStageActive(false);
        _navFocusNodes[_selectedNavIndex].requestFocus();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        unawaited(_activateContent());
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  Future<void> _switchHomeTab(TvHomeTab tab) async {
    await _controller.switchTab(tab);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedNavIndex = tab.index;
    });
    _controller.markRecommendStageActive(true);
    _homeFocusNode.requestFocus();
  }

  Future<void> _activateContent() async {
    if (_controller.currentTabNeedsLogin) {
      await _openNamed(TvRoutes.login, returnFocusIndex: 3);
      return;
    }
    if (_controller.currentError != null) {
      await _controller.retryCurrentTab();
      return;
    }
    if (_controller.currentVideos.isEmpty) {
      return;
    }
    await _controller.playSelected();
    if (!mounted) {
      return;
    }
    _homeFocusNode.requestFocus();
  }

  Future<void> _openSelectedDetail() async {
    if (_controller.currentTabNeedsLogin ||
        _controller.currentError != null ||
        _controller.currentVideos.isEmpty) {
      return;
    }
    await _controller.openSelectedDetail();
    if (!mounted) {
      return;
    }
    _homeFocusNode.requestFocus();
  }

  Future<void> _openNamed(String route, {required int returnFocusIndex}) async {
    _controller.markRecommendStageActive(false);
    await Get.toNamed(route);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedNavIndex = _controller.currentTab.value.index;
    });
    _controller.markRecommendStageActive(true);
    _homeFocusNode.requestFocus();
  }

  void _handleShellBack() {
    if (_controller.consumeShellExitSuppression()) {
      _controller.markRecommendStageActive(true);
      _homeFocusNode.requestFocus();
      return;
    }
    unawaited(_confirmExit());
  }

  Future<void> _confirmExit() async {
    _controller.markRecommendStageActive(false);
    final bool? exit = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF10182A),
        title: const Text('退出 云视听pilipala？',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          '再确认一次，避免遥控器误按直接退到桌面。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (exit == true) {
      SystemNavigator.pop();
      return;
    }
    _controller.markRecommendStageActive(true);
    _homeFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _homeFocusNode.dispose();
    for (final FocusNode node in _navFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

class _HomeStage extends StatelessWidget {
  const _HomeStage({
    required this.controller,
    required this.contentFocused,
    required this.onSelectContent,
  });

  final TvHomeController controller;
  final bool contentFocused;
  final ValueChanged<int> onSelectContent;

  @override
  Widget build(BuildContext context) {
    final List<TvVideoCardData> videos = controller.currentVideos;
    final TvVideoCardData? selectedVideo = controller.selectedVideo;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _Backdrop(video: selectedVideo),
        _PreviewBackdrop(controller: controller, video: selectedVideo),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Color(0xF507101E),
                Color(0xC807101E),
                Color(0x3307101E),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                controller.currentTabLabel,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                controller.isRecommendTab
                    ? 'OK 全屏  右键详情  左键返回菜单'
                    : 'OK 播放  右键详情  左键返回菜单',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _ContentStage(
                  controller: controller,
                  videos: videos,
                  selectedVideo: selectedVideo,
                  contentFocused: contentFocused,
                  onSelectContent: onSelectContent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContentStage extends StatefulWidget {
  const _ContentStage({
    required this.controller,
    required this.videos,
    required this.selectedVideo,
    required this.contentFocused,
    required this.onSelectContent,
  });

  final TvHomeController controller;
  final List<TvVideoCardData> videos;
  final TvVideoCardData? selectedVideo;
  final bool contentFocused;
  final ValueChanged<int> onSelectContent;

  @override
  State<_ContentStage> createState() => _ContentStageState();
}

class _ContentStageState extends State<_ContentStage> {
  static const double _rowExtent = 112;
  final ScrollController _scrollController = ScrollController();
  late final Worker _selectedWorker;

  @override
  void initState() {
    super.initState();
    _selectedWorker = ever<int>(
      widget.controller.selectedIndex,
      _scrollToSelected,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected(widget.controller.selectedIndex.value);
    });
  }

  @override
  void didUpdateWidget(covariant _ContentStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected(widget.controller.selectedIndex.value);
    });
  }

  @override
  void dispose() {
    _selectedWorker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected(int index) {
    if (!_scrollController.hasClients || !mounted) {
      return;
    }
    final double target = (index * _rowExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TvHomeController controller = widget.controller;
    final List<TvVideoCardData> videos = widget.videos;
    final TvVideoCardData? selectedVideo = widget.selectedVideo;
    if (controller.currentTabNeedsLogin) {
      return _StateCard(
        icon: Icons.qr_code_2,
        title: '登录后可查看${controller.currentTabLabel}',
        subtitle: '按 OK 进入登录页  左键返回菜单',
      );
    }
    if (controller.currentLoading) {
      return const _LoadingStateCard();
    }
    if (controller.currentError != null) {
      return _StateCard(
        icon: Icons.error_outline,
        title: controller.currentError!,
        subtitle: '按 OK 重试  左键返回菜单',
      );
    }
    if (videos.isEmpty || selectedVideo == null) {
      return _StateCard(
        icon: Icons.inbox_outlined,
        title: controller.currentEmptyText,
        subtitle: controller.currentTab.value == TvHomeTab.favorite &&
                (controller.favoriteFolderTitle.value ?? '').isNotEmpty
            ? '当前读取收藏夹：${controller.favoriteFolderTitle.value}'
            : '左键返回菜单',
      );
    }
    final TvVideoCardData currentVideo = selectedVideo;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double listWidth =
            (constraints.maxWidth * 0.45).clamp(340.0, 470.0);
        final double gap = constraints.maxWidth < 760 ? 24 : 38;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: listWidth,
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemBuilder: (_, int index) => _HomeVideoRow(
                  data: videos[index],
                  selected: index == controller.selectedIndex.value,
                  contentFocused: widget.contentFocused,
                  onTap: () => widget.onSelectContent(index),
                ),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: videos.length,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _HeroInfo(
                controller: controller,
                video: currentVideo,
                autoFullscreenArmed: controller.autoFullscreenArmed.value,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PreviewBackdrop extends StatelessWidget {
  const _PreviewBackdrop({
    required this.controller,
    required this.video,
  });

  final TvHomeController controller;
  final TvVideoCardData? video;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final VideoController? videoController =
            controller.previewVideoController;
        final bool canShow = controller.isRecommendTab &&
            controller.previewReady.value &&
            controller.previewBvid.value == video?.bvid &&
            videoController != null;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: canShow ? 1 : 0,
          child: canShow
              ? Video(
                  key: ValueKey<String>('preview-${video?.bvid ?? 'none'}'),
                  controller: videoController,
                  controls: NoVideoControls,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  pauseUponEnteringBackgroundMode: true,
                  resumeUponEnteringForegroundMode: true,
                )
              : const SizedBox.expand(),
        );
      },
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.video});

  final TvVideoCardData? video;

  @override
  Widget build(BuildContext context) {
    if (video == null || video!.cover.isEmpty) {
      return Container(color: const Color(0xFF07101E));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: CachedNetworkImage(
        key: ValueKey<String>(video!.cover),
        imageUrl: video!.cover,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(color: const Color(0xFF07101E)),
      ),
    );
  }
}

class _HomeVideoRow extends StatelessWidget {
  const _HomeVideoRow({
    required this.data,
    required this.selected,
    required this.contentFocused,
    required this.onTap,
  });

  final TvVideoCardData data;
  final bool selected;
  final bool contentFocused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool emphasize = selected && contentFocused;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      height: 124,
      transform: Matrix4.identity()..scale(emphasize ? 1.02 : 1.0),
      decoration: BoxDecoration(
        color: selected ? const Color(0xDD243048) : const Color(0xAA111B2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: selected ? 2.2 : 1,
        ),
        boxShadow: emphasize
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.white.withOpacity(0.18),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 184,
              height: 124,
              child: CachedNetworkImage(
                imageUrl: data.cover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1A2438),
                  alignment: Alignment.center,
                  child: const Icon(Icons.movie_outlined, size: 34),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if ((data.subtitle ?? '').isNotEmpty) ...<Widget>[
                      Text(
                        data.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      data.title,
                      maxLines: selected ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: selected ? 19 : 17,
                        height: 1.2,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${data.ownerName}  ${tvFormatDuration(data.duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    if (selected) ...<Widget>[
                      const SizedBox(height: 8),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _InlineHint(label: 'OK 全屏观看'),
                          _InlineHint(label: '右键详情'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.controller,
    required this.video,
    required this.autoFullscreenArmed,
  });

  final TvHomeController controller;
  final TvVideoCardData video;
  final bool autoFullscreenArmed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 320;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(),
              _HeroStatus(controller: controller, video: video),
              const SizedBox(height: 16),
              Text(
                video.title,
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.displaySmall)
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${video.ownerName}  ${tvFormatDuration(video.duration)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((video.desc ?? '').isNotEmpty) ...<Widget>[
                SizedBox(height: compact ? 16 : 20),
                Text(
                  video.desc!,
                  maxLines: compact ? 4 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: compact ? 14 : 16,
                    height: 1.5,
                  ),
                ),
              ],
              SizedBox(height: compact ? 20 : 26),
              Wrap(
                spacing: compact ? 10 : 14,
                runSpacing: 12,
                children: <Widget>[
                  _HintChip(
                    icon: Icons.play_arrow_rounded,
                    label: controller.isRecommendTab
                        ? (autoFullscreenArmed ? '即将全屏' : 'OK 全屏')
                        : 'OK 播放',
                    highlighted:
                        controller.isRecommendTab && autoFullscreenArmed,
                    compact: compact,
                  ),
                  _HintChip(
                    icon: Icons.info_outline,
                    label: '右键详情',
                    compact: compact,
                  ),
                  _HintChip(
                    icon: Icons.keyboard_return_rounded,
                    label: '左键返回菜单',
                    compact: compact,
                  ),
                ],
              ),
              const SizedBox(height: 34),
            ],
          ),
        );
      },
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({
    required this.controller,
    required this.video,
  });

  final TvHomeController controller;
  final TvVideoCardData video;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        if (!controller.isRecommendTab) {
          return _PreviewStatus(
            icon: _tabIcon(controller.currentTab.value),
            label: controller.currentTabLabel,
            highlighted: true,
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: controller.previewPreparing.value
              ? const _PreviewStatus(
                  key: ValueKey<String>('preview-loading'),
                  icon: Icons.play_circle_outline,
                  label: '正在加载首页预览',
                  highlighted: true,
                )
              : controller.previewReady.value &&
                      controller.previewBvid.value == video.bvid
                  ? const _PreviewStatus(
                      key: ValueKey<String>('preview-playing'),
                      icon: Icons.play_arrow_rounded,
                      label: '正在自动播放',
                      highlighted: true,
                    )
                  : const _PreviewStatus(
                      key: ValueKey<String>('preview-cover'),
                      icon: Icons.image_outlined,
                      label: '封面预览',
                    ),
        );
      },
    );
  }
}

class _PreviewStatus extends StatelessWidget {
  const _PreviewStatus({
    required this.icon,
    required this.label,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted ? Colors.white : const Color(0x99111B2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: highlighted ? const Color(0xFF0F172A) : Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: highlighted ? const Color(0xFF0F172A) : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 9 : 10,
      ),
      decoration: BoxDecoration(
        color: highlighted ? Colors.white : const Color(0xAA111B2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: highlighted ? const Color(0xFF0F172A) : Colors.white,
            size: compact ? 18 : 20,
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              color: highlighted ? const Color(0xFF0F172A) : Colors.white,
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: Colors.white70),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingStateCard extends StatelessWidget {
  const _LoadingStateCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 18),
          Text(
            '正在加载频道内容',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _tabIcon(TvHomeTab tab) {
  switch (tab) {
    case TvHomeTab.recommend:
      return Icons.home_outlined;
    case TvHomeTab.history:
      return Icons.history;
    case TvHomeTab.favorite:
      return Icons.star_border;
    case TvHomeTab.watchLater:
      return Icons.watch_later_outlined;
  }
}
