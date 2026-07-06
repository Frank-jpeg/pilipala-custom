import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pilipala/tv/controllers/tv_login_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/widgets/tv_focusable_button.dart';

class TvLoginPage extends StatefulWidget {
  const TvLoginPage({super.key});

  @override
  State<TvLoginPage> createState() => _TvLoginPageState();
}

class _TvLoginPageState extends State<TvLoginPage> {
  static const MethodChannel _tvPointerChannel =
      MethodChannel('pilipala/tv_pointer');
  static const double _pointerRadius = 13;
  static const double _pointerStep = 30;

  final TvLoginController controller = Get.put(TvLoginController());
  final FocusNode _captchaPointerFocusNode =
      FocusNode(debugLabel: 'tvCaptchaPointer');
  final GlobalKey _captchaPointerAreaKey = GlobalKey();
  Offset _captchaPointer = Offset.zero;
  Size _captchaPointerBounds = Size.zero;

  @override
  void dispose() {
    _captchaPointerFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleCaptchaPointerKey(FocusNode node, KeyEvent event) {
    if (!controller.captchaVisible.value || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _moveCaptchaPointer(const Offset(-_pointerStep, 0));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _moveCaptchaPointer(const Offset(_pointerStep, 0));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveCaptchaPointer(const Offset(0, -_pointerStep));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveCaptchaPointer(const Offset(0, _pointerStep));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _tapCaptchaPointer();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveCaptchaPointer(Offset delta) {
    if (_captchaPointerBounds == Size.zero) {
      return;
    }
    setState(() {
      _captchaPointer =
          _clampCaptchaPointer(_captchaPointer + delta, _captchaPointerBounds);
    });
  }

  Offset _clampCaptchaPointer(Offset value, Size bounds) {
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

  void _syncCaptchaPointerBounds(Size bounds) {
    if (!controller.captchaVisible.value) {
      // 验证码关闭后重置，下次弹出按首帧处理（重新居中并夺取焦点）。
      _captchaPointerBounds = Size.zero;
      return;
    }
    // 关键：bounds 不变时直接返回，否则 build->postFrame setState->build 会每帧无限重建。
    if (bounds.width <= 0 ||
        bounds.height <= 0 ||
        _captchaPointerBounds == bounds) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.captchaVisible.value) {
        return;
      }
      setState(() {
        final bool firstLayout = _captchaPointerBounds == Size.zero;
        _captchaPointerBounds = bounds;
        _captchaPointer = firstLayout
            ? Offset(bounds.width / 2, bounds.height / 2)
            : _clampCaptchaPointer(_captchaPointer, bounds);
      });
      _captchaPointerFocusNode.requestFocus();
    });
  }

  Future<void> _tapCaptchaPointer() async {
    final BuildContext? areaContext = _captchaPointerAreaKey.currentContext;
    final RenderObject? renderObject = areaContext?.findRenderObject();
    if (areaContext == null || renderObject is! RenderBox) {
      return;
    }
    final Offset global = renderObject.localToGlobal(_captchaPointer);
    final double devicePixelRatio = MediaQuery.of(areaContext).devicePixelRatio;
    try {
      await _tvPointerChannel.invokeMethod<bool>(
        'tap',
        <String, double>{
          'x': global.dx * devicePixelRatio,
          'y': global.dy * devicePixelRatio,
        },
      );
    } catch (_) {
      SmartDialog.showToast('验证码点击失败，请重试');
    } finally {
      if (mounted && controller.captchaVisible.value) {
        _captchaPointerFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TvSessionController session = Get.find<TvSessionController>();
    return Obx(
      () {
        final bool blockBack = (controller.loginMode.value == 1 ||
                controller.loginMode.value == 2) &&
            !controller.isPhoneStep;
        return PopScope(
          canPop: !blockBack,
          onPopInvoked: (bool didPop) {
            if (!didPop && blockBack) {
              controller.previousSmsStepOrBack();
            }
          },
          child: Scaffold(
            body: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                _syncCaptchaPointerBounds(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );
                return Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 42, 56, 42),
                      child: session.isLogin.value
                          ? _LoggedInView(session: session)
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(
                                  width: 280,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      TvFocusableButton(
                                        autofocus: true,
                                        label: blockBack ? '返回手机号' : '返回',
                                        icon: Icons.arrow_back,
                                        onPressed: (controller
                                                        .loginMode.value ==
                                                    1 ||
                                                controller.loginMode.value == 2)
                                            ? controller.previousSmsStepOrBack
                                            : Get.back,
                                      ),
                                      const SizedBox(height: 42),
                                      _ModeButton(
                                        label: '扫码登录',
                                        icon: Icons.qr_code_2,
                                        selected:
                                            controller.loginMode.value == 0,
                                        onPressed: () =>
                                            controller.setLoginMode(0),
                                      ),
                                      const SizedBox(height: 14),
                                      _ModeButton(
                                        label: 'TV原生手机号',
                                        icon: Icons.phone_android,
                                        selected:
                                            controller.loginMode.value == 1,
                                        onPressed: () =>
                                            controller.setLoginMode(1),
                                      ),
                                      const SizedBox(height: 14),
                                      _ModeButton(
                                        label: '网页登录手机号',
                                        icon: Icons.pin_outlined,
                                        selected:
                                            controller.loginMode.value == 2,
                                        onPressed: () =>
                                            controller.setLoginMode(2),
                                      ),
                                      const SizedBox(height: 14),
                                      _ModeButton(
                                        label: '网页登录兜底',
                                        icon: Icons.language,
                                        selected:
                                            controller.loginMode.value == 3,
                                        onPressed: () =>
                                            controller.setLoginMode(3),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 52),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: switch (controller.loginMode.value) {
                                      0 =>
                                        _QrLoginPanel(controller: controller),
                                      1 => _SmsLoginPanel(
                                          controller: controller,
                                          nativeMode: true,
                                        ),
                                      2 => _SmsLoginPanel(
                                          controller: controller,
                                          nativeMode: false,
                                        ),
                                      _ =>
                                        _WebLoginPanel(controller: controller),
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (controller.captchaVisible.value)
                      Positioned.fill(
                        child: Focus(
                          focusNode: _captchaPointerFocusNode,
                          autofocus: true,
                          onKeyEvent: _handleCaptchaPointerKey,
                          child: SizedBox.expand(
                            key: _captchaPointerAreaKey,
                            child: Stack(
                              children: <Widget>[
                                Positioned(
                                  left: _captchaPointer.dx - _pointerRadius,
                                  top: _captchaPointer.dy - _pointerRadius,
                                  child: const IgnorePointer(
                                    child: _CaptchaPointerCursor(),
                                  ),
                                ),
                                const Positioned(
                                  left: 24,
                                  right: 24,
                                  bottom: 24,
                                  child: IgnorePointer(
                                    child: _CaptchaPointerHint(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LoggedInView extends StatelessWidget {
  const _LoggedInView({required this.session});

  final TvSessionController session;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 48,
            backgroundImage: session.userInfo.value?.face != null
                ? NetworkImage(session.userInfo.value!.face!)
                : null,
            child: session.userInfo.value?.face == null
                ? const Icon(Icons.account_circle, size: 60)
                : null,
          ),
          const SizedBox(height: 18),
          Text(
            session.userInfo.value?.uname ?? '已登录',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: <Widget>[
              TvFocusableButton(
                label: '返回',
                icon: Icons.check_circle_outline,
                autofocus: true,
                onPressed: Get.back,
              ),
              TvFocusableButton(
                label: '退出登录',
                icon: Icons.logout,
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121A2B),
          title: const Text('退出登录'),
          content: const Text('确认要退出当前账号吗？'),
          actions: <Widget>[
            TvFocusableButton(
              autofocus: true,
              icon: Icons.close,
              label: '取消',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TvFocusableButton(
              icon: Icons.logout,
              label: '退出登录',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await session.clearLoginState();
    SmartDialog.showToast('已退出登录');
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TvFocusableButton(
      label: selected ? '$label  ✓' : label,
      icon: icon,
      onPressed: onPressed,
    );
  }
}

class _QrLoginPanel extends StatelessWidget {
  const _QrLoginPanel({required this.controller});

  final TvLoginController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        key: const ValueKey<String>('qr'),
        title: '扫码登录',
        subtitle: '用哔哩哔哩 App 扫码后确认登录。扫码失败时，可以切到手机号登录或网页登录兜底。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 280,
              height: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: controller.qrUrl.value.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : QrImageView(
                      data: controller.qrUrl.value,
                      backgroundColor: Colors.white,
                    ),
            ),
            const SizedBox(height: 18),
            Text('二维码剩余 ${controller.validSeconds.value}s'),
            _ErrorText(error: controller.error.value),
            const SizedBox(height: 22),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: <Widget>[
                TvFocusableButton(
                  label: '刷新二维码',
                  icon: Icons.refresh,
                  onPressed: controller.startLogin,
                ),
                TvFocusableButton(
                  label: '检查登录状态',
                  icon: Icons.verified_user_outlined,
                  onPressed: controller.refreshLoginStatus,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsLoginPanel extends StatelessWidget {
  const _SmsLoginPanel({
    required this.controller,
    required this.nativeMode,
  });

  final TvLoginController controller;
  final bool nativeMode;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final bool phoneStep = controller.isPhoneStep;
        return _Panel(
          key: ValueKey<String>(nativeMode ? 'tvSms' : 'webSms'),
          title: nativeMode ? 'TV原生手机号登录' : '网页登录手机号',
          subtitle: nativeMode
              ? (phoneStep ? '输入手机号后直接获取短信验证码。' : '输入短信验证码完成 TV 原生登录。')
              : (phoneStep
                  ? '先输入手机号。遇到点选验证时会出现遥控器光标，方向键移动，OK 点击。'
                  : '输入短信验证码。重新获取验证码时若再弹验证，也可继续用遥控器光标点击。'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _InputPreview(
                      label: phoneStep ? '手机号' : '验证码',
                      value: phoneStep
                          ? (controller.phoneInput.value.isEmpty
                              ? '请输入手机号'
                              : controller.maskedPhone)
                          : controller.smsCodeDisplay,
                      progress: phoneStep
                          ? '${controller.phoneInput.value.length}/11'
                          : '${controller.smsCodeInput.value.length}/6',
                    ),
                    const SizedBox(height: 18),
                    if (!nativeMode && controller.captchaVisible.value)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: Text(
                          '验证码已弹出：方向键移动光标，OK 点击要选的字。',
                          style: TextStyle(
                            color: Color(0xFFFFC24B),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    _ErrorText(error: controller.error.value),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: <Widget>[
                        if (!phoneStep)
                          TvFocusableButton(
                            label: '返回手机号',
                            icon: Icons.arrow_back,
                            onPressed: controller.previousSmsStepOrBack,
                          ),
                        TvFocusableButton(
                          label: phoneStep
                              ? controller.smsSending.value
                                  ? '获取中...'
                                  : '获取验证码'
                              : controller.smsCountdown.value > 0
                                  ? '重新获取(${controller.smsCountdown.value}s)'
                                  : controller.smsSending.value
                                      ? '获取中...'
                                      : '重新获取',
                          icon: Icons.sms_outlined,
                          onPressed: controller.requestSmsCode,
                        ),
                        if (!phoneStep)
                          TvFocusableButton(
                            label:
                                controller.smsLoggingIn.value ? '登录中...' : '登录',
                            icon: Icons.login,
                            onPressed: controller.loginBySmsCode,
                          ),
                        TvFocusableButton(
                          label: nativeMode ? '网页登录手机号' : 'TV原生手机号',
                          icon: nativeMode
                              ? Icons.pin_outlined
                              : Icons.phone_android,
                          onPressed: () =>
                              controller.setLoginMode(nativeMode ? 2 : 1),
                        ),
                        TvFocusableButton(
                          label: '网页登录兜底',
                          icon: Icons.language,
                          onPressed: controller.openWebLogin,
                        ),
                        TvFocusableButton(
                          label: '检查状态',
                          icon: Icons.verified_user_outlined,
                          onPressed: controller.refreshLoginStatus,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 36),
              _NumberPad(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _InputPreview extends StatelessWidget {
  const _InputPreview({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final String progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 17),
              ),
              const Spacer(),
              Text(
                progress,
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.controller});

  final TvLoginController controller;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: SizedBox(
        width: 330,
        child: Column(
          children: <Widget>[
            for (final List<_PadKey> row in const <List<_PadKey>>[
              <_PadKey>[
                _PadKey('1', '1'),
                _PadKey('2', '2'),
                _PadKey('3', '3'),
              ],
              <_PadKey>[
                _PadKey('4', '4'),
                _PadKey('5', '5'),
                _PadKey('6', '6'),
              ],
              <_PadKey>[
                _PadKey('7', '7'),
                _PadKey('8', '8'),
                _PadKey('9', '9'),
              ],
              <_PadKey>[
                _PadKey('清空', 'clear'),
                _PadKey('0', '0'),
                _PadKey('删除', 'delete'),
              ],
            ]) ...<Widget>[
              Row(
                children: <Widget>[
                  for (final _PadKey item in row) ...<Widget>[
                    Expanded(
                      child: _PadButton(
                        label: item.label,
                        onPressed: () {
                          switch (item.value) {
                            case 'clear':
                              controller.clearInput();
                              break;
                            case 'delete':
                              controller.deleteDigit();
                              break;
                            default:
                              controller.inputDigit(item.value);
                          }
                        },
                      ),
                    ),
                    if (item != row.last) const SizedBox(width: 12),
                  ],
                ],
              ),
              if (row !=
                  const <_PadKey>[
                    _PadKey('清空', 'clear'),
                    _PadKey('0', '0'),
                    _PadKey('删除', 'delete'),
                  ])
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PadKey {
  const _PadKey(this.label, this.value);

  final String label;
  final String value;
}

class _PadButton extends StatefulWidget {
  const _PadButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Focus(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (bool value) {
        setState(() {
          _focused = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 74,
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(_focused ? 1.04 : 1.0),
        decoration: BoxDecoration(
          color: _focused ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _focused ? Colors.white : Colors.white12,
            width: _focused ? 2 : 1,
          ),
          boxShadow: _focused
              ? <BoxShadow>[
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onPressed,
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: _focused ? Colors.white : colorScheme.onSurface,
                fontSize: widget.label.length == 1 ? 30 : 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebLoginPanel extends StatelessWidget {
  const _WebLoginPanel({required this.controller});

  final TvLoginController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        key: const ValueKey<String>('web'),
        title: '网页登录兜底',
        subtitle: '打开和手机版一致的哔哩哔哩官方登录页，可处理密码、扫码、滑块和风控验证。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '如果短信验证码被风控、滑块验证失败，或扫码一直不同步，就用这里。登录成功后点右上角“刷新登录状态”，或返回本页点检查状态。',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 17,
                height: 1.4,
              ),
            ),
            _ErrorText(error: controller.error.value),
            const SizedBox(height: 26),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: <Widget>[
                TvFocusableButton(
                  label: '打开官方登录页',
                  icon: Icons.language,
                  onPressed: controller.openWebLogin,
                ),
                TvFocusableButton(
                  label: '检查登录状态',
                  icon: Icons.verified_user_outlined,
                  onPressed: controller.refreshLoginStatus,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 17),
        ),
        const SizedBox(height: 30),
        child,
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null || error!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        error!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 15),
      ),
    );
  }
}

class _CaptchaPointerCursor extends StatelessWidget {
  const _CaptchaPointerCursor();

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

class _CaptchaPointerHint extends StatelessWidget {
  const _CaptchaPointerHint();

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
          '验证码光标：方向键移动，OK 点击。若要关闭验证码，可按返回键。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
