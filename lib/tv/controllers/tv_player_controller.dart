import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/plugin/pl_player/controller.dart';
import 'package:pilipala/plugin/pl_player/models/data_source.dart';

class TvPlayerController extends GetxController {
  final PlPlayerController player = PlPlayerController(videoType: 'archive');
  final RxBool loading = true.obs;
  final RxBool controlsVisible = true.obs;
  final RxDouble volume = 1.0.obs;
  final RxnString error = RxnString();

  String get bvid => Get.parameters['bvid'] ?? '';
  int get cid => int.tryParse(Get.parameters['cid'] ?? '0') ?? 0;

  Future<void> initPlayer() async {
    loading.value = true;
    error.value = null;
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
      final String audioUrl =
          dashAudios != null && dashAudios.isNotEmpty ? dashAudios.first.baseUrl ?? '' : '';
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
        bvid: bvid,
        cid: cid,
      );
      await player.getCurrentVolume();
      volume.value = player.volume.value;
    } catch (e) {
      error.value = '播放器初始化失败: $e';
      SmartDialog.showToast(error.value!);
    } finally {
      loading.value = false;
    }
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

  @override
  void onInit() {
    super.onInit();
    initPlayer();
  }

  @override
  void onClose() {
    player.dispose();
    super.onClose();
  }
}
