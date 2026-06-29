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

class TvShellPage extends StatefulWidget {
  const TvShellPage({super.key});

  @override
  State<TvShellPage> createState() => _TvShellPageState();
}

class _TvShellPageState extends State<TvShellPage> {
  final TvHomeController _controller = Get.put(TvHomeController());
  final FocusNode _focusNode = FocusNode();

  static const List<_TvTopTab> _tabs = <_TvTopTab>[
    _TvTopTab('我的'),
    _TvTopTab('推荐', selected: true),
    _TvTopTab('精选'),
    _TvTopTab('热播'),
    _TvTopTab('4K世界'),
    _TvTopTab('番剧'),
    _TvTopTab('国创'),
    _TvTopTab('影视'),
  ];

  @override
  Widget build(BuildContext context) {
    final TvSessionController session = Get.find<TvSessionController>();
    return Scaffold(
      backgroundColor: const Color(0xFF07101E),
      body: Focus(
        focusNode: _focusNode,
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
              isLogin: session.isLogin.value,
              autoFullscreenArmed: _controller.autoFullscreenArmed.value,
              tabs: _tabs,
              onSelect: _controller.selectIndex,
              onOpenSearch: () {
                _controller.cancelAutoFullscreen();
                Get.toNamed(TvRoutes.search)?.whenComplete(
                  _controller.scheduleAutoFullscreen,
                );
              },
              onOpenLogin: () {
                _controller.cancelAutoFullscreen();
                Get.toNamed(TvRoutes.login)?.whenComplete(
                  _controller.scheduleAutoFullscreen,
                );
              },
            ),
          ),
        ),
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
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _controller.playSelected();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _controller.openSelectedDetail();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}

class _RecommendStage extends StatelessWidget {
  const _RecommendStage({
    required this.videos,
    required this.selectedIndex,
    required this.isLogin,
    required this.autoFullscreenArmed,
    required this.tabs,
    required this.onSelect,
    required this.onOpenSearch,
    required this.onOpenLogin,
  });

  final List<TvVideoCardData> videos;
  final int selectedIndex;
  final bool isLogin;
  final bool autoFullscreenArmed;
  final List<_TvTopTab> tabs;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenLogin;

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
                Color(0xEE07101E),
                Color(0xAA07101E),
                Color(0x2207101E),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _TopActions(
                  isLogin: isLogin,
                  onOpenSearch: onOpenSearch,
                  onOpenLogin: onOpenLogin,
                ),
                const SizedBox(height: 18),
                _TabStrip(tabs: tabs),
                const SizedBox(height: 18),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 548,
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
                      const SizedBox(width: 38),
                      Expanded(
                        child: _HeroInfo(
                          video: selected,
                          autoFullscreenArmed: autoFullscreenArmed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.isLogin,
    required this.onOpenSearch,
    required this.onOpenLogin,
  });

  final bool isLogin;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _PillButton(
          icon: Icons.search,
          label: '搜索',
          onTap: onOpenSearch,
        ),
        const SizedBox(width: 18),
        _PillButton(
          icon: Icons.account_circle,
          label: isLogin ? '个人中心' : '登录',
          highlighted: true,
          onTap: onOpenLogin,
        ),
        const SizedBox(width: 28),
        const _PromoPill(label: '周中限定，月卡买一送一!'),
        const SizedBox(width: 18),
        const _PromoPill(label: 'BLG夺冠，买年卡再赠半年!'),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? const Color(0xFFEAF5FF) : const Color(0xAA182336),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon,
                  color: highlighted ? const Color(0xFF102036) : Colors.white,
                  size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: highlighted ? const Color(0xFF102036) : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoPill extends StatelessWidget {
  const _PromoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x88182336),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tabs});

  final List<_TvTopTab> tabs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, int index) => _TabItem(tab: tabs[index]),
        separatorBuilder: (_, __) => const SizedBox(width: 32),
        itemCount: tabs.length,
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab});

  final _TvTopTab tab;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          tab.label,
          style: TextStyle(
            color: tab.selected ? Colors.white : const Color(0xFFBFD8F4),
            fontSize: 25,
            fontWeight: tab.selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: tab.selected ? 36 : 0,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFFF4BA0),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Spacer(),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            '${video.ownerName}  ${tvFormatDuration(video.duration)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: <Widget>[
              _HintChip(
                icon: Icons.play_arrow_rounded,
                label: autoFullscreenArmed ? '即将全屏播放' : 'OK 播放',
                highlighted: autoFullscreenArmed,
              ),
              const _HintChip(icon: Icons.info_outline, label: '左键详情'),
              const _HintChip(icon: Icons.swap_vert_rounded, label: '上下切换'),
            ],
          ),
          const SizedBox(height: 34),
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
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFF4BA0) : const Color(0xAA111B2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TvTopTab {
  const _TvTopTab(this.label, {this.selected = false});

  final String label;
  final bool selected;
}
