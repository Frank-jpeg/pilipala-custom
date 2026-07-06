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

enum _HomeFocusArea { quickActions, tabs, content }

enum _QuickActionType {
  search,
  history,
  favorite,
  watchLater,
  account,
  settings
}

class TvShellPage extends StatefulWidget {
  const TvShellPage({super.key});

  @override
  State<TvShellPage> createState() => _TvShellPageState();
}

class _TvShellPageState extends State<TvShellPage> {
  static const int _navItemCount = 5;

  final TvHomeController _controller = Get.put(TvHomeController());
  final FocusNode _homeFocusNode = FocusNode();
  final List<FocusNode> _navFocusNodes =
      List<FocusNode>.generate(_navItemCount, (_) => FocusNode());

  int _selectedNavIndex = 0;
  int _quickActionIndex = 0;
  int _tabIndex = 0;
  _HomeFocusArea _focusArea = _HomeFocusArea.content;
  bool _homeFocused = true;

  @override
  Widget build(BuildContext context) {
    final TvSessionController session = Get.find<TvSessionController>();
    return Scaffold(
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
                      _focusArea = _HomeFocusArea.content;
                    });
                    unawaited(_switchHomeTab(TvHomeTab.recommend));
                  },
                ),
                TvNavItem(
                  label: '搜索',
                  icon: Icons.search,
                  onTap: () => unawaited(
                    _openNamed(TvRoutes.search, returnFocusIndex: 1),
                  ),
                ),
                TvNavItem(
                  label: '媒体库',
                  icon: Icons.video_library_outlined,
                  onTap: () => unawaited(
                    _openNamed(TvRoutes.library, returnFocusIndex: 2),
                  ),
                ),
                TvNavItem(
                  label: session.isLogin.value ? '我的' : '登录',
                  icon: Icons.account_circle_outlined,
                  onTap: () => unawaited(
                    _openNamed(TvRoutes.login, returnFocusIndex: 3),
                  ),
                ),
                TvNavItem(
                  label: '设置',
                  icon: Icons.settings_outlined,
                  onTap: () => unawaited(
                    _openNamed(TvRoutes.settings, returnFocusIndex: 4),
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
                    focusArea: _homeFocused ? _focusArea : null,
                    quickActionIndex: _quickActionIndex,
                    tabIndex: _tabIndex,
                    onQuickActionTap: _activateQuickAction,
                    onTabTap: (TvHomeTab tab) {
                      setState(() {
                        _focusArea = _HomeFocusArea.content;
                      });
                      unawaited(_switchHomeTab(tab));
                    },
                    onSelectContent: (int index) {
                      setState(() {
                        _focusArea = _HomeFocusArea.content;
                      });
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
    );
  }

  KeyEventResult _handleHomeKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    switch (_focusArea) {
      case _HomeFocusArea.quickActions:
        return _handleQuickActionKey(event.logicalKey);
      case _HomeFocusArea.tabs:
        return _handleTabKey(event.logicalKey);
      case _HomeFocusArea.content:
        return _handleContentKey(event.logicalKey);
    }
  }

  KeyEventResult _handleQuickActionKey(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        if (_quickActionIndex > 0) {
          setState(() => _quickActionIndex--);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (_quickActionIndex < _QuickActionType.values.length - 1) {
          setState(() => _quickActionIndex++);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        setState(() => _focusArea = _HomeFocusArea.tabs);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _controller.markRecommendStageActive(false);
        _navFocusNodes[_selectedNavIndex].requestFocus();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        unawaited(
            _activateQuickAction(_QuickActionType.values[_quickActionIndex]));
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _handleTabKey(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        if (_tabIndex > 0) {
          setState(() => _tabIndex--);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (_tabIndex < TvHomeTab.values.length - 1) {
          setState(() => _tabIndex++);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _focusArea = _HomeFocusArea.quickActions);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        setState(() => _focusArea = _HomeFocusArea.content);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        setState(() => _focusArea = _HomeFocusArea.content);
        unawaited(_switchHomeTab(TvHomeTab.values[_tabIndex]));
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _handleContentKey(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        if (_controller.currentVideos.isNotEmpty &&
            _controller.selectedIndex.value > 0) {
          _controller.selectPrevious();
        } else {
          setState(() => _focusArea = _HomeFocusArea.tabs);
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

  Future<void> _activateQuickAction(_QuickActionType type) async {
    switch (type) {
      case _QuickActionType.search:
        await _openNamed(TvRoutes.search, returnFocusIndex: 1);
        return;
      case _QuickActionType.history:
        await _switchHomeTab(TvHomeTab.history);
        break;
      case _QuickActionType.favorite:
        await _switchHomeTab(TvHomeTab.favorite);
        break;
      case _QuickActionType.watchLater:
        await _switchHomeTab(TvHomeTab.watchLater);
        break;
      case _QuickActionType.account:
        await _openNamed(TvRoutes.login, returnFocusIndex: 3);
        return;
      case _QuickActionType.settings:
        await _openNamed(TvRoutes.settings, returnFocusIndex: 4);
        return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _focusArea = _HomeFocusArea.content;
    });
    _homeFocusNode.requestFocus();
  }

  Future<void> _switchHomeTab(TvHomeTab tab) async {
    await _controller.switchTab(tab);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedNavIndex = 0;
      _tabIndex = tab.index;
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
      _selectedNavIndex = 0;
    });
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
    required this.focusArea,
    required this.quickActionIndex,
    required this.tabIndex,
    required this.onQuickActionTap,
    required this.onTabTap,
    required this.onSelectContent,
  });

  final TvHomeController controller;
  final _HomeFocusArea? focusArea;
  final int quickActionIndex;
  final int tabIndex;
  final ValueChanged<_QuickActionType> onQuickActionTap;
  final ValueChanged<TvHomeTab> onTabTap;
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
          padding: const EdgeInsets.fromLTRB(30, 24, 30, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '首页',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              _QuickActionBar(
                session: Get.find<TvSessionController>(),
                focused: focusArea == _HomeFocusArea.quickActions,
                selectedIndex: quickActionIndex,
                onTap: onQuickActionTap,
              ),
              const SizedBox(height: 14),
              _HomeTabBar(
                focused: focusArea == _HomeFocusArea.tabs,
                selectedIndex: tabIndex,
                currentTab: controller.currentTab.value,
                onTap: onTabTap,
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
                  contentFocused: focusArea == _HomeFocusArea.content,
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

class _QuickActionBar extends StatelessWidget {
  const _QuickActionBar({
    required this.session,
    required this.focused,
    required this.selectedIndex,
    required this.onTap,
  });

  final TvSessionController session;
  final bool focused;
  final int selectedIndex;
  final ValueChanged<_QuickActionType> onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final List<_QuickActionData> actions = <_QuickActionData>[
          const _QuickActionData(
            type: _QuickActionType.search,
            label: '搜索',
            icon: Icons.search,
          ),
          const _QuickActionData(
            type: _QuickActionType.history,
            label: '历史',
            icon: Icons.history,
          ),
          const _QuickActionData(
            type: _QuickActionType.favorite,
            label: '收藏',
            icon: Icons.star_border,
          ),
          const _QuickActionData(
            type: _QuickActionType.watchLater,
            label: '稍后再看',
            icon: Icons.watch_later_outlined,
          ),
          _QuickActionData(
            type: _QuickActionType.account,
            label: session.isLogin.value ? '我的' : '登录',
            icon: Icons.account_circle_outlined,
          ),
          const _QuickActionData(
            type: _QuickActionType.settings,
            label: '设置',
            icon: Icons.settings_outlined,
          ),
        ];
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final _QuickActionData action = actions[index];
              return _PillButton(
                label: action.label,
                icon: action.icon,
                selected: focused && selectedIndex == index,
                active: false,
                onTap: () => onTap(action.type),
              );
            },
          ),
        );
      },
    );
  }
}

class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar({
    required this.focused,
    required this.selectedIndex,
    required this.currentTab,
    required this.onTap,
  });

  final bool focused;
  final int selectedIndex;
  final TvHomeTab currentTab;
  final ValueChanged<TvHomeTab> onTap;

  @override
  Widget build(BuildContext context) {
    const List<TvHomeTab> tabs = TvHomeTab.values;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final TvHomeTab tab = tabs[index];
          return _PillButton(
            label: _tabLabel(tab),
            selected: focused && selectedIndex == index,
            active: currentTab == tab,
            onTap: () => onTap(tab),
          );
        },
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.selected,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool highlighted = selected || active;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: highlighted ? Colors.white : const Color(0xAA111B2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withOpacity(0.14),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  color: highlighted ? const Color(0xFF0F172A) : Colors.white,
                  size: 19,
                ),
                const SizedBox(width: 8),
              ],
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
        ),
      ),
    );
  }
}

class _ContentStage extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
    final TvVideoCardData currentVideo = selectedVideo!;
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
                padding: EdgeInsets.zero,
                itemBuilder: (_, int index) => _HomeVideoRow(
                  data: videos[index],
                  selected: index == controller.selectedIndex.value,
                  contentFocused: contentFocused,
                  onTap: () => onSelectContent(index),
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

class _QuickActionData {
  const _QuickActionData({
    required this.type,
    required this.label,
    required this.icon,
  });

  final _QuickActionType type;
  final String label;
  final IconData icon;
}

String _tabLabel(TvHomeTab tab) {
  switch (tab) {
    case TvHomeTab.recommend:
      return '推荐';
    case TvHomeTab.history:
      return '历史';
    case TvHomeTab.favorite:
      return '收藏';
    case TvHomeTab.watchLater:
      return '稍后再看';
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
