import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/plugin/pl_player/controller.dart';
import 'package:pilipala/plugin/pl_player/models/data_source.dart';
import 'package:pilipala/plugin/pl_player/models/play_status.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/tv/models/tv_video_card_data.dart';

class TvPlayerController extends GetxController {
  final PlPlayerController player = PlPlayerController(videoType: 'archive');
  final RxBool loading = true.obs;
  final RxBool controlsVisible = true.obs;
  final RxDouble volume = 1.0.obs;
  final RxnString error = RxnString();
  final RxnString title = RxnString();

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
    try {
      if (bvid.isEmpty || cid <= 0) {
        error.value = '播放参数缺失';
        return;
      }
      final dynamic res = await VideoHttp.videoUrl(
        bvid: bvid,
        cid: cid,
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
        bvid: bvid,
        cid: cid,
      );
      await player.getCurrentVolume();
      volume.value = player.volume.value;
      _syncAntiAddictionWithPlayer();
    } catch (e) {
      error.value = '播放器初始化失败: $e';
      SmartDialog.showToast(error.value!);
    } finally {
      loading.value = false;
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
