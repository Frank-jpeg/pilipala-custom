import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/user/fav_folder.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/models/video_detail_res.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';

class TvVideoController extends GetxController {
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final Rxn<VideoDetailData> detail = Rxn<VideoDetailData>();
  final RxInt selectedCid = 0.obs;
  final RxBool hasFav = false.obs;
  final RxBool hasWatchLater = false.obs;
  final RxList<FavFolderItemData> favFolders = <FavFolderItemData>[].obs;

  String get bvid => Get.parameters['bvid'] ?? '';
  int get cidParam => int.tryParse(Get.parameters['cid'] ?? '0') ?? 0;
  int get aidParam => int.tryParse(Get.parameters['aid'] ?? '0') ?? 0;
  bool get isLogin => Get.find<TvSessionController>().isLogin.value;

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final dynamic res = await VideoHttp.videoIntro(bvid: bvid);
      if (res['status'] == true) {
        detail.value = res['data'] as VideoDetailData;
        final int firstPageCid = detail.value?.pages
                ?.firstWhereOrNull((part) => (part.cid ?? 0) > 0)
                ?.cid ??
            0;
        selectedCid.value = cidParam > 0
            ? cidParam
            : (detail.value?.cid ?? 0) > 0
                ? detail.value!.cid!
                : firstPageCid;
        if (isLogin) {
          await Future.wait(<Future<void>>[
            loadFavStatus(),
            loadFavFolders(),
          ]);
        }
      } else {
        error.value = res['msg']?.toString() ?? '加载详情失败';
      }
    } catch (e) {
      error.value = '加载详情失败: $e';
      SmartDialog.showToast(error.value!);
    } finally {
      loading.value = false;
    }
  }

  Future<PlayUrlModel?> loadPlayUrl([int? cid]) async {
    final dynamic res = await VideoHttp.videoUrl(
      bvid: bvid,
      cid: cid ?? selectedCid.value,
      qn: VideoQuality.high720.code,
    );
    if (res['status'] == true) {
      return res['data'] as PlayUrlModel;
    }
    SmartDialog.showToast(res['msg']?.toString() ?? '获取播放地址失败');
    return null;
  }

  Future<void> loadFavStatus() async {
    if (!isLogin || (detail.value?.aid ?? aidParam) <= 0) {
      hasFav.value = false;
      return;
    }
    final dynamic res =
        await VideoHttp.hasFavVideo(aid: detail.value?.aid ?? aidParam);
    if (res['status'] == true) {
      hasFav.value = res['data']['favoured'] == true;
    }
  }

  Future<void> loadFavFolders() async {
    if (!isLogin) {
      return;
    }
    final dynamic userRes = await UserHttp.userInfo();
    if (userRes['status'] == true && userRes['data']?.mid != null) {
      final dynamic res = await UserHttp.userfavFolder(
        pn: 1,
        ps: 20,
        mid: userRes['data'].mid as int,
      );
      if (res['status'] == true) {
        final FavFolderData data = res['data'] as FavFolderData;
        favFolders.value = data.list ?? <FavFolderItemData>[];
      }
    }
  }

  Future<void> toggleWatchLater() async {
    if (!isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    final dynamic res = await UserHttp.toViewLater(
      bvid: bvid,
      aid: detail.value?.aid ?? aidParam,
    );
    SmartDialog.showToast(res['msg']?.toString() ?? '操作完成');
    if (res['status'] == true) {
      hasWatchLater.value = true;
    }
  }

  Future<void> toggleFav() async {
    if (!isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    if (favFolders.isEmpty) {
      await loadFavFolders();
    }
    if (favFolders.isEmpty) {
      SmartDialog.showToast('没有可用收藏夹');
      return;
    }
    final int folderId = favFolders.first.id ?? 0;
    final dynamic res = await VideoHttp.favVideo(
      aid: detail.value?.aid ?? aidParam,
      addIds: hasFav.value ? '' : '$folderId',
      delIds: hasFav.value ? '$folderId' : '',
    );
    if (res['status'] == true) {
      hasFav.value = !hasFav.value;
      SmartDialog.showToast(hasFav.value ? '已收藏' : '已取消收藏');
    } else {
      SmartDialog.showToast(res['msg']?.toString() ?? '收藏失败');
    }
  }

  void selectCid(int cid) {
    selectedCid.value = cid;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }
}
