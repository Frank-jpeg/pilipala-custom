import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/models/video_detail_res.dart';
import 'package:pilipala/plugin/pl_player/controller.dart';
import 'package:pilipala/plugin/pl_player/models/data_source.dart';
import 'package:pilipala/plugin/pl_player/models/play_status.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/utils/global_data_cache.dart';
import 'package:pilipala/utils/storage.dart';

class TvPlayerController extends GetxController {
  static const int playerMenuItemCount = 14;

  final PlPlayerController player = PlPlayerController(videoType: 'archive');
  final RxBool loading = true.obs;
  final RxBool controlsVisible = true.obs;
  final RxBool menuVisible = false.obs;
  final RxInt menuIndex = 0.obs;
  final RxInt danmakuOptionVersion = 0.obs;
  final RxBool thinProgressEnabled = true.obs;
  final RxDouble volume = 1.0.obs;
  final RxDouble playbackSpeed = 1.0.obs;
  final RxnString error = RxnString();
  final RxnString title = RxnString();
  final RxInt currentCid = 0.obs;

  String _bvid = '';
  int _cid = 0;
  int _aid = 0;
  int _recommendIndex = 0;
  int _startSeconds = 0;
  String _source = '';
  bool _isRecommendSource = false;

  String get bvid => _bvid;
  int get cid => _cid;
  int get aid => _aid;
  int get recommendIndex => _recommendIndex;
  int get startSeconds => _startSeconds;
  String get source => _source;
  bool get isRecommendSource => _isRecommendSource;
  bool get isHomeSource => _source == 'home';

  Worker? _positionWorker;
  Worker? _statusWorker;
  bool _switchingVideo = false;

  void _readRouteParams() {
    _bvid = Get.parameters['bvid'] ?? '';
    _cid = int.tryParse(Get.parameters['cid'] ?? '0') ?? 0;
    _aid = int.tryParse(Get.parameters['aid'] ?? '0') ?? 0;
    _recommendIndex = int.tryParse(Get.parameters['index'] ?? '0') ?? 0;
    _startSeconds =
        (int.tryParse(Get.parameters['start'] ?? '0') ?? 0).clamp(0, 86400);
    _source = Get.parameters['source'] ?? '';
    _isRecommendSource = _source == 'recommend';
    thinProgressEnabled.value = GStrorage.setting.get(
      SettingBoxKey.tvPlayerThinProgressEnable,
      defaultValue: true,
    ) as bool;
  }

  Future<void> initPlayer() async {
    if (isRecommendSource && Get.isRegistered<TvHomeController>()) {
      await playRecommendIndex(recommendIndex, startSeconds: startSeconds);
      return;
    }
    await playByParams(bvid: bvid, cid: cid, startSeconds: startSeconds);
  }

  Future<void> playByParams({
    required String bvid,
    required int cid,
    String? title,
    int startSeconds = 0,
  }) async {
    loading.value = true;
    error.value = null;
    this.title.value = title;
    player.danmakuController?.clear();
    player.danmakuController = null;
    try {
      if (bvid.isEmpty) {
        error.value = '播放参数缺失';
        return;
      }
      int resolvedCid = cid;
      if (resolvedCid <= 0) {
        resolvedCid = await _resolveCidFromDetail(bvid);
      }
      if (resolvedCid <= 0) {
        error.value = '播放分 P 参数缺失';
        SmartDialog.showToast(error.value!);
        return;
      }
      _bvid = bvid;
      _cid = resolvedCid;
      currentCid.value = resolvedCid;
      player.isOpenDanmu.value = GStrorage.setting.get(
        SettingBoxKey.enableShowDanmaku,
        defaultValue: true,
      ) as bool;
      _reloadDanmakuOptionsFromStorage();
      final dynamic res = await VideoHttp.videoUrl(
        bvid: bvid,
        cid: resolvedCid,
        qn: VideoQuality.high720.code,
      );
      if (res['status'] != true) {
        error.value = res['msg']?.toString() ?? '获取播放地址失败';
        SmartDialog.showToast(error.value!);
        return;
      }
      final PlayUrlModel playData = res['data'] as PlayUrlModel;
      final List<Durl>? durl = playData.durl;
      final List<VideoItem>? dashVideos = playData.dash?.video;
      final List<AudioItem>? dashAudios = playData.dash?.audio;
      final String videoUrl = (durl != null && durl.isNotEmpty
              ? durl.first.url
              : dashVideos != null && dashVideos.isNotEmpty
                  ? dashVideos.first.baseUrl
                  : null) ??
          '';
      final String audioUrl = dashAudios != null && dashAudios.isNotEmpty
          ? dashAudios.first.baseUrl ?? ''
          : '';
      if (videoUrl.isEmpty) {
        error.value = '播放地址为空';
        return;
      }
      await player.setDataSource(
        DataSource(
          videoSource: videoUrl,
          audioSource: audioUrl,
          type: DataSourceType.network,
          httpHeaders: <String, String>{
            'user-agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
            'referer': HttpString.baseUrl,
          },
        ),
        autoplay: true,
        enableHA: false,
        seekTo: Duration(seconds: startSeconds.clamp(0, 86400)),
        duration: playData.timeLength == null
            ? null
            : Duration(milliseconds: playData.timeLength!),
        bvid: bvid,
        cid: resolvedCid,
      );
      await player.getCurrentVolume();
      volume.value = player.volume.value;
      playbackSpeed.value = player.playbackSpeed;
      _syncAntiAddictionWithPlayer();
    } catch (e) {
      error.value = '播放器初始化失败: $e';
      SmartDialog.showToast(error.value!);
    } finally {
      loading.value = false;
    }
  }

  Future<int> _resolveCidFromDetail(String bvid) async {
    try {
      final dynamic res = await VideoHttp.videoIntro(bvid: bvid);
      if (res['status'] != true || res['data'] is! VideoDetailData) {
        return 0;
      }
      final VideoDetailData detail = res['data'] as VideoDetailData;
      if ((detail.cid ?? 0) > 0) {
        _aid = detail.aid ?? _aid;
        return detail.cid!;
      }
      final int firstPageCid = detail.pages
              ?.firstWhereOrNull((Part part) => (part.cid ?? 0) > 0)
              ?.cid ??
          0;
      if (firstPageCid > 0) {
        _aid = detail.aid ?? _aid;
      }
      return firstPageCid;
    } catch (_) {
      return 0;
    }
  }

  Future<void> playRecommendIndex(int index, {int startSeconds = 0}) async {
    if (!Get.isRegistered<TvHomeController>()) {
      return;
    }
    final TvHomeController home = Get.find<TvHomeController>();
    if (home.videos.isEmpty) {
      error.value = '推荐列表为空';
      loading.value = false;
      return;
    }
    home.selectIndex(index, schedule: false);
    final TvVideoCardData? data = home.selectedVideo;
    if (data == null) {
      error.value = '推荐视频不存在';
      loading.value = false;
      return;
    }
    await playByParams(
      bvid: data.bvid,
      cid: data.cid,
      title: data.title,
      startSeconds: startSeconds,
    );
    _aid = data.aid;
  }

  Future<void> playNextRecommend() async {
    if (!isRecommendSource || !Get.isRegistered<TvHomeController>()) {
      return;
    }
    final TvHomeController home = Get.find<TvHomeController>();
    home.selectNext(schedule: false);
    _startSeconds = 0;
    await playRecommendIndex(home.selectedIndex.value);
  }

  Future<void> playPreviousRecommend() async {
    if (!isRecommendSource || !Get.isRegistered<TvHomeController>()) {
      return;
    }
    final TvHomeController home = Get.find<TvHomeController>();
    home.selectPrevious(schedule: false);
    _startSeconds = 0;
    await playRecommendIndex(home.selectedIndex.value);
  }

  Future<void> togglePlay() async {
    await player.togglePlay();
    controlsVisible.value = true;
  }

  Future<void> toggleDanmaku() async {
    final bool next = !player.isOpenDanmu.value;
    player.isOpenDanmu.value = next;
    await GStrorage.setting.put(SettingBoxKey.enableShowDanmaku, next);
    menuVisible.value = true;
    controlsVisible.value = true;
  }

  String get danmakuAreaLabel {
    final double area = player.showArea;
    if ((area - 0.25).abs() < 0.01) {
      return '1/4屏';
    }
    if ((area - 0.5).abs() < 0.01) {
      return '半屏';
    }
    if ((area - 0.75).abs() < 0.01) {
      return '3/4屏';
    }
    return '满屏';
  }

  String get danmakuDurationLabel =>
      '${player.danmakuDurationVal.toStringAsFixed(0)}秒';

  String get danmakuFontScaleLabel => '${(player.fontSizeVal * 100).round()}%';

  String get danmakuOpacityLabel => '${(player.opacityVal * 100).round()}%';

  String get danmakuStrokeLabel {
    final double stroke = player.strokeWidth;
    return stroke % 1 == 0
        ? stroke.toStringAsFixed(0)
        : stroke.toStringAsFixed(1);
  }

  bool isDanmakuBlockEnabled(int type) => player.blockTypes.contains(type);

  Future<void> cycleDanmakuArea() async {
    const List<double> areas = <double>[0.25, 0.5, 0.75, 1.0];
    final int index = _nearestDoubleIndex(areas, player.showArea);
    player.showArea = areas[(index + 1) % areas.length];
    _applyDanmakuOption();
    await _cacheDanmakuOption();
  }

  Future<void> cycleDanmakuDuration() async {
    const List<double> durations = <double>[2, 4, 6, 8, 12, 16];
    final int index = _nearestDoubleIndex(durations, player.danmakuDurationVal);
    player.danmakuDurationVal = durations[(index + 1) % durations.length];
    _applyDanmakuOption();
    await _cacheDanmakuOption();
  }

  Future<void> cycleDanmakuFontScale() async {
    const List<double> scales = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5];
    final int index = _nearestDoubleIndex(scales, player.fontSizeVal);
    player.fontSizeVal = scales[(index + 1) % scales.length];
    _applyDanmakuOption();
    await _cacheDanmakuOption();
  }

  Future<void> cycleDanmakuOpacity() async {
    const List<double> opacities = <double>[0.25, 0.5, 0.75, 1.0];
    final int index = _nearestDoubleIndex(opacities, player.opacityVal);
    player.opacityVal = opacities[(index + 1) % opacities.length];
    _applyDanmakuOption();
    await _cacheDanmakuOption();
  }

  Future<void> cycleDanmakuStroke() async {
    const List<double> strokes = <double>[0, 0.5, 1, 1.5, 2, 3];
    final int index = _nearestDoubleIndex(strokes, player.strokeWidth);
    player.strokeWidth = strokes[(index + 1) % strokes.length];
    _applyDanmakuOption();
    await _cacheDanmakuOption();
  }

  Future<void> toggleDanmakuBlock(int type) async {
    final List<dynamic> next = List<dynamic>.from(player.blockTypes);
    if (next.contains(type)) {
      next.remove(type);
    } else {
      next.add(type);
    }
    player.blockTypes = next;
    _applyDanmakuOption();
    await _cacheDanmakuOption();
  }

  int _nearestDoubleIndex(List<double> values, double current) {
    int bestIndex = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < values.length; i++) {
      final double distance = (values[i] - current).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  void _applyDanmakuOption() {
    try {
      final option = player.danmakuController?.option;
      if (option == null) {
        return;
      }
      player.danmakuController?.updateOption(
        option.copyWith(
          area: player.showArea,
          opacity: player.opacityVal,
          strokeWidth: player.strokeWidth,
          fontSize: (15 * player.fontSizeVal).toDouble(),
          duration: player.danmakuDurationVal / player.playbackSpeed,
          hideTop: player.blockTypes.contains(5),
          hideScroll: player.blockTypes.contains(2),
          hideBottom: player.blockTypes.contains(4),
        ),
      );
    } catch (_) {}
    danmakuOptionVersion.value++;
    menuVisible.value = true;
    controlsVisible.value = true;
  }

  Future<void> _cacheDanmakuOption() async {
    await player.cacheDanmakuOption();
    _syncDanmakuGlobalCache();
    danmakuOptionVersion.value++;
    menuVisible.value = true;
    controlsVisible.value = true;
  }

  void _reloadDanmakuOptionsFromStorage() {
    player.blockTypes = List<dynamic>.from(
      GStrorage.localCache.get(
        LocalCacheKey.danmakuBlockType,
        defaultValue: <dynamic>[],
      ) as List,
    );
    player.showArea = _readDouble(LocalCacheKey.danmakuShowArea, 0.5);
    player.danmakuDurationVal = _readDouble(LocalCacheKey.danmakuDuration, 4.0);
    player.fontSizeVal = _readDouble(LocalCacheKey.danmakuFontScale, 1.0);
    player.opacityVal = _readDouble(LocalCacheKey.danmakuOpacity, 1.0);
    player.strokeWidth = _readDouble(LocalCacheKey.strokeWidth, 1.5);
    _syncDanmakuGlobalCache();
  }

  double _readDouble(String key, double defaultValue) {
    final dynamic value = GStrorage.localCache.get(
      key,
      defaultValue: defaultValue,
    );
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  void _syncDanmakuGlobalCache() {
    final GlobalDataCache cache = GlobalDataCache();
    cache.isOpenDanmu = player.isOpenDanmu.value;
    cache.blockTypes = List<dynamic>.from(player.blockTypes);
    cache.showArea = player.showArea;
    cache.danmakuDurationVal = player.danmakuDurationVal;
    cache.fontSizeVal = player.fontSizeVal;
    cache.opacityVal = player.opacityVal;
    cache.strokeWidth = player.strokeWidth;
  }

  Future<void> cyclePlaybackSpeed() async {
    const List<double> speeds = <double>[1.0, 1.25, 1.5, 2.0];
    final double current = player.playbackSpeed;
    final int index = speeds.indexWhere((double speed) {
      return (speed - current).abs() < 0.01;
    });
    final double next = speeds[(index + 1) % speeds.length];
    await player.setPlaybackSpeed(next);
    playbackSpeed.value = next;
    menuVisible.value = true;
    controlsVisible.value = true;
  }

  Future<void> toggleThinProgress() async {
    thinProgressEnabled.value = !thinProgressEnabled.value;
    await GStrorage.setting.put(
      SettingBoxKey.tvPlayerThinProgressEnable,
      thinProgressEnabled.value,
    );
    menuVisible.value = true;
    controlsVisible.value = true;
  }

  void toggleMenu() {
    menuVisible.value = !menuVisible.value;
    if (menuVisible.value) {
      menuIndex.value = 0;
    }
    controlsVisible.value = true;
  }

  void closeMenu() {
    menuVisible.value = false;
  }

  void moveMenuSelection(int delta) {
    menuIndex.value =
        (menuIndex.value + delta + playerMenuItemCount) % playerMenuItemCount;
  }

  Future<void> activateMenuSelection({
    required void Function() exitPlayer,
  }) async {
    switch (menuIndex.value) {
      case 0:
        await toggleDanmaku();
        break;
      case 1:
        await cyclePlaybackSpeed();
        break;
      case 2:
        await toggleThinProgress();
        break;
      case 3:
        await cycleDanmakuArea();
        break;
      case 4:
        await cycleDanmakuDuration();
        break;
      case 5:
        await cycleDanmakuFontScale();
        break;
      case 6:
        await cycleDanmakuOpacity();
        break;
      case 7:
        await cycleDanmakuStroke();
        break;
      case 8:
        await toggleDanmakuBlock(5);
        break;
      case 9:
        await toggleDanmakuBlock(2);
        break;
      case 10:
        await toggleDanmakuBlock(4);
        break;
      case 11:
        await toggleDanmakuBlock(6);
        break;
      case 12:
        closeMenu();
        break;
      case 13:
        exitPlayer();
        break;
    }
  }

  Future<void> seekRelative(int seconds) async {
    final Duration target = player.position.value + Duration(seconds: seconds);
    await player.seekTo(target);
    controlsVisible.value = true;
  }

  Future<void> adjustVolume(double delta) async {
    final double next = (player.volume.value + delta).clamp(0.0, 1.0);
    await player.setVolume(next);
    volume.value = next;
    controlsVisible.value = true;
  }

  void toggleControls() {
    controlsVisible.value = !controlsVisible.value;
    player.controls = controlsVisible.value;
  }

  void _watchAutoNext() {
    if (!isRecommendSource) {
      return;
    }
    _positionWorker = ever<Duration>(player.position, (Duration position) {
      final Duration duration = player.duration.value;
      if (_switchingVideo ||
          loading.value ||
          duration.inSeconds < 10 ||
          position.inSeconds < duration.inSeconds - 2) {
        return;
      }
      _switchingVideo = true;
      playNextRecommend().whenComplete(() {
        _switchingVideo = false;
      });
    });
  }

  void _watchAntiAddiction() {
    _statusWorker = ever<PlayerStatus>(
      player.playerStatus.status,
      (_) => _syncAntiAddictionWithPlayer(),
    );
  }

  void _syncAntiAddictionWithPlayer() {
    if (!Get.isRegistered<TvAntiAddictionController>()) {
      return;
    }
    final TvAntiAddictionController anti =
        Get.find<TvAntiAddictionController>();
    if (loading.value || error.value != null) {
      anti.stopCounting();
      return;
    }
    if (player.playerStatus.playing) {
      anti.startCounting(
        pausePlayback: () => player.pause(),
        resumePlayback: () => player.play(),
      );
    } else {
      anti.stopCounting();
    }
  }

  @override
  void onInit() {
    super.onInit();
    _readRouteParams();
    _watchAutoNext();
    _watchAntiAddiction();
    initPlayer();
  }

  @override
  void onClose() {
    _positionWorker?.dispose();
    _statusWorker?.dispose();
    if (Get.isRegistered<TvAntiAddictionController>()) {
      Get.find<TvAntiAddictionController>().stopCounting();
    }
    player.dispose();
    super.onClose();
  }
}
