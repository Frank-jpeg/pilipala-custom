import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_home_controller.dart';
import 'package:pilipala/utils/storage.dart';

class TvSettingsController extends GetxController {
  final RxBool autoFullscreenEnabled = true.obs;
  final RxInt autoFullscreenDelaySeconds = 15.obs;

  static const int minDelaySeconds = 5;
  static const int maxDelaySeconds = 60;
  static const int delayStepSeconds = 5;

  void load() {
    autoFullscreenEnabled.value = GStrorage.setting.get(
      SettingBoxKey.tvAutoFullscreenEnable,
      defaultValue: true,
    ) as bool;
    final int delay = GStrorage.setting.get(
      SettingBoxKey.tvAutoFullscreenDelay,
      defaultValue: 15,
    ) as int;
    autoFullscreenDelaySeconds.value =
        delay.clamp(minDelaySeconds, maxDelaySeconds);
  }

  Future<void> toggleAutoFullscreen() async {
    autoFullscreenEnabled.value = !autoFullscreenEnabled.value;
    await GStrorage.setting.put(
      SettingBoxKey.tvAutoFullscreenEnable,
      autoFullscreenEnabled.value,
    );
    _applyHomeSettings();
  }

  Future<void> decreaseDelay() async {
    await _setDelay(autoFullscreenDelaySeconds.value - delayStepSeconds);
  }

  Future<void> increaseDelay() async {
    await _setDelay(autoFullscreenDelaySeconds.value + delayStepSeconds);
  }

  Future<void> _setDelay(int value) async {
    autoFullscreenDelaySeconds.value =
        value.clamp(minDelaySeconds, maxDelaySeconds);
    await GStrorage.setting.put(
      SettingBoxKey.tvAutoFullscreenDelay,
      autoFullscreenDelaySeconds.value,
    );
    _applyHomeSettings();
  }

  void _applyHomeSettings() {
    if (Get.isRegistered<TvHomeController>()) {
      Get.find<TvHomeController>().applyAutoFullscreenSettings();
    }
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }
}
