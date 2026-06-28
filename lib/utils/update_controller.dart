import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilipala/http/index.dart';
import 'package:pilipala/models/github/latest.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:pilipala/utils/utils.dart';

class UpdateController extends GetxController {
  RxBool hasUnreadUpdate = false.obs;
  RxString remoteVersion = ''.obs;

  LatestDataModel? remoteAppInfo;

  final Box setting = GStrorage.setting;
  final Box localCache = GStrorage.localCache;
  bool _checking = false;

  static UpdateController get to => Get.find<UpdateController>();

  Future<void> checkSilently({bool force = false}) async {
    if (_checking) {
      return;
    }
    if (!force &&
        setting.get(SettingBoxKey.autoUpdate, defaultValue: true) != true) {
      return;
    }

    _checking = true;
    try {
      final PackageInfo currentInfo = await PackageInfo.fromPlatform();
      final result = await Request().get(Api.latestApp, extra: {'ua': 'mob'});
      if (result.data == null || result.data.isEmpty) {
        return;
      }

      final LatestDataModel data = LatestDataModel.fromJson(result.data);
      if (data.tagName == null || data.tagName!.isEmpty) {
        return;
      }

      remoteAppInfo = data;
      remoteVersion.value = data.tagName!;
      final String seenVersion = localCache.get(
        LocalCacheKey.seenUpdateVersion,
        defaultValue: '',
      );
      hasUnreadUpdate.value =
          Utils.needUpdate(currentInfo.version, data.tagName!) &&
              seenVersion != data.tagName;
    } catch (_) {
      // 静默检查不打扰用户，网络或接口失败时下次再试。
    } finally {
      _checking = false;
    }
  }

  Future<void> markCurrentUpdateSeen() async {
    if (remoteVersion.value.isNotEmpty) {
      await localCache.put(
        LocalCacheKey.seenUpdateVersion,
        remoteVersion.value,
      );
    }
    hasUnreadUpdate.value = false;
  }

  Future<void> openAboutUpdatePage() async {
    await markCurrentUpdateSeen();
    Get.toNamed('/about', preventDuplicates: false);
  }
}
