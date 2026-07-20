import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/user/fav_folder.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/models/video_detail_res.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/tv_routes.dart';

class TvVideoController extends GetxController {
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final Rxn<VideoDetailData> detail = Rxn<VideoDetailData>();
  final RxInt selectedCid = 0.obs;
  final RxBool hasFav = false.obs;
  final RxBool hasWatchLater = false.obs;
  final RxList<FavFolderItemData> favFolders = <FavFolderItemData>[].obs;

  String _bvid = '';
  int _cidParam = 0;
  int _aidParam = 0;

  String get bvid => _bvid;
  int get cidParam => _cidParam;
  int get aidParam => _aidParam;
  bool get isLogin => Get.find<TvSessionController>().isLogin.value;

  void _readRouteParams() {
    _bvid = Get.parameters['bvid'] ?? '';
    _cidParam = int.tryParse(Get.parameters['cid'] ?? '0') ?? 0;
    _aidParam = int.tryParse(Get.parameters['aid'] ?? '0') ?? 0;
  }

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
    try {
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
    } catch (e) {
      SmartDialog.showToast('加载收藏夹失败: $e');
    }
  }

  void playSelected() {
    final int cid = selectedCid.value;
    final int aid = detail.value?.aid ?? aidParam;
    if (bvid.isEmpty || cid <= 0) {
      SmartDialog.showToast('当前视频暂时不能播放');
      return;
    }
    Get.toNamed(
      TvRoutes.player,
      parameters: <String, String>{
        'bvid': bvid,
        'cid': '$cid',
        'aid': '$aid',
        'source': 'detail',
      },
    );
  }

  void playCid(int cid) {
    selectCid(cid);
    if (selectedCid.value == cid) {
      playSelected();
    }
  }

  Future<void> toggleWatchLater() async {
    if (!isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    final int aid = detail.value?.aid ?? aidParam;
    if (bvid.isEmpty || aid <= 0) {
      SmartDialog.showToast('视频参数缺失');
      return;
    }
    try {
      final dynamic res = await UserHttp.toViewLater(
        bvid: bvid,
        aid: aid,
      );
      SmartDialog.showToast(res['msg']?.toString() ?? '操作完成');
      if (res['status'] == true) {
        hasWatchLater.value = true;
      }
    } catch (e) {
      SmartDialog.showToast('稍后再看失败: $e');
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
    final int aid = detail.value?.aid ?? aidParam;
    if (folderId <= 0 || aid <= 0) {
      SmartDialog.showToast('收藏参数缺失');
      return;
    }
    try {
      final dynamic res = await VideoHttp.favVideo(
        aid: aid,
        addIds: hasFav.value ? '' : '$folderId',
        delIds: hasFav.value ? '$folderId' : '',
      );
      if (res['status'] == true) {
        hasFav.value = !hasFav.value;
        SmartDialog.showToast(hasFav.value ? '已收藏' : '已取消收藏');
      } else {
        SmartDialog.showToast(res['msg']?.toString() ?? '收藏失败');
      }
    } catch (e) {
      SmartDialog.showToast('收藏失败: $e');
    }
  }

  void selectCid(int cid) {
    if (cid <= 0) {
      SmartDialog.showToast('分P参数无效');
      return;
    }
    selectedCid.value = cid;
  }

  @override
  void onInit() {
    super.onInit();
    _readRouteParams();
    load();
  }
}
