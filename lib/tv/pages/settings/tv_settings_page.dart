import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TvSettingsPage extends StatelessWidget {
  const TvSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.settings_outlined, size: 64, color: Colors.white70),
            const SizedBox(height: 18),
            const Text(
              'TV 设置首版先保持极简',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              '后续可以继续补画质偏好、自动播放、首页布局等选项',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Get.back(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
