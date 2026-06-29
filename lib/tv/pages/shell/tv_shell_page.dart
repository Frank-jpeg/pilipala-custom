import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/utils/tv_video_mapper.dart';
import 'package:pilipala/tv/widgets/tv_async_state.dart';
import 'package:pilipala/tv/widgets/tv_horizontal_rail.dart';
import 'package:pilipala/tv/widgets/tv_left_nav.dart';

class TvShellPage extends StatefulWidget {
  const TvShellPage({super.key});

  @override
  State<TvShellPage> createState() => _TvShellPageState();
}

class _TvShellPageState extends State<TvShellPage> {
  final TvHomeController _controller = Get.put(TvHomeController());

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final TvSessionController session = Get.find<TvSessionController>();
    return Scaffold(
      body: Row(
        children: <Widget>[
          Obx(
            () => TvLeftNav(
              selectedIndex: _selectedIndex,
              items: <TvNavItem>[
                TvNavItem(
                  label: '推荐',
                  icon: Icons.home_outlined,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                ),
                TvNavItem(
                  label: '搜索',
                  icon: Icons.search,
                  onTap: () => Get.toNamed(TvRoutes.search),
                ),
                TvNavItem(
                  label: '媒体库',
                  icon: Icons.video_library_outlined,
                  onTap: () => Get.toNamed(TvRoutes.library),
                ),
                TvNavItem(
                  label: session.isLogin.value ? '我的' : '登录',
                  icon: Icons.account_circle_outlined,
                  onTap: () => Get.toNamed(TvRoutes.login),
                ),
                TvNavItem(
                  label: '设置',
                  icon: Icons.settings_outlined,
                  onTap: () => Get.toNamed(TvRoutes.settings),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
              child: Obx(
                () => TvAsyncState(
                  loading: _controller.loading.value,
                  error: _controller.error.value,
                  empty: _controller.items.isEmpty,
                  emptyText: '暂无推荐内容',
                  child: ListView(
                    children: <Widget>[
                      Text(
                        '推荐',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        session.isLogin.value
                            ? '已登录，优先使用更完整的推荐流'
                            : '未登录，先给你来一版游客推荐',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 28),
                      TvHorizontalRail(
                        title: '今日推荐',
                        items: _controller.items
                            .map(TvVideoMapper.fromRcmd)
                            .toList(growable: false),
                        autofocusFirst: true,
                        onTap: (data) {
                          Get.toNamed(
                            '${TvRoutes.video}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
