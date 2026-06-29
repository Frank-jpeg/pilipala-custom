import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_video_controller.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/utils/tv_formatters.dart';
import 'package:pilipala/tv/widgets/tv_async_state.dart';
import 'package:pilipala/tv/widgets/tv_focusable_button.dart';

class TvVideoPage extends StatelessWidget {
  const TvVideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TvVideoController controller =
        Get.put(TvVideoController(), tag: '${Get.parameters['bvid']}_${Get.parameters['cid']}');
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        child: Obx(
          () => TvAsyncState(
            loading: controller.loading.value,
            error: controller.error.value,
            empty: controller.detail.value == null,
            emptyText: '没有找到视频详情',
            child: ListView(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.detail.value?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 420,
                        height: 236,
                        child: CachedNetworkImage(
                          imageUrl: controller.detail.value?.pic ?? '',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFF1A2438),
                            alignment: Alignment.center,
                            child: const Icon(Icons.movie_outlined, size: 48),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            controller.detail.value?.owner?.name ?? '未知UP',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${tvCompactNumber(controller.detail.value?.stat?.view)} 播放  ${tvCompactNumber(controller.detail.value?.stat?.like)} 点赞',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: <Widget>[
                              TvFocusableButton(
                                label: '播放',
                                icon: Icons.play_arrow_rounded,
                                autofocus: true,
                                onPressed: () => Get.toNamed(
                                  TvRoutes.player,
                                  parameters: <String, String>{
                                    'bvid': controller.bvid,
                                    'cid': '${controller.selectedCid.value}',
                                    'aid':
                                        '${controller.detail.value?.aid ?? controller.aidParam}',
                                  },
                                ),
                              ),
                              TvFocusableButton(
                                label: controller.hasFav.value ? '取消收藏' : '收藏',
                                icon: controller.hasFav.value
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                onPressed: controller.toggleFav,
                              ),
                              TvFocusableButton(
                                label: '稍后再看',
                                icon: Icons.watch_later_outlined,
                                onPressed: controller.toggleWatchLater,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            controller.detail.value?.desc ?? '暂无简介',
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.6,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((controller.detail.value?.pages?.length ?? 0) > 1) ...<Widget>[
                  const SizedBox(height: 28),
                  const Text(
                    '选集',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: controller.detail.value!.pages!.map((part) {
                      return TvFocusableButton(
                        label: 'P${part.page} ${part.pagePart ?? ''}',
                        onPressed: () => controller.selectCid(part.cid ?? 0),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
