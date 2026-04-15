import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(SettingsController());
    final urlCtrl = TextEditingController(text: ctrl.serverUrl.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: const Color(0xFF0078D4),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('服务器配置',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('服务器地址', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      hintText: 'http://localhost:8080',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ctrl.saveServerUrl(urlCtrl.text),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0078D4), foregroundColor: Colors.white),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('账号',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('退出登录', style: TextStyle(color: Colors.red)),
              onTap: () => Get.dialog(AlertDialog(
                title: const Text('退出登录'),
                content: const Text('确定要退出登录吗？'),
                actions: [
                  TextButton(onPressed: Get.back, child: const Text('取消')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: ctrl.logout,
                    child: const Text('退出', style: TextStyle(color: Colors.white)),
                  ),
                ],
              )),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('GoPan v1.0.0',
                style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB))),
          ),
        ],
      ),
    );
  }
}
