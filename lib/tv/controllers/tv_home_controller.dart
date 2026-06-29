import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/home/rcmd/result.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';

class TvHomeController extends GetxController {
  final RxList<RecVideoItemAppModel> items = <RecVideoItemAppModel>[].obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();

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

  @override
  void onInit() {
    super.onInit();
    load();
  }
}
