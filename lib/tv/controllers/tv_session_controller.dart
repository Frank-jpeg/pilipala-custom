import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/models/user/info.dart';
import 'package:pilipala/utils/storage.dart';

class TvSessionController extends GetxController {
  final Rxn<UserInfoData> userInfo = Rxn<UserInfoData>();
  final RxBool isLogin = false.obs;
  final RxInt refreshTick = 0.obs;

  Future<void> restoreUser() async {
    userInfo.value = GStrorage.userInfo.get('userInfoCache');
    isLogin.value = userInfo.value?.mid != null;
  }

  Future<bool> syncUserFromServer({
    bool silent = false,
    bool clearOnFailure = true,
  }) async {
    try {
      final dynamic result = await UserHttp.userInfo();
      if (result['status'] == true && result['data']?.isLogin == true) {
        await applyLoginUser(result['data'] as UserInfoData);
        return true;
      }
      if (clearOnFailure) {
        await clearLoginState();
      }
      if (!silent) {
        SmartDialog.showToast(result['msg']?.toString() ?? '登录状态无效');
      }
      return false;
    } catch (error) {
      if (!silent) {
        SmartDialog.showToast('同步登录失败: $error');
      }
      return false;
    }
  }

  Future<void> clearLoginState() async {
    userInfo.value = null;
    isLogin.value = false;
    refreshTick.value++;
    await GStrorage.userInfo.delete('userInfoCache');
    await Request.cookieManager.cookieJar.deleteAll();
    Request.dio.options.headers['cookie'] = '';
  }

  Future<void> applyLoginUser(UserInfoData user) async {
    Box<dynamic> userInfoCache = GStrorage.userInfo;
    if (!userInfoCache.isOpen) {
      userInfoCache = await Hive.openBox<dynamic>('userInfo');
    }
    await userInfoCache.put('userInfoCache', user);
    userInfo.value = user;
    isLogin.value = true;
    refreshTick.value++;
  }
}
