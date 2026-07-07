import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/models/model_hot_video_item.dart';
import 'package:pilipala/models/user/fav_detail.dart';
import 'package:pilipala/models/user/fav_folder.dart';
import 'package:pilipala/models/user/history.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/tv/utils/tv_video_mapper.dart';

class TvLibraryController extends GetxController {
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxList<HisListItem> historyList = <HisListItem>[].obs;
  final RxList<FavFolderItemData> favFolders = <FavFolderItemData>[].obs;
  final RxList<FavDetailItemData> favVideos = <FavDetailItemData>[].obs;
  final RxList<HotVideoItemModel> watchLaterList = <HotVideoItemModel>[].obs;
  final RxList<TvVideoCardData> historyCards = <TvVideoCardData>[].obs;
  final RxList<TvVideoCardData> favCards = <TvVideoCardData>[].obs;
  final RxList<TvVideoCardData> watchLaterCards = <TvVideoCardData>[].obs;
  final RxInt selectedFavFolderId = 0.obs;
  Worker? _loginWorker;

  bool get isLogin => Get.find<TvSessionController>().isLogin.value;

  Future<void> loadAll() async {
    if (!isLogin) {
      return;
    }
    loading.value = true;
    error.value = null;
    try {
      final String accessKey = UserHttp.cachedAccessKey();
      if (accessKey.isNotEmpty) {
        final List<dynamic> tvResponses = await Future.wait(<Future<dynamic>>[
          UserHttp.tvHistoryListByAccessKey(accessKey: accessKey),
          UserHttp.tvWatchLaterByAccessKey(accessKey: accessKey),
          _loadTvFavoriteCards(accessKey),
        ]);
        final dynamic historyRes = tvResponses[0];
        final dynamic laterRes = tvResponses[1];
        final dynamic favRes = tvResponses[2];
        if (historyRes['status'] == true &&
            historyRes['data'] is List<TvVideoCardData>) {
          historyCards.value = historyRes['data'] as List<TvVideoCardData>;
          historyList.clear();
        }
        if (laterRes['status'] == true &&
            laterRes['data'] is List<TvVideoCardData>) {
          watchLaterCards.value = laterRes['data'] as List<TvVideoCardData>;
          watchLaterList.clear();
        }
        if (favRes['status'] == true &&
            favRes['data'] is List<TvVideoCardData>) {
          favCards.value = favRes['data'] as List<TvVideoCardData>;
          favFolders.clear();
          favVideos.clear();
        }
        if (historyCards.isNotEmpty ||
            watchLaterCards.isNotEmpty ||
            favCards.isNotEmpty) {
          return;
        }
      }

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
        historyCards.value =
            historyList.map(TvVideoMapper.fromHistory).toList(growable: false);
      }
      if (laterRes['status'] == true) {
        final dynamic laterData = laterRes['data'];
        final dynamic laterList = laterData is Map ? laterData['list'] : null;
        watchLaterList.value = laterList is List
            ? laterList.whereType<HotVideoItemModel>().toList(growable: false)
            : <HotVideoItemModel>[];
        watchLaterCards.value = watchLaterList
            .map(TvVideoMapper.fromWatchLater)
            .toList(growable: false);
      }

      if (userInfoRes['status'] == true && userInfoRes['data']?.mid != null) {
        final int mid = userInfoRes['data'].mid as int;
        final dynamic favRes =
            await UserHttp.userfavFolder(pn: 1, ps: 20, mid: mid);
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

  Future<dynamic> _loadTvFavoriteCards(String accessKey) async {
    int fid = 0;
    final dynamic folderRes =
        await UserHttp.tvFavoriteFoldersByAccessKey(accessKey: accessKey);
    if (folderRes['status'] == true && folderRes['data'] is List) {
      final List folders = folderRes['data'] as List;
      if (folders.isNotEmpty && folders.first is Map) {
        final Map folder = folders.first as Map;
        fid = UserHttp.tvInt(folder['fid'] ?? folder['id']);
      }
    }
    return UserHttp.tvFavoritesByAccessKey(accessKey: accessKey, fid: fid);
  }

  Future<void> loadFavFolder(int mediaId) async {
    if (mediaId <= 0) {
      favVideos.clear();
      return;
    }
    selectedFavFolderId.value = mediaId;
    try {
      final dynamic res = await UserHttp.userFavFolderDetail(
        mediaId: mediaId,
        pn: 1,
        ps: 20,
      );
      if (res['status'] == true) {
        final FavDetailData data = res['data'] as FavDetailData;
        favVideos.value = data.medias ?? <FavDetailItemData>[];
        favCards.value =
            favVideos.map(TvVideoMapper.fromFavDetail).toList(growable: false);
      } else {
        final String message = res['msg']?.toString() ?? '加载收藏夹失败';
        SmartDialog.showToast(message);
      }
    } catch (e) {
      SmartDialog.showToast('加载收藏夹失败: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loginWorker = ever<bool>(Get.find<TvSessionController>().isLogin, (_) {
      if (isLogin) {
        loadAll();
      } else {
        historyList.clear();
        favFolders.clear();
        favVideos.clear();
        watchLaterList.clear();
        historyCards.clear();
        favCards.clear();
        watchLaterCards.clear();
      }
    });
    if (isLogin) {
      loadAll();
    }
  }

  @override
  void onClose() {
    _loginWorker?.dispose();
    super.onClose();
  }
}
