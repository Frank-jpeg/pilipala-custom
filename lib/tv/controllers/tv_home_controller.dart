import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/home/rcmd/result.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/utils/tv_video_mapper.dart';
import 'package:pilipala/utils/storage.dart';

class TvHomeController extends GetxController {
  final RxList<RecVideoItemAppModel> items = <RecVideoItemAppModel>[].obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxInt selectedIndex = 0.obs;
  final RxBool autoFullscreenArmed = false.obs;
  final RxBool previewPreparing = false.obs;
  final RxBool previewReady = false.obs;
  final RxnString previewError = RxnString();
  final RxnString previewBvid = RxnString();

  Timer? _fullscreenTimer;
  Timer? _previewTimer;
  Player? _previewPlayer;
  VideoController? _previewVideoController;
  int _fullscreenGeneration = 0;
  int _previewGeneration = 0;
  bool _recommendStageActive = true;

  VideoController? get previewVideoController => _previewVideoController;
  TvAntiAddictionController get _antiAddiction =>
      Get.find<TvAntiAddictionController>();

  bool get _canAutoActOnRecommend =>
      !isClosed && _recommendStageActive && items.isNotEmpty;

  bool get autoFullscreenEnabled => GStrorage.setting
      .get(SettingBoxKey.tvAutoFullscreenEnable, defaultValue: true) as bool;

  int get autoFullscreenDelaySeconds {
    final int value = GStrorage.setting
        .get(SettingBoxKey.tvAutoFullscreenDelay, defaultValue: 15) as int;
    return value.clamp(5, 60);
  }

  List<TvVideoCardData> get videos =>
      items.map(TvVideoMapper.fromRcmd).toList(growable: false);

  TvVideoCardData? get selectedVideo {
    final List<TvVideoCardData> list = videos;
    if (list.isEmpty) {
      return null;
    }
    return list[selectedIndex.value.clamp(0, list.length - 1)];
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final bool loginStatus = Get.find<TvSessionController>().isLogin.value;
      final dynamic res = await VideoHttp.rcmdVideoListApp(
        loginStatus: loginStatus,
        freshIdx: 0,
      );
      if (res['status'] == true) {
        items.value = List<RecVideoItemAppModel>.from(res['data'] as List);
        if (items.isNotEmpty) {
          selectedIndex.value = 0;
          schedulePreviewAutoplay(immediate: true);
          scheduleAutoFullscreen();
        }
      } else {
        error.value = res['msg']?.toString() ?? '加载推荐失败';
      }
    } catch (e) {
      error.value = '加载推荐失败: $e';
      SmartDialog.showToast(error.value!);
    } finally {
      loading.value = false;
    }
  }

  void selectIndex(int index, {bool schedule = true}) {
    if (items.isEmpty) {
      selectedIndex.value = 0;
      return;
    }
    selectedIndex.value = index.clamp(0, items.length - 1);
    if (schedule) {
      schedulePreviewAutoplay();
      scheduleAutoFullscreen();
    }
  }

  void selectNext({bool schedule = true}) {
    if (items.isEmpty) {
      return;
    }
    selectIndex((selectedIndex.value + 1) % items.length, schedule: schedule);
  }

  void selectPrevious({bool schedule = true}) {
    if (items.isEmpty) {
      return;
    }
    selectIndex(
      selectedIndex.value == 0 ? items.length - 1 : selectedIndex.value - 1,
      schedule: schedule,
    );
  }

  void openSelectedDetail() {
    final TvVideoCardData? data = selectedVideo;
    if (data == null || data.bvid.isEmpty) {
      return;
    }
    cancelAutoFullscreen();
    pausePreview();
    Get.toNamed(
      '${TvRoutes.video}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}',
    )?.whenComplete(() {
      markRecommendStageActive(true);
      schedulePreviewAutoplay(immediate: true);
      scheduleAutoFullscreen();
    });
  }

  void playSelected({bool immersive = false}) {
    final TvVideoCardData? data = selectedVideo;
    if (data == null || data.bvid.isEmpty || data.cid <= 0) {
      return;
    }
    final int startSeconds = _previewStartSecondsFor(data);
    cancelAutoFullscreen();
    pausePreview();
    Get.toNamed(
      '${TvRoutes.player}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}&source=recommend&index=${selectedIndex.value}&start=$startSeconds',
    )?.whenComplete(() {
      markRecommendStageActive(true);
      schedulePreviewAutoplay(immediate: true);
      scheduleAutoFullscreen();
    });
  }

  int _previewStartSecondsFor(TvVideoCardData data) {
    if (previewBvid.value != data.bvid) {
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
    schedulePreviewAutoplay(immediate: true);
    scheduleAutoFullscreen();
  }

  void schedulePreviewAutoplay({bool immediate = false}) {
    _previewTimer?.cancel();
    final TvVideoCardData? data = selectedVideo;
    if (!_recommendStageActive ||
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

  Future<void> _startPreview(
    TvVideoCardData data,
    int generation,
  ) async {
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
    } catch (e) {
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
          'audio-files', audioUrl.replaceAll(':', r'\:'));
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
        playSelected(immersive: true);
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
    if (!_recommendStageActive) {
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

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    cancelAutoFullscreen();
    _previewTimer?.cancel();
    _antiAddiction.stopCounting();
    _previewPlayer?.dispose();
    super.onClose();
  }
}
