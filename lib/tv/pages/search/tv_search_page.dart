import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/tv/controllers/tv_search_controller.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/utils/tv_video_mapper.dart';
import 'package:pilipala/tv/widgets/tv_async_state.dart';
import 'package:pilipala/tv/widgets/tv_focusable_button.dart';
import 'package:pilipala/tv/widgets/tv_poster_grid.dart';

class TvSearchPage extends StatefulWidget {
  const TvSearchPage({super.key});

  @override
  State<TvSearchPage> createState() => _TvSearchPageState();
}

class _TvSearchPageState extends State<TvSearchPage> {
  final TvSearchController _controller = Get.put(TvSearchController());
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _firstResultFocusNode = FocusNode();

  Future<void> _runSearch() async {
    _inputFocusNode.unfocus();
    await _controller.search(_textController.text);
    if (!mounted || _controller.results.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _firstResultFocusNode.canRequestFocus) {
        _firstResultFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        child: Obx(
          () => ListView(
            children: <Widget>[
              Row(
                children: <Widget>[
                  TvFocusableButton(
                    label: '返回',
                    icon: Icons.arrow_back,
                    onPressed: Get.back,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '搜索',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _inputFocusNode,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '输入视频关键词',
                      ),
                      onSubmitted: (_) => _runSearch(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TvFocusableButton(
                    label: '搜索',
                    icon: Icons.search,
                    onPressed: _runSearch,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_controller.resultSource.value == 'webFallback' &&
                  _controller.results.isNotEmpty) ...<Widget>[
                const Text(
                  'TV 搜索暂不可用，已显示兼容搜索结果',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
              ],
              if (_controller.hotItems.isNotEmpty) ...<Widget>[
                const Text(
                  '热门搜索',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _controller.hotItems.take(10).map((item) {
                    return TvFocusableButton(
                      label: item.showName ?? item.keyword ?? '',
                      onPressed: () {
                        final String value = item.keyword ?? '';
                        _textController.text = value;
                        _runSearch();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
              ],
              TvAsyncState(
                loading: _controller.loadingSearch.value,
                error: _controller.error.value,
                empty: _controller.keyword.value.isNotEmpty &&
                    _controller.results.isEmpty &&
                    !_controller.loadingSearch.value,
                emptyText: '没有搜到内容',
                child: _controller.results.isEmpty
                    ? const SizedBox.shrink()
                    : TvPosterGrid(
                        items: _controller.results
                            .map(TvVideoMapper.fromSearch)
                            .toList(growable: false),
                        initialAutofocus: false,
                        firstFocusNode: _firstResultFocusNode,
                        onTap: (data) {
                          Get.toNamed(
                            '${TvRoutes.video}?bvid=${data.bvid}&cid=${data.cid}&aid=${data.aid}',
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _firstResultFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }
}
