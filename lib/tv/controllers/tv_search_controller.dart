import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/search.dart';
import 'package:pilipala/models/common/search_type.dart';
import 'package:pilipala/models/search/hot.dart';
import 'package:pilipala/models/search/result.dart';

class TvSearchController extends GetxController {
  final RxString keyword = ''.obs;
  final RxList<HotSearchItem> hotItems = <HotSearchItem>[].obs;
  final RxList<SearchVideoItemModel> results = <SearchVideoItemModel>[].obs;
  final RxBool loadingHot = false.obs;
  final RxBool loadingSearch = false.obs;
  final RxnString error = RxnString();

  Future<void> loadHot() async {
    loadingHot.value = true;
    error.value = null;
    try {
      final dynamic res = await SearchHttp.hotSearchList();
      if (res['status'] == true) {
        final HotSearchModel data = res['data'] as HotSearchModel;
        hotItems.value = data.list ?? <HotSearchItem>[];
      }
    } catch (e) {
      error.value = '加载热门搜索失败: $e';
    } finally {
      loadingHot.value = false;
    }
  }

  Future<void> search([String? nextKeyword]) async {
    final String value = (nextKeyword ?? keyword.value).trim();
    keyword.value = value;
    if (value.isEmpty) {
      results.clear();
      return;
    }
    loadingSearch.value = true;
    error.value = null;
    try {
      final dynamic res = await SearchHttp.searchByType(
        searchType: SearchType.video,
        keyword: value,
        page: 1,
      );
      if (res is! Map) {
        results.clear();
        error.value = '搜索失败: 返回数据异常';
        SmartDialog.showToast(error.value!);
        return;
      }
      if (res['status'] == true) {
        final dynamic data = res['data'];
        if (data is SearchVideoModel) {
          results.value = data.list ?? <SearchVideoItemModel>[];
        } else {
          results.clear();
        }
      } else {
        error.value = res['msg']?.toString() ?? '搜索失败';
        SmartDialog.showToast(error.value!);
      }
    } catch (e) {
      error.value = '搜索失败: $e';
      SmartDialog.showToast(error.value!);
    } finally {
      loadingSearch.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadHot();
  }
}
