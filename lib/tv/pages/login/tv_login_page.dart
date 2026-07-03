import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TvLoginController controller = Get.put(TvLoginController());

  @override
  Widget build(BuildContext context) {
    final TvSessionController session = Get.find<TvSessionController>();
    return Obx(
      () {
        final bool blockBack =
            controller.loginMode.value == 1 && !controller.isPhoneStep;
        return PopScope(
          canPop: !blockBack,
          onPopInvoked: (bool didPop) {
            if (!didPop && blockBack) {
              controller.previousSmsStepOrBack();
            }
          },
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(56, 42, 56, 42),
              child: session.isLogin.value
                  ? _LoggedInView(session: session)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 280,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              TvFocusableButton(
                                autofocus: true,
                                label: blockBack ? '返回手机号' : '返回',
                                icon: Icons.arrow_back,
                                onPressed: controller.loginMode.value == 1
                                    ? controller.previousSmsStepOrBack
                                    : Get.back,
                              ),
                              const SizedBox(height: 42),
                              _ModeButton(
                                label: '扫码登录',
                                icon: Icons.qr_code_2,
                                selected: controller.loginMode.value == 0,
                                onPressed: () => controller.setLoginMode(0),
                              ),
                              const SizedBox(height: 14),
                              _ModeButton(
                                label: '手机号登录',
                                icon: Icons.pin_outlined,
                                selected: controller.loginMode.value == 1,
                                onPressed: () => controller.setLoginMode(1),
                              ),
                              const SizedBox(height: 14),
                              _ModeButton(
                                label: '网页登录兜底',
                                icon: Icons.language,
                                selected: controller.loginMode.value == 2,
                                onPressed: () => controller.setLoginMode(2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 52),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: switch (controller.loginMode.value) {
                              0 => _QrLoginPanel(controller: controller),
                              1 => _SmsLoginPanel(controller: controller),
                              _ => _WebLoginPanel(controller: controller),
                            },
                          ),
                        ),
                      ],
                    ),
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
          TvFocusableButton(
            label: '返回',
            icon: Icons.check_circle_outline,
            autofocus: true,
            onPressed: Get.back,
          ),
        ],
      ),
    );
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
    return _Panel(
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
    );
  }
}

class _SmsLoginPanel extends StatelessWidget {
  const _SmsLoginPanel({required this.controller});

  final TvLoginController controller;

  @override
  Widget build(BuildContext context) {
    final bool phoneStep = controller.isPhoneStep;
    return _Panel(
      key: const ValueKey<String>('sms'),
      title: '手机号登录',
      subtitle:
          phoneStep ? '用遥控器方向键选择数字，OK 输入手机号。' : '输入短信验证码。遇到滑块或风控失败时，请切到网页登录兜底。',
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
                        label: controller.smsLoggingIn.value ? '登录中...' : '登录',
                        icon: Icons.login,
                        onPressed: controller.loginBySmsCode,
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
    return _Panel(
      key: const ValueKey<String>('web'),
      title: '网页登录兜底',
      subtitle: '打开和手机版一致的哔哩哔哩官方登录页，可处理密码、扫码、滑块和风控验证。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '如果短信验证码被风控、滑块验证失败，或扫码一直不同步，就用这里。登录成功后点右上角“刷新登录状态”，或返回本页点检查状态。',
            style: TextStyle(color: Colors.white70, fontSize: 17, height: 1.4),
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
