import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/short_video/item.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/plugin/pl_player/index.dart';
import 'package:pilipala/utils/id_utils.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:pilipala/utils/utils.dart';
import 'package:pilipala/utils/video_utils.dart';

class ShortVideoController extends GetxController {
  final PageController pageController = PageController();
  RxList<ShortVideoItem> videoList = <ShortVideoItem>[].obs;
  RxBool isLoading = false.obs;
  RxBool isPreparing = false.obs;
  RxString errorMessage = ''.obs;
  RxString activeBvid = ''.obs;
  RxInt currentIndex = 0.obs;

  PlPlayerController plPlayerController =
      PlPlayerController(videoType: 'story');
  Box setting = GStrorage.setting;
  Box userInfoCache = GStrorage.userInfo;
  Box localCache = GStrorage.localCache;

  int _freshIdx = 0;
  int _playToken = 0;
  bool _isTabActive = false;

  late bool enableCDN;
  late bool enableHA;
  late int? cacheVideoQa;
  late String cacheDecode;
  late int defaultAudioQa;

  @override
  void onInit() {
    super.onInit();
    enableCDN = setting.get(SettingBoxKey.enableCDN, defaultValue: true);
    enableHA = setting.get(SettingBoxKey.enableHA, defaultValue: false);
    cacheVideoQa = setting.get(SettingBoxKey.defaultVideoQa);
    cacheDecode = setting.get(SettingBoxKey.defaultDecode,
        defaultValue: VideoDecodeFormats.values.last.code);
    defaultAudioQa = setting.get(SettingBoxKey.defaultAudioQa,
        defaultValue: AudioQuality.hiRes.code);
  }

  void setTabActive(bool active) {
    if (_isTabActive == active) {
      return;
    }
    _isTabActive = active;
    if (active) {
      if (videoList.isEmpty) {
        queryFeed(type: 'init');
      } else {
        playIndex(currentIndex.value);
      }
    } else {
      pauseCurrent();
    }
  }

  Future queryFeed({String type = 'onLoad'}) async {
    if (isLoading.value) {
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';

    if (type == 'onRefresh') {
      _freshIdx = 0;
      activeBvid.value = '';
      currentIndex.value = 0;
    }

    final res = await VideoHttp.shortVideoFeed(freshIdx: _freshIdx);
    if (res['status']) {
      final List<ShortVideoItem> list =
          List<ShortVideoItem>.from(res['data'] ?? []);
      _freshIdx = res['nextFreshIdx'] ?? (_freshIdx + 1);
      if (type == 'onRefresh') {
        videoList.value = list;
        if (pageController.hasClients) {
          pageController.jumpToPage(0);
        }
      } else {
        videoList.addAll(list);
      }
      if (_isTabActive && videoList.isNotEmpty && activeBvid.value.isEmpty) {
        await playIndex(currentIndex.value);
      }
    } else {
      errorMessage.value = res['msg']?.toString() ?? '加载失败';
    }
    isLoading.value = false;
  }

  Future onRefresh() async {
    await pauseCurrent();
    await queryFeed(type: 'onRefresh');
  }

  Future onLoad() async {
    await queryFeed();
  }

  Future<void> animateToTop() async {
    if (!pageController.hasClients) {
      return;
    }
    await pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> onPageChanged(int index) async {
    currentIndex.value = index;
    if (index >= videoList.length - 3 && !isLoading.value) {
      queryFeed();
    }
    if (_isTabActive) {
      await playIndex(index);
    }
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= videoList.length) {
      return;
    }
    final int token = ++_playToken;
    final ShortVideoItem item = videoList[index];
    if (item.bvid == null || item.cid == null) {
      return;
    }

    _ensurePlayerController();
    isPreparing.value = true;
    errorMessage.value = '';
    try {
      final result = await VideoHttp.videoUrl(
          cid: item.cid!, bvid: item.bvid!, qn: cacheVideoQa);
      if (token != _playToken) {
        return;
      }
      if (!result['status']) {
        errorMessage.value = result['msg']?.toString() ?? '播放地址获取失败';
        return;
      }

      final PlayUrlModel data = result['data'];
      final _ShortPlaySource source = _resolvePlaySource(data);
      await plPlayerController.setDataSource(
        DataSource(
          videoSource: source.videoUrl,
          audioSource: source.audioUrl,
          type: DataSourceType.network,
          httpHeaders: {
            'user-agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Mobile Safari/537.36',
            'referer': HttpString.baseUrl,
          },
        ),
        enableHA: enableHA,
        duration: Duration(
          milliseconds: data.timeLength ?? (item.duration ?? 0) * 1000,
        ),
        direction: 'vertical',
        bvid: item.bvid!,
        cid: item.cid!,
        enableHeart: _enableHeart,
        isFirstTime: false,
        autoplay: _isTabActive,
      );
      plPlayerController.videoFit.value = BoxFit.contain;
      activeBvid.value = item.bvid!;
      if (_isTabActive) {
        await plPlayerController.play();
      }
    } catch (err) {
      errorMessage.value = err.toString();
    } finally {
      if (token == _playToken) {
        isPreparing.value = false;
      }
    }
  }

  Future<void> pauseCurrent() async {
    await plPlayerController.pause();
  }

  Future<void> openDetail(ShortVideoItem item) async {
    if (item.bvid == null || item.cid == null) {
      SmartDialog.showToast('视频信息不完整');
      return;
    }
    await pauseCurrent();
    await Get.toNamed('/video?bvid=${item.bvid}&cid=${item.cid}', arguments: {
      'pic': item.pic,
      'heroTag': Utils.makeHeroTag(item.aid ?? IdUtils.bv2av(item.bvid!)),
    });
    activeBvid.value = '';
    _ensurePlayerController();
    if (_isTabActive && videoList.isNotEmpty) {
      await playIndex(currentIndex.value);
    }
  }

  _ShortPlaySource _resolvePlaySource(PlayUrlModel data) {
    if (data.durl != null && data.durl!.isNotEmpty) {
      return _ShortPlaySource(videoUrl: data.durl!.first.url!, audioUrl: '');
    }

    final List<VideoItem> allVideosList = data.dash?.video ?? [];
    if (allVideosList.isEmpty) {
      throw '未找到可播放视频流';
    }

    final int currentHighVideoQa =
        allVideosList.first.quality?.code ?? allVideosList.first.id ?? 80;
    cacheVideoQa ??= currentHighVideoQa;
    int resVideoQa = currentHighVideoQa;
    final List<int> acceptQuality = data.acceptQuality ?? [currentHighVideoQa];
    if (cacheVideoQa! <= currentHighVideoQa) {
      final List<int> numbers =
          acceptQuality.where((e) => e <= currentHighVideoQa).toList();
      resVideoQa = numbers.isEmpty
          ? currentHighVideoQa
          : Utils.findClosestNumber(cacheVideoQa!, numbers);
    }

    final List<VideoItem> videosList = allVideosList
        .where((e) => (e.quality?.code ?? e.id) == resVideoQa)
        .toList();
    VideoDecodeFormats? currentDecodeFormats =
        VideoDecodeFormatsCode.fromString(cacheDecode);
    VideoItem firstVideo;
    try {
      firstVideo = videosList.firstWhere(
        (e) => e.codecs!.startsWith(currentDecodeFormats!.code),
      );
    } catch (_) {
      firstVideo =
          videosList.isNotEmpty ? videosList.first : allVideosList.first;
    }

    final List<AudioItem> audiosList = [...(data.dash?.audio ?? [])];
    if (data.dash?.dolby?.audio?.isNotEmpty == true) {
      audiosList.insert(0, data.dash!.dolby!.audio!.first);
    }
    if (data.dash?.flac?.audio != null) {
      audiosList.insert(0, data.dash!.flac!.audio!);
    }

    AudioItem? firstAudio;
    if (audiosList.isNotEmpty) {
      final List<int> numbers = audiosList
          .where((item) => item.id != null)
          .map((item) => item.id!)
          .toList();
      final int closestNumber = numbers.isEmpty
          ? audiosList.first.id!
          : Utils.findClosestNumber(defaultAudioQa, numbers);
      firstAudio = audiosList.firstWhere(
        (e) => e.id == closestNumber,
        orElse: () => audiosList.first,
      );
    }

    return _ShortPlaySource(
      videoUrl: enableCDN
          ? VideoUtils.getCdnUrl(firstVideo)
          : (firstVideo.backupUrl ?? firstVideo.baseUrl!),
      audioUrl: firstAudio == null
          ? ''
          : enableCDN
              ? VideoUtils.getCdnUrl(firstAudio)
              : (firstAudio.backupUrl ?? firstAudio.baseUrl ?? ''),
    );
  }

  bool get _enableHeart =>
      userInfoCache.get('userInfoCache') != null &&
      localCache.get(LocalCacheKey.historyPause) != true;

  void _ensurePlayerController() {
    if (plPlayerController.videoPlayerController == null &&
        plPlayerController.playerCount.value == 0) {
      plPlayerController = PlPlayerController(videoType: 'story');
    }
  }

  @override
  void onClose() {
    _playToken += 1;
    pageController.dispose();
    plPlayerController.dispose(type: 'all');
    super.onClose();
  }
}

class _ShortPlaySource {
  _ShortPlaySource({
    required this.videoUrl,
    required this.audioUrl,
  });

  final String videoUrl;
  final String audioUrl;
}
