import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/home/rcmd/result.dart';
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

  Timer? _fullscreenTimer;

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
    Get.toNamed(
      '${TvRoutes.video}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}',
    )?.whenComplete(scheduleAutoFullscreen);
  }

  void playSelected({bool immersive = false}) {
    final TvVideoCardData? data = selectedVideo;
    if (data == null || data.bvid.isEmpty || data.cid <= 0) {
      return;
    }
    cancelAutoFullscreen();
    Get.toNamed(
      '${TvRoutes.player}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}&source=recommend&index=${selectedIndex.value}',
    )?.whenComplete(scheduleAutoFullscreen);
  }

  void scheduleAutoFullscreen() {
    cancelAutoFullscreen();
    if (!autoFullscreenEnabled ||
        items.isEmpty ||
        Get.currentRoute != TvRoutes.shell) {
      return;
    }
    Future<void>.delayed(Duration.zero, () {
      if (isClosed || _fullscreenTimer != null) {
        return;
      }
      autoFullscreenArmed.value = true;
      _fullscreenTimer =
          Timer(Duration(seconds: autoFullscreenDelaySeconds), () {
        autoFullscreenArmed.value = false;
        playSelected(immersive: true);
      });
    });
  }

  void cancelAutoFullscreen() {
    _fullscreenTimer?.cancel();
    _fullscreenTimer = null;
    autoFullscreenArmed.value = false;
  }

  void applyAutoFullscreenSettings() {
    if (Get.currentRoute != TvRoutes.shell) {
      cancelAutoFullscreen();
      return;
    }
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
    super.onClose();
  }
}
