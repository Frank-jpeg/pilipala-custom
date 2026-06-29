import 'package:get/get.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/models/model_hot_video_item.dart';
import 'package:pilipala/models/user/fav_detail.dart';
import 'package:pilipala/models/user/fav_folder.dart';
import 'package:pilipala/models/user/history.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';

class TvLibraryController extends GetxController {
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxList<HisListItem> historyList = <HisListItem>[].obs;
  final RxList<FavFolderItemData> favFolders = <FavFolderItemData>[].obs;
  final RxList<FavDetailItemData> favVideos = <FavDetailItemData>[].obs;
  final RxList<HotVideoItemModel> watchLaterList = <HotVideoItemModel>[].obs;
  final RxInt selectedFavFolderId = 0.obs;

  bool get isLogin => Get.find<TvSessionController>().isLogin.value;

  Future<void> loadAll() async {
    if (!isLogin) {
      return;
    }
    loading.value = true;
    error.value = null;
    try {
      final List<dynamic> responses = await Future.wait(<Future<dynamic>>[
        UserHttp.historyList(null, null),
        UserHttp.userInfo(),
        UserHttp.seeYouLater(),
      ]);

      final dynamic historyRes = responses[0];
      final dynamic userInfoRes = responses[1];
      final dynamic laterRes = responses[2];

      if (historyRes['status'] == true) {
        final HistoryData data = historyRes['data'] as HistoryData;
        historyList.value = data.list ?? <HisListItem>[];
      }
      if (laterRes['status'] == true) {
        final dynamic laterData = laterRes['data'];
        final dynamic laterList = laterData is Map ? laterData['list'] : null;
        watchLaterList.value = laterList is List
            ? laterList.whereType<HotVideoItemModel>().toList(growable: false)
            : <HotVideoItemModel>[];
      }

      if (userInfoRes['status'] == true && userInfoRes['data']?.mid != null) {
        final int mid = userInfoRes['data'].mid as int;
        final dynamic favRes = await UserHttp.userfavFolder(pn: 1, ps: 20, mid: mid);
        if (favRes['status'] == true) {
          final FavFolderData data = favRes['data'] as FavFolderData;
          favFolders.value = data.list ?? <FavFolderItemData>[];
          if (favFolders.isNotEmpty) {
            selectedFavFolderId.value = favFolders.first.id ?? 0;
            await loadFavFolder(selectedFavFolderId.value);
          }
        }
      }
    } catch (e) {
      error.value = '加载媒体库失败: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadFavFolder(int mediaId) async {
    if (mediaId <= 0) {
      favVideos.clear();
      return;
    }
    selectedFavFolderId.value = mediaId;
    final dynamic res = await UserHttp.userFavFolderDetail(
      mediaId: mediaId,
      pn: 1,
      ps: 20,
    );
    if (res['status'] == true) {
      final FavDetailData data = res['data'] as FavDetailData;
      favVideos.value = data.medias ?? <FavDetailItemData>[];
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever<bool>(Get.find<TvSessionController>().isLogin, (_) {
      if (isLogin) {
        loadAll();
      } else {
        historyList.clear();
        favFolders.clear();
        favVideos.clear();
        watchLaterList.clear();
      }
    });
    if (isLogin) {
      loadAll();
    }
  }
}
