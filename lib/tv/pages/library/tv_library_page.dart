import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_library_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/widgets/tv_async_state.dart';
import 'package:pilipala/tv/widgets/tv_focusable_button.dart';
import 'package:pilipala/tv/widgets/tv_horizontal_rail.dart';

class TvLibraryPage extends StatelessWidget {
  const TvLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TvLibraryController controller = Get.put(TvLibraryController());
    final TvSessionController session = Get.find<TvSessionController>();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        child: Obx(
          () {
            if (!session.isLogin.value) {
              return Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TvFocusableButton(
                        label: '返回',
                        icon: Icons.arrow_back,
                        onPressed: Get.back,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '媒体库',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.qr_code_2,
                            size: 64,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 18),
                          const Text('登录后可查看历史、收藏和稍后再看'),
                          const SizedBox(height: 18),
                          TvFocusableButton(
                            label: '去登录',
                            icon: Icons.login,
                            autofocus: true,
                            onPressed: () => Get.toNamed(TvRoutes.login),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return TvAsyncState(
              loading: controller.loading.value,
              error: controller.error.value,
              empty: false,
              child: ListView(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TvFocusableButton(
                        label: '返回',
                        icon: Icons.arrow_back,
                        onPressed: Get.back,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '媒体库',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (controller.historyCards.isNotEmpty) ...<Widget>[
                    TvHorizontalRail(
                      title: '历史记录',
                      items: controller.historyCards
                          .take(10)
                          .toList(growable: false),
                      onTap: (data) => Get.toNamed(
                        '${TvRoutes.video}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}',
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  if (controller.watchLaterCards.isNotEmpty) ...<Widget>[
                    TvHorizontalRail(
                      title: '稍后再看',
                      items: controller.watchLaterCards
                          .take(10)
                          .toList(growable: false),
                      onTap: (data) => Get.toNamed(
                        '${TvRoutes.video}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}',
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  if (controller.favFolders.isNotEmpty) ...<Widget>[
                    const Text(
                      '收藏夹',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: controller.favFolders.map((folder) {
                        return TvFocusableButton(
                          label: folder.title ?? '未命名收藏夹',
                          onPressed: () =>
                              controller.loadFavFolder(folder.id ?? 0),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    if (controller.favCards.isNotEmpty)
                      TvHorizontalRail(
                        title: '收藏内容',
                        items: controller.favCards
                            .take(10)
                            .toList(growable: false),
                        onTap: (data) => Get.toNamed(
                          '${TvRoutes.video}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}',
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
