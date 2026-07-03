import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pilipala/utils/login.dart';
import 'package:url_launcher/url_launcher.dart';
import 'controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewPage extends StatefulWidget {
  const WebviewPage({super.key});

  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  static const MethodChannel _tvPointerChannel =
      MethodChannel('pilipala/tv_pointer');
  static const double _pointerRadius = 13;
  static const double _pointerStep = 30;

  final WebviewController _webviewController = Get.put(WebviewController());
  final FocusNode _tvPointerFocusNode = FocusNode(debugLabel: 'tvWebPointer');
  final GlobalKey _webViewAreaKey = GlobalKey();
  Offset _tvPointer = Offset.zero;
  Size _tvPointerBounds = Size.zero;

  bool get _isTvLogin => _webviewController.type.value == 'tvLogin';

  @override
  void dispose() {
    _tvPointerFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleTvPointerKey(FocusNode node, KeyEvent event) {
    if (!_isTvLogin || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _moveTvPointer(const Offset(-_pointerStep, 0));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _moveTvPointer(const Offset(_pointerStep, 0));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveTvPointer(const Offset(0, -_pointerStep));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveTvPointer(const Offset(0, _pointerStep));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _tapTvPointer();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveTvPointer(Offset delta) {
    if (_tvPointerBounds == Size.zero) {
      return;
    }
    setState(() {
      _tvPointer = _clampTvPointer(_tvPointer + delta, _tvPointerBounds);
    });
  }

  Offset _clampTvPointer(Offset value, Size bounds) {
    const double minX = _pointerRadius;
    const double minY = _pointerRadius;
    final double maxX = bounds.width > _pointerRadius * 2
        ? bounds.width - _pointerRadius
        : minX;
    final double maxY = bounds.height > _pointerRadius * 2
        ? bounds.height - _pointerRadius
        : minY;
    return Offset(
      value.dx.clamp(minX, maxX).toDouble(),
      value.dy.clamp(minY, maxY).toDouble(),
    );
  }

  void _syncTvPointerBounds(Size bounds) {
    if (bounds.width <= 0 || bounds.height <= 0 || _tvPointerBounds == bounds) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        final bool firstLayout = _tvPointerBounds == Size.zero;
        _tvPointerBounds = bounds;
        _tvPointer = firstLayout
            ? Offset(bounds.width / 2, bounds.height / 2)
            : _clampTvPointer(_tvPointer, bounds);
      });
      _tvPointerFocusNode.requestFocus();
    });
  }

  Future<void> _tapTvPointer() async {
    final BuildContext? areaContext = _webViewAreaKey.currentContext;
    final RenderObject? renderObject = areaContext?.findRenderObject();
    if (areaContext == null || renderObject is! RenderBox) {
      return;
    }
    final Offset global = renderObject.localToGlobal(_tvPointer);
    final double devicePixelRatio = MediaQuery.of(areaContext).devicePixelRatio;
    try {
      final bool? handled = await _tvPointerChannel.invokeMethod<bool>(
        'tap',
        <String, double>{
          'x': global.dx * devicePixelRatio,
          'y': global.dy * devicePixelRatio,
        },
      );
      if (handled != true) {
        await _tapTvPointerByJavaScript(renderObject.size);
      }
    } catch (_) {
      await _tapTvPointerByJavaScript(renderObject.size);
    } finally {
      if (mounted) {
        _tvPointerFocusNode.requestFocus();
      }
    }
  }

  Future<void> _tapTvPointerByJavaScript(Size bounds) async {
    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }
    final double xRatio = (_tvPointer.dx / bounds.width).clamp(0.0, 1.0);
    final double yRatio = (_tvPointer.dy / bounds.height).clamp(0.0, 1.0);
    await _webviewController.controller.runJavaScript('''
(function () {
  const x = window.innerWidth * $xRatio;
  const y = window.innerHeight * $yRatio;
  const target = document.elementFromPoint(x, y);
  if (!target) return;
  const base = {
    bubbles: true,
    cancelable: true,
    view: window,
    clientX: x,
    clientY: y,
    screenX: x,
    screenY: y
  };
  if (window.PointerEvent) {
    target.dispatchEvent(new PointerEvent('pointerdown', Object.assign({}, base, { pointerId: 1, pointerType: 'mouse', isPrimary: true })));
    target.dispatchEvent(new PointerEvent('pointerup', Object.assign({}, base, { pointerId: 1, pointerType: 'mouse', isPrimary: true })));
  }
  target.dispatchEvent(new MouseEvent('mousedown', base));
  target.dispatchEvent(new MouseEvent('mouseup', base));
  target.dispatchEvent(new MouseEvent('click', base));
  if (typeof target.click === 'function') target.click();
})();
''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          title: Text(
            _webviewController.pageTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          actions: [
            const SizedBox(width: 4),
            IconButton(
              onPressed: () {
                _webviewController.controller.reload();
              },
              icon: Icon(Icons.refresh_outlined,
                  color: Theme.of(context).colorScheme.primary),
            ),
            IconButton(
              onPressed: () {
                launchUrl(Uri.parse(_webviewController.url));
              },
              icon: Icon(Icons.open_in_browser_outlined,
                  color: Theme.of(context).colorScheme.primary),
            ),
            Obx(
              () => (_webviewController.type.value == 'login' ||
                      _webviewController.type.value == 'tvLogin')
                  ? TextButton(
                      onPressed: () {
                        if (_webviewController.type.value == 'tvLogin') {
                          _webviewController.confirmTvLogin();
                        } else {
                          LoginUtils.confirmLogin(null, _webviewController);
                        }
                      },
                      child: const Text('刷新登录状态'),
                    )
                  : const SizedBox(),
            ),
            const SizedBox(width: 12)
          ],
        ),
        body: Column(
          children: [
            Obx(
              () => AnimatedContainer(
                curve: Curves.easeInOut,
                duration: const Duration(milliseconds: 350),
                height: _webviewController.loadShow.value ? 4 : 0,
                child: LinearProgressIndicator(
                  key: ValueKey(_webviewController.loadProgress),
                  value: _webviewController.loadProgress / 100,
                ),
              ),
            ),
            if (_webviewController.type.value == 'login' ||
                _webviewController.type.value == 'tvLogin')
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.onInverseSurface,
                padding: const EdgeInsets.only(
                    left: 12, right: 12, top: 6, bottom: 6),
                child: const Text('登录成功未自动跳转?  请点击右上角「刷新登录状态」'),
              ),
            Expanded(
              child: Obx(
                () {
                  final bool tvPointerEnabled = _isTvLogin;
                  return Focus(
                    focusNode: _tvPointerFocusNode,
                    autofocus: tvPointerEnabled,
                    canRequestFocus: tvPointerEnabled,
                    onKeyEvent: _handleTvPointerKey,
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        final Size bounds = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        if (tvPointerEnabled) {
                          _syncTvPointerBounds(bounds);
                        }
                        return SizedBox.expand(
                          key: _webViewAreaKey,
                          child: Stack(
                            children: <Widget>[
                              WebViewWidget(
                                controller: _webviewController.controller,
                              ),
                              if (tvPointerEnabled) ...<Widget>[
                                Positioned(
                                  left: _tvPointer.dx - _pointerRadius,
                                  top: _tvPointer.dy - _pointerRadius,
                                  child: const IgnorePointer(
                                    child: _TvPointerCursor(),
                                  ),
                                ),
                                const Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: IgnorePointer(
                                    child: _TvPointerHint(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ));
  }
}

class _TvPointerCursor extends StatelessWidget {
  const _TvPointerCursor();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4BA0).withOpacity(0.28),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFF4BA0), width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xAAFF4BA0),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TvPointerHint extends StatelessWidget {
  const _TvPointerHint();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          '遥控器鼠标：方向键移动，OK 点击。登录成功后点右上角刷新登录状态。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
