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

  // 递增序号，用于丢弃过期搜索响应，避免慢的旧请求覆盖新请求的结果。
  int _searchSeq = 0;

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
    final int seq = ++_searchSeq;
    loadingSearch.value = true;
    error.value = null;
    try {
      final dynamic tvRes = await SearchHttp.tvSearchVideo(
        keyword: value,
        page: 1,
      );
      if (seq != _searchSeq) {
        // 已有更新的搜索发出，丢弃这次过期结果。
        return;
      }
      dynamic effectiveRes = tvRes;
      if (tvRes is Map && tvRes['status'] == true) {
        final dynamic tvData = tvRes['data'];
        if (tvData is SearchVideoModel &&
            (tvData.list ?? <SearchVideoItemModel>[]).isEmpty) {
          effectiveRes = await SearchHttp.searchByType(
            searchType: SearchType.video,
            keyword: value,
            page: 1,
          );
        }
      } else {
        effectiveRes = await SearchHttp.searchByType(
          searchType: SearchType.video,
          keyword: value,
          page: 1,
        );
      }
      if (seq != _searchSeq) {
        // 已有更新的搜索发出，丢弃这次过期结果。
        return;
      }
      if (effectiveRes is! Map) {
        results.clear();
        error.value = '搜索失败: 返回数据异常';
        SmartDialog.showToast(error.value!);
        return;
      }
      if (effectiveRes['status'] == true) {
        final dynamic data = effectiveRes['data'];
        if (data is SearchVideoModel) {
          results.value = data.list ?? <SearchVideoItemModel>[];
        } else {
          results.clear();
        }
      } else {
        error.value = effectiveRes['msg']?.toString() ?? '搜索失败';
        SmartDialog.showToast(error.value!);
      }
    } catch (e) {
      if (seq != _searchSeq) {
        return;
      }
      error.value = '搜索失败: $e';
      SmartDialog.showToast(error.value!);
    } finally {
      if (seq == _searchSeq) {
        loadingSearch.value = false;
      }
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadHot();
  }
}
