import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pilipala/tv/controllers/tv_login_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/widgets/tv_focusable_button.dart';

class TvLoginPage extends StatelessWidget {
  const TvLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TvLoginController controller = Get.put(TvLoginController());
    final TvSessionController session = Get.find<TvSessionController>();
    return Scaffold(
      body: Center(
        child: Obx(
          () {
            if (session.isLogin.value) {
              return Column(
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
                    onPressed: () => Get.back(),
                  ),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  '扫码登录',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  '用哔哩哔哩 App 扫码后确认登录',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 28),
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
                if (controller.error.value != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(controller.error.value!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 22),
                TvFocusableButton(
                  label: '刷新二维码',
                  icon: Icons.refresh,
                  autofocus: true,
                  onPressed: controller.startLogin,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
