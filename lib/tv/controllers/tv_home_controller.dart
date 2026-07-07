import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/home/rcmd/result.dart';
import 'package:pilipala/models/model_hot_video_item.dart';
import 'package:pilipala/models/user/fav_detail.dart';
import 'package:pilipala/models/user/fav_folder.dart';
import 'package:pilipala/models/user/history.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/utils/tv_video_mapper.dart';
import 'package:pilipala/utils/storage.dart';

enum TvHomeTab { recommend, history, favorite, watchLater }

class TvHomeController extends GetxController {
  final Rx<TvHomeTab> currentTab = TvHomeTab.recommend.obs;
  final RxInt selectedIndex = 0.obs;

  final RxList<RecVideoItemAppModel> items = <RecVideoItemAppModel>[].obs;
  final RxBool recommendLoading = false.obs;
  final RxnString recommendError = RxnString();

  final RxList<TvVideoCardData> historyVideos = <TvVideoCardData>[].obs;
  final RxBool historyLoading = false.obs;
  final RxnString historyError = RxnString();

  final RxList<TvVideoCardData> favoriteVideos = <TvVideoCardData>[].obs;
  final RxBool favoriteLoading = false.obs;
  final RxnString favoriteError = RxnString();
  final RxnString favoriteFolderTitle = RxnString();

  final RxList<TvVideoCardData> watchLaterVideos = <TvVideoCardData>[].obs;
  final RxBool watchLaterLoading = false.obs;
  final RxnString watchLaterError = RxnString();

  final RxBool autoFullscreenArmed = false.obs;
  final RxBool previewPreparing = false.obs;
  final RxBool previewReady = false.obs;
  final RxnString previewError = RxnString();
  final RxnString previewBvid = RxnString();
  final RxBool recommendLoadingMore = false.obs;

  Timer? _fullscreenTimer;
  Timer? _previewTimer;
  Player? _previewPlayer;
  VideoController? _previewVideoController;
  Worker? _loginWorker;
  int _fullscreenGeneration = 0;
  int _previewGeneration = 0;
  bool _recommendStageActive = true;
  DateTime? _suppressShellExitUntil;
  bool _historyLoaded = false;
  bool _favoriteLoaded = false;
  bool _watchLaterLoaded = false;
  int _recommendFreshIdx = 0;

  VideoController? get previewVideoController => _previewVideoController;
  TvAntiAddictionController get _antiAddiction =>
      Get.find<TvAntiAddictionController>();
  TvSessionController get _session => Get.find<TvSessionController>();

  RxBool get loading => recommendLoading;
  RxnString get error => recommendError;
  bool get isLogin => _session.isLogin.value;
  bool get isRecommendTab => currentTab.value == TvHomeTab.recommend;

  bool get _canAutoActOnRecommend =>
      !isClosed &&
      _recommendStageActive &&
      isRecommendTab &&
      recommendVideos.isNotEmpty;

  bool get autoFullscreenEnabled => GStrorage.setting
      .get(SettingBoxKey.tvAutoFullscreenEnable, defaultValue: true) as bool;

  int get autoFullscreenDelaySeconds {
    final int value = GStrorage.setting
        .get(SettingBoxKey.tvAutoFullscreenDelay, defaultValue: 15) as int;
    return value.clamp(5, 60);
  }

  List<TvVideoCardData> get videos => recommendVideos;

  List<TvVideoCardData> get recommendVideos =>
      items.map(TvVideoMapper.fromRcmd).toList(growable: false);

  List<TvVideoCardData> get currentVideos {
    switch (currentTab.value) {
      case TvHomeTab.recommend:
        return recommendVideos;
      case TvHomeTab.history:
        return historyVideos;
      case TvHomeTab.favorite:
        return favoriteVideos;
      case TvHomeTab.watchLater:
        return watchLaterVideos;
    }
  }

  bool get currentLoading {
    switch (currentTab.value) {
      case TvHomeTab.recommend:
        return recommendLoading.value;
      case TvHomeTab.history:
        return historyLoading.value;
      case TvHomeTab.favorite:
        return favoriteLoading.value;
      case TvHomeTab.watchLater:
        return watchLaterLoading.value;
    }
  }

  String? get currentError {
    switch (currentTab.value) {
      case TvHomeTab.recommend:
        return recommendError.value;
      case TvHomeTab.history:
        return historyError.value;
      case TvHomeTab.favorite:
        return favoriteError.value;
      case TvHomeTab.watchLater:
        return watchLaterError.value;
    }
  }

  String get currentTabLabel {
    switch (currentTab.value) {
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

  String get currentEmptyText {
    switch (currentTab.value) {
      case TvHomeTab.recommend:
        return '暂无推荐内容';
      case TvHomeTab.history:
        return '暂无历史记录';
      case TvHomeTab.favorite:
        return '暂无收藏内容';
      case TvHomeTab.watchLater:
        return '稍后再看空空的';
    }
  }

  bool get currentTabNeedsLogin => !isRecommendTab && !isLogin;

  TvVideoCardData? get selectedVideo {
    final List<TvVideoCardData> list = currentVideos;
    if (list.isEmpty) {
      return null;
    }
    return list[selectedIndex.value.clamp(0, list.length - 1)];
  }

  Future<void> load() => loadRecommend();

  Future<void> loadRecommend({bool force = false}) async {
    if (recommendLoading.value) {
      return;
    }
    recommendLoading.value = true;
    recommendError.value = null;
    try {
      final dynamic res = await VideoHttp.rcmdVideoListApp(
        loginStatus: isLogin,
        freshIdx: force ? 0 : _recommendFreshIdx,
      );
      if (res['status'] == true) {
        items.value = List<RecVideoItemAppModel>.from(res['data'] as List);
        _recommendFreshIdx = 1;
        if (currentTab.value == TvHomeTab.recommend) {
          _normalizeSelectedIndex(resetWhenEmpty: true);
          schedulePreviewAutoplay(immediate: true);
          scheduleAutoFullscreen();
        }
      } else {
        recommendError.value = res['msg']?.toString() ?? '加载推荐失败';
      }
    } catch (e) {
      recommendError.value = '加载推荐失败: $e';
      SmartDialog.showToast(recommendError.value!);
    } finally {
      recommendLoading.value = false;
    }
  }

  Future<void> loadMoreRecommendIfNeeded() async {
    if (!isRecommendTab ||
        recommendLoading.value ||
        recommendLoadingMore.value ||
        items.isEmpty ||
        selectedIndex.value < items.length - 3) {
      return;
    }
    recommendLoadingMore.value = true;
    try {
      final dynamic res = await VideoHttp.rcmdVideoListApp(
        loginStatus: isLogin,
        freshIdx: _recommendFreshIdx,
      );
      if (res['status'] == true) {
        final List<RecVideoItemAppModel> more =
            List<RecVideoItemAppModel>.from(res['data'] as List);
        if (more.isNotEmpty) {
          items.addAll(more);
          _recommendFreshIdx++;
        }
      }
    } catch (_) {
      // 追加加载失败不打断当前遥控器浏览。
    } finally {
      recommendLoadingMore.value = false;
    }
  }

  Future<void> switchTab(
    TvHomeTab tab, {
    bool forceReload = false,
  }) async {
    currentTab.value = tab;
    selectedIndex.value = 0;
    if (tab == TvHomeTab.recommend) {
      if (items.isEmpty && !recommendLoading.value) {
        unawaited(loadRecommend(force: forceReload));
      } else {
        schedulePreviewAutoplay(immediate: true);
        scheduleAutoFullscreen();
      }
      return;
    }
    cancelAutoFullscreen();
    pausePreview();
    await ensureCurrentTabLoaded(force: forceReload);
  }

  Future<void> ensureCurrentTabLoaded({bool force = false}) async {
    if (currentTab.value == TvHomeTab.recommend) {
      if (force || (items.isEmpty && !recommendLoading.value)) {
        await loadRecommend(force: true);
      }
      return;
    }
    if (!isLogin) {
      return;
    }
    switch (currentTab.value) {
      case TvHomeTab.history:
        if (force || !_historyLoaded) {
          await _loadHistory();
        }
        return;
      case TvHomeTab.favorite:
        if (force || !_favoriteLoaded) {
          await _loadFavorites();
        }
        return;
      case TvHomeTab.watchLater:
        if (force || !_watchLaterLoaded) {
          await _loadWatchLater();
        }
        return;
      case TvHomeTab.recommend:
        return;
    }
  }

  Future<void> retryCurrentTab() async {
    if (currentTab.value == TvHomeTab.recommend) {
      await loadRecommend(force: true);
      return;
    }
    await switchTab(currentTab.value, forceReload: true);
  }

  void selectIndex(int index, {bool schedule = true}) {
    final List<TvVideoCardData> list = currentVideos;
    if (list.isEmpty) {
      selectedIndex.value = 0;
      return;
    }
    selectedIndex.value = index.clamp(0, list.length - 1);
    if (isRecommendTab) {
      unawaited(loadMoreRecommendIfNeeded());
    }
    if (schedule) {
      if (isRecommendTab) {
        schedulePreviewAutoplay();
        scheduleAutoFullscreen();
      } else {
        cancelAutoFullscreen();
        pausePreview();
      }
    }
  }

  void selectNext({bool schedule = true}) {
    final List<TvVideoCardData> list = currentVideos;
    if (list.isEmpty) {
      return;
    }
    selectIndex((selectedIndex.value + 1) % list.length, schedule: schedule);
  }

  void selectPrevious({bool schedule = true}) {
    final List<TvVideoCardData> list = currentVideos;
    if (list.isEmpty) {
      return;
    }
    selectIndex(
      selectedIndex.value == 0 ? list.length - 1 : selectedIndex.value - 1,
      schedule: schedule,
    );
  }

  Future<void> openSelectedDetail() async {
    final TvVideoCardData? data = selectedVideo;
    if (data == null || data.bvid.isEmpty) {
      return;
    }
    cancelAutoFullscreen();
    pausePreview();
    await Get.toNamed(
      '${TvRoutes.video}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}',
    );
    markRecommendStageActive(true);
  }

  Future<void> playSelected({bool immersive = false}) async {
    final TvVideoCardData? data = selectedVideo;
    if (data == null || data.bvid.isEmpty || data.cid <= 0) {
      return;
    }
    final String source = isRecommendTab ? 'recommend' : 'home';
    final int startSeconds = isRecommendTab ? _previewStartSecondsFor(data) : 0;
    cancelAutoFullscreen();
    pausePreview();
    final String route = isRecommendTab
        ? '${TvRoutes.player}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}&source=$source&index=${selectedIndex.value}&start=$startSeconds'
        : '${TvRoutes.player}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}&source=$source&start=$startSeconds';
    await Get.toNamed(route);
    suppressNextShellExit();
    markRecommendStageActive(true);
  }

  void suppressNextShellExit({
    Duration duration = const Duration(milliseconds: 900),
  }) {
    _suppressShellExitUntil = DateTime.now().add(duration);
  }

  bool consumeShellExitSuppression() {
    final DateTime? until = _suppressShellExitUntil;
    if (until == null) {
      return false;
    }
    _suppressShellExitUntil = null;
    return DateTime.now().isBefore(until);
  }

  int _previewStartSecondsFor(TvVideoCardData data) {
    if (!isRecommendTab || previewBvid.value != data.bvid) {
      return 0;
    }
    final int seconds = _previewPlayer?.state.position.inSeconds ?? 0;
    return seconds > 3 ? seconds : 0;
  }

  void markRecommendStageActive(bool active) {
    _recommendStageActive = active;
    if (!active) {
      _antiAddiction.stopCounting();
      cancelAutoFullscreen();
      pausePreview();
      return;
    }
    if (isRecommendTab) {
      schedulePreviewAutoplay(immediate: true);
      scheduleAutoFullscreen();
    }
  }

  void schedulePreviewAutoplay({bool immediate = false}) {
    _previewTimer?.cancel();
    final TvVideoCardData? data = selectedVideo;
    if (!_recommendStageActive ||
        !isRecommendTab ||
        data == null ||
        data.bvid.isEmpty ||
        data.cid <= 0) {
      previewReady.value = false;
      previewPreparing.value = false;
      previewError.value = null;
      previewBvid.value = null;
      return;
    }
    final int generation = ++_previewGeneration;
    _previewTimer = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 650),
      () {
        _startPreview(data, generation);
      },
    );
  }

  Future<void> _startPreview(TvVideoCardData data, int generation) async {
    if (!_canAutoActOnRecommend || generation != _previewGeneration) {
      return;
    }
    previewPreparing.value = true;
    previewError.value = null;
    try {
      final dynamic res = await VideoHttp.videoUrl(
        bvid: data.bvid,
        cid: data.cid,
        qn: VideoQuality.high720.code,
      );
      if (!_canAutoActOnRecommend || generation != _previewGeneration) {
        return;
      }
      if (res['status'] != true) {
        previewReady.value = false;
        previewError.value = res['msg']?.toString() ?? '预览地址获取失败';
        return;
      }
      final PlayUrlModel playData = res['data'] as PlayUrlModel;
      final String videoUrl = _resolveVideoUrl(playData);
      final String audioUrl = _resolveAudioUrl(playData);
      if (videoUrl.isEmpty) {
        previewReady.value = false;
        previewError.value = '预览地址为空';
        return;
      }
      await _openPreviewPlayer(videoUrl: videoUrl, audioUrl: audioUrl);
      if (!_canAutoActOnRecommend || generation != _previewGeneration) {
        return;
      }
      previewBvid.value = data.bvid;
      previewReady.value = _previewVideoController != null;
      _antiAddiction.startCounting(
        pausePlayback: pausePreview,
        resumePlayback: () => schedulePreviewAutoplay(immediate: true),
      );
    } catch (_) {
      if (generation == _previewGeneration) {
        previewReady.value = false;
        previewError.value = '预览播放失败';
      }
    } finally {
      if (generation == _previewGeneration) {
        previewPreparing.value = false;
      }
    }
  }

  String _resolveVideoUrl(PlayUrlModel playData) {
    final List<Durl>? durl = playData.durl;
    if (durl != null && durl.isNotEmpty && (durl.first.url ?? '').isNotEmpty) {
      return durl.first.url!;
    }
    final List<VideoItem>? dashVideos = playData.dash?.video;
    if (dashVideos != null && dashVideos.isNotEmpty) {
      return dashVideos.first.baseUrl ?? dashVideos.first.backupUrl ?? '';
    }
    return '';
  }

  String _resolveAudioUrl(PlayUrlModel playData) {
    final List<AudioItem>? dashAudios = playData.dash?.audio;
    if (dashAudios != null && dashAudios.isNotEmpty) {
      return dashAudios.first.baseUrl ?? dashAudios.first.backupUrl ?? '';
    }
    return '';
  }

  void pausePreview() {
    _previewGeneration++;
    _previewTimer?.cancel();
    _previewTimer = null;
    previewReady.value = false;
    previewPreparing.value = false;
    _previewPlayer?.pause();
    _antiAddiction.stopCounting();
  }

  Future<void> _openPreviewPlayer({
    required String videoUrl,
    required String audioUrl,
  }) async {
    final Player player = _previewPlayer ??= Player(
      configuration: const PlayerConfiguration(
        bufferSize: 5 * 1024 * 1024,
      ),
    );
    _previewVideoController ??= VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    final NativePlayer nativePlayer = player.platform as NativePlayer;
    if (audioUrl.isNotEmpty) {
      await nativePlayer.setProperty(
        'audio-files',
        audioUrl.replaceAll(':', r'\:'),
      );
    } else {
      await nativePlayer.setProperty('audio-files', '');
    }
    await player.setPlaylistMode(PlaylistMode.none);
    await player.open(
      Media(
        videoUrl,
        httpHeaders: const <String, String>{
          'user-agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Mobile Safari/537.36',
          'referer': HttpString.baseUrl,
        },
      ),
      play: true,
    );
  }

  void scheduleAutoFullscreen() {
    cancelAutoFullscreen();
    if (!autoFullscreenEnabled || !_canAutoActOnRecommend) {
      return;
    }
    final int generation = ++_fullscreenGeneration;
    Future<void>.delayed(Duration.zero, () {
      if (isClosed ||
          _fullscreenTimer != null ||
          generation != _fullscreenGeneration ||
          !autoFullscreenEnabled ||
          !_canAutoActOnRecommend) {
        return;
      }
      autoFullscreenArmed.value = true;
      _fullscreenTimer =
          Timer(Duration(seconds: autoFullscreenDelaySeconds), () {
        if (generation != _fullscreenGeneration ||
            !autoFullscreenEnabled ||
            !_canAutoActOnRecommend) {
          autoFullscreenArmed.value = false;
          return;
        }
        autoFullscreenArmed.value = false;
        unawaited(playSelected(immersive: true));
      });
    });
  }

  void cancelAutoFullscreen() {
    _fullscreenGeneration++;
    _fullscreenTimer?.cancel();
    _fullscreenTimer = null;
    autoFullscreenArmed.value = false;
  }

  void applyAutoFullscreenSettings() {
    if (!_recommendStageActive || !isRecommendTab) {
      cancelAutoFullscreen();
      pausePreview();
      return;
    }
    schedulePreviewAutoplay(immediate: true);
    if (autoFullscreenEnabled && items.isNotEmpty) {
      scheduleAutoFullscreen();
    } else {
      cancelAutoFullscreen();
    }
  }

  Future<void> _loadHistory() async {
    historyLoading.value = true;
    historyError.value = null;
    try {
      final String accessKey = UserHttp.cachedAccessKey();
      if (accessKey.isNotEmpty) {
        final dynamic tvRes = await UserHttp.tvHistoryListByAccessKey(
          accessKey: accessKey,
        );
        if (tvRes['status'] == true && tvRes['data'] is List<TvVideoCardData>) {
          historyVideos.value = tvRes['data'] as List<TvVideoCardData>;
          _historyLoaded = true;
          return;
        }
      }
      final dynamic res = await UserHttp.historyList(null, null);
      if (res['status'] == true) {
        final HistoryData data = res['data'] as HistoryData;
        historyVideos.value = (data.list ?? <HisListItem>[])
            .map(TvVideoMapper.fromHistory)
            .toList(growable: false);
        _historyLoaded = true;
      } else {
        historyVideos.clear();
        historyError.value = res['msg']?.toString() ?? '加载历史失败';
        _historyLoaded = false;
      }
    } catch (e) {
      historyVideos.clear();
      historyError.value = '加载历史失败: $e';
      _historyLoaded = false;
    } finally {
      historyLoading.value = false;
      if (currentTab.value == TvHomeTab.history) {
        _normalizeSelectedIndex(resetWhenEmpty: true);
      }
    }
  }

  Future<void> _loadWatchLater() async {
    watchLaterLoading.value = true;
    watchLaterError.value = null;
    try {
      final String accessKey = UserHttp.cachedAccessKey();
      if (accessKey.isNotEmpty) {
        final dynamic tvRes = await UserHttp.tvWatchLaterByAccessKey(
          accessKey: accessKey,
        );
        if (tvRes['status'] == true && tvRes['data'] is List<TvVideoCardData>) {
          watchLaterVideos.value = tvRes['data'] as List<TvVideoCardData>;
          _watchLaterLoaded = true;
          return;
        }
      }
      final dynamic res = await UserHttp.seeYouLater();
      if (res['status'] == true) {
        final dynamic data = res['data'];
        final dynamic list = data is Map ? data['list'] : null;
        watchLaterVideos.value = list is List
            ? list
                .whereType<HotVideoItemModel>()
                .map(TvVideoMapper.fromWatchLater)
                .toList(growable: false)
            : <TvVideoCardData>[];
        _watchLaterLoaded = true;
      } else {
        watchLaterVideos.clear();
        watchLaterError.value = res['msg']?.toString() ?? '加载稍后再看失败';
        _watchLaterLoaded = false;
      }
    } catch (e) {
      watchLaterVideos.clear();
      watchLaterError.value = '加载稍后再看失败: $e';
      _watchLaterLoaded = false;
    } finally {
      watchLaterLoading.value = false;
      if (currentTab.value == TvHomeTab.watchLater) {
        _normalizeSelectedIndex(resetWhenEmpty: true);
      }
    }
  }

  Future<void> _loadFavorites() async {
    favoriteLoading.value = true;
    favoriteError.value = null;
    favoriteFolderTitle.value = null;
    try {
      final String accessKey = UserHttp.cachedAccessKey();
      if (accessKey.isNotEmpty) {
        int fid = 0;
        final dynamic folderRes = await UserHttp.tvFavoriteFoldersByAccessKey(
          accessKey: accessKey,
        );
        if (folderRes['status'] == true && folderRes['data'] is List) {
          final List folders = folderRes['data'] as List;
          if (folders.isNotEmpty && folders.first is Map) {
            final Map folder = folders.first as Map;
            fid = UserHttp.tvInt(folder['fid'] ?? folder['id']);
            favoriteFolderTitle.value =
                folder['name']?.toString() ?? folder['title']?.toString();
          }
        }
        final dynamic tvRes = await UserHttp.tvFavoritesByAccessKey(
          accessKey: accessKey,
          fid: fid,
        );
        if (tvRes['status'] == true && tvRes['data'] is List<TvVideoCardData>) {
          favoriteVideos.value = tvRes['data'] as List<TvVideoCardData>;
          favoriteFolderTitle.value ??= '我的收藏';
          _favoriteLoaded = true;
          return;
        }
      }
      int mid = _session.userInfo.value?.mid ?? 0;
      if (mid <= 0) {
        final dynamic userInfoRes = await UserHttp.userInfo();
        if (userInfoRes['status'] == true && userInfoRes['data']?.mid != null) {
          mid = userInfoRes['data'].mid as int;
        }
      }
      if (mid <= 0) {
        favoriteVideos.clear();
        favoriteError.value = '无法获取账号信息';
        _favoriteLoaded = false;
        return;
      }
      final dynamic folderRes =
          await UserHttp.userfavFolder(pn: 1, ps: 20, mid: mid);
      if (folderRes['status'] != true) {
        favoriteVideos.clear();
        favoriteError.value = folderRes['msg']?.toString() ?? '加载收藏失败';
        _favoriteLoaded = false;
        return;
      }
      final FavFolderData folderData = folderRes['data'] as FavFolderData;
      final List<FavFolderItemData> folders =
          folderData.list ?? <FavFolderItemData>[];
      if (folders.isEmpty) {
        favoriteVideos.clear();
        favoriteFolderTitle.value = null;
        _favoriteLoaded = true;
        return;
      }
      final FavFolderItemData folder = folders.first;
      favoriteFolderTitle.value = folder.title;
      final int mediaId = folder.id ?? 0;
      if (mediaId <= 0) {
        favoriteVideos.clear();
        favoriteError.value = '收藏夹参数无效';
        _favoriteLoaded = false;
        return;
      }
      final dynamic detailRes = await UserHttp.userFavFolderDetail(
        mediaId: mediaId,
        pn: 1,
        ps: 20,
      );
      if (detailRes['status'] == true) {
        final FavDetailData data = detailRes['data'] as FavDetailData;
        favoriteVideos.value = (data.medias ?? <FavDetailItemData>[])
            .map(TvVideoMapper.fromFavDetail)
            .toList(growable: false);
        _favoriteLoaded = true;
      } else {
        favoriteVideos.clear();
        favoriteError.value = detailRes['msg']?.toString() ?? '加载收藏失败';
        _favoriteLoaded = false;
      }
    } catch (e) {
      favoriteVideos.clear();
      favoriteError.value = '加载收藏失败: $e';
      _favoriteLoaded = false;
    } finally {
      favoriteLoading.value = false;
      if (currentTab.value == TvHomeTab.favorite) {
        _normalizeSelectedIndex(resetWhenEmpty: true);
      }
    }
  }

  void _normalizeSelectedIndex({bool resetWhenEmpty = false}) {
    final List<TvVideoCardData> list = currentVideos;
    if (list.isEmpty) {
      if (resetWhenEmpty) {
        selectedIndex.value = 0;
      }
      cancelAutoFullscreen();
      pausePreview();
      return;
    }
    selectedIndex.value = selectedIndex.value.clamp(0, list.length - 1);
  }

  void _handleLoginChanged(bool loggedIn) {
    _historyLoaded = false;
    _favoriteLoaded = false;
    _watchLaterLoaded = false;
    historyVideos.clear();
    favoriteVideos.clear();
    watchLaterVideos.clear();
    favoriteFolderTitle.value = null;
    historyError.value = null;
    favoriteError.value = null;
    watchLaterError.value = null;
    unawaited(loadRecommend(force: true));
    if (loggedIn && !isRecommendTab) {
      unawaited(ensureCurrentTabLoaded(force: true));
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loginWorker = ever<bool>(_session.isLogin, _handleLoginChanged);
    unawaited(loadRecommend());
  }

  @override
  void onClose() {
    cancelAutoFullscreen();
    _previewTimer?.cancel();
    _antiAddiction.stopCounting();
    _previewPlayer?.dispose();
    _loginWorker?.dispose();
    super.onClose();
  }
}
