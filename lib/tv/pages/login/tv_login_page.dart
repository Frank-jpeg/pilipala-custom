import 'package:flutter/material.dart';
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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(56, 42, 56, 42),
        child: Obx(
          () {
            if (session.isLogin.value) {
              return _LoggedInView(session: session);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TvFocusableButton(
                        autofocus: true,
                        label: '返回',
                        icon: Icons.arrow_back,
                        onPressed: Get.back,
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
                        label: '账号登录',
                        icon: Icons.language,
                        selected: controller.loginMode.value == 1,
                        onPressed: () => controller.setLoginMode(1),
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
                      _ => _WebLoginPanel(controller: controller),
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() => super.dispose();
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
      subtitle: '用哔哩哔哩 App 扫码后确认登录。扫码失败时，可以切到网页登录。',
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

class _WebLoginPanel extends StatelessWidget {
  const _WebLoginPanel({required this.controller});

  final TvLoginController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      key: const ValueKey<String>('web'),
      title: '账号登录',
      subtitle: '打开和手机版一致的哔哩哔哩官方登录页，可用密码、短信验证码、扫码和风控验证。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '如果 TV 端扫码一直不同步，优先用这里。登录成功后点右上角“刷新登录状态”，或返回本页点检查登录状态。',
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
