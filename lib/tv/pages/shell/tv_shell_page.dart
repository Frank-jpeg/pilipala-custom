import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/utils/tv_formatters.dart';
import 'package:pilipala/tv/widgets/tv_async_state.dart';
import 'package:pilipala/tv/widgets/tv_left_nav.dart';

class TvShellPage extends StatefulWidget {
  const TvShellPage({super.key});

  @override
  State<TvShellPage> createState() => _TvShellPageState();
}

class _TvShellPageState extends State<TvShellPage> {
  final TvHomeController _controller = Get.put(TvHomeController());
  final FocusNode _recommendFocusNode = FocusNode();
  final List<FocusNode> _navFocusNodes =
      List<FocusNode>.generate(5, (_) => FocusNode());
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final TvSessionController session = Get.find<TvSessionController>();
    return Scaffold(
      backgroundColor: const Color(0xFF07101E),
      body: Row(
        children: <Widget>[
          Obx(
            () => TvLeftNav(
              selectedIndex: _selectedIndex,
              focusNodes: _navFocusNodes,
              items: <TvNavItem>[
                TvNavItem(
                  label: '推荐',
                  icon: Icons.home_outlined,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                    _controller.scheduleAutoFullscreen();
                    _recommendFocusNode.requestFocus();
                  },
                ),
                TvNavItem(
                  label: '搜索',
                  icon: Icons.search,
                  onTap: () {
                    _controller.cancelAutoFullscreen();
                    Get.toNamed(TvRoutes.search)?.whenComplete(
                      _controller.scheduleAutoFullscreen,
                    );
                  },
                ),
                TvNavItem(
                  label: '媒体库',
                  icon: Icons.video_library_outlined,
                  onTap: () {
                    _controller.cancelAutoFullscreen();
                    Get.toNamed(TvRoutes.library)?.whenComplete(
                      _controller.scheduleAutoFullscreen,
                    );
                  },
                ),
                TvNavItem(
                  label: session.isLogin.value ? '我的' : '登录',
                  icon: Icons.account_circle_outlined,
                  onTap: () {
                    _controller.cancelAutoFullscreen();
                    Get.toNamed(TvRoutes.login)?.whenComplete(
                      _controller.scheduleAutoFullscreen,
                    );
                  },
                ),
                TvNavItem(
                  label: '设置',
                  icon: Icons.settings_outlined,
                  onTap: () {
                    _controller.cancelAutoFullscreen();
                    Get.toNamed(TvRoutes.settings)?.whenComplete(
                      _controller.scheduleAutoFullscreen,
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Focus(
              focusNode: _recommendFocusNode,
              autofocus: true,
              onKeyEvent: _handleKey,
              child: Obx(
                () => TvAsyncState(
                  loading: _controller.loading.value,
                  error: _controller.error.value,
                  empty: _controller.items.isEmpty,
                  emptyText: '暂无推荐内容',
                  child: _RecommendStage(
                    videos: _controller.videos,
                    selectedIndex: _controller.selectedIndex.value,
                    autoFullscreenArmed: _controller.autoFullscreenArmed.value,
                    onSelect: _controller.selectIndex,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _controller.selectNext();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _controller.selectPrevious();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _controller.openSelectedDetail();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _navFocusNodes[_selectedIndex.clamp(0, _navFocusNodes.length - 1)]
            .requestFocus();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _controller.playSelected();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    _recommendFocusNode.dispose();
    for (final FocusNode node in _navFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

class _RecommendStage extends StatelessWidget {
  const _RecommendStage({
    required this.videos,
    required this.selectedIndex,
    required this.autoFullscreenArmed,
    required this.onSelect,
  });

  final List<TvVideoCardData> videos;
  final int selectedIndex;
  final bool autoFullscreenArmed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final TvVideoCardData selected =
        videos[selectedIndex.clamp(0, videos.length - 1)];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _Backdrop(video: selected),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Color(0xF507101E),
                Color(0xB807101E),
                Color(0x3307101E),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '推荐',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'OK 播放  右键详情  上下切换  左键返回菜单',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double listWidth =
                        (constraints.maxWidth * 0.58).clamp(360.0, 548.0);
                    final double gap = constraints.maxWidth < 760 ? 24 : 38;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: listWidth,
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemBuilder: (_, int index) => _RecommendRow(
                              data: videos[index],
                              focused: index == selectedIndex,
                              onTap: () => onSelect(index),
                            ),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemCount: videos.length,
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: _HeroInfo(
                            video: selected,
                            autoFullscreenArmed: autoFullscreenArmed,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.video});

  final TvVideoCardData video;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: CachedNetworkImage(
        key: ValueKey<String>(video.cover),
        imageUrl: video.cover,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(color: const Color(0xFF07101E)),
      ),
    );
  }
}

class _RecommendRow extends StatelessWidget {
  const _RecommendRow({
    required this.data,
    required this.focused,
    required this.onTap,
  });

  final TvVideoCardData data;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      height: 112,
      decoration: BoxDecoration(
        color: focused ? const Color(0xDD243048) : const Color(0xAA111B2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? const Color(0xFFFF4BA0) : Colors.transparent,
          width: focused ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 178,
              height: 112,
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
                padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (focused &&
                        (data.subtitle ?? '').isNotEmpty) ...<Widget>[
                      Text(
                        data.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFF60B2),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      data.title,
                      maxLines: focused ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: focused ? 19 : 17,
                        height: 1.2,
                        fontWeight: focused ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${data.ownerName}  ${tvFormatDuration(data.duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
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

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.video,
    required this.autoFullscreenArmed,
  });

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
              SizedBox(height: compact ? 20 : 26),
              Wrap(
                spacing: compact ? 10 : 14,
                runSpacing: 12,
                children: <Widget>[
                  _HintChip(
                    icon: Icons.play_arrow_rounded,
                    label: autoFullscreenArmed ? '即将全屏播放' : 'OK 播放',
                    highlighted: autoFullscreenArmed,
                    compact: compact,
                  ),
                  _HintChip(
                    icon: Icons.info_outline,
                    label: '右键详情',
                    compact: compact,
                  ),
                  _HintChip(
                    icon: Icons.swap_vert_rounded,
                    label: '上下切换',
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
        color: highlighted ? const Color(0xFFFF4BA0) : const Color(0xAA111B2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: compact ? 18 : 20),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
