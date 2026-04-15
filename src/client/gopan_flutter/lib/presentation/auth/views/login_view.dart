import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../../app/routes/app_routes.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
            ),
            child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                const Icon(Icons.cloud, size: 48, color: Color(0xFF0078D4)),
                const SizedBox(height: 8),
                const Text('GoPan 网盘',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                // Username
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),

                // Email (register only)
                if (controller.isRegisterMode.value) ...[
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: '邮箱（可选）',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Password
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onSubmitted: (_) => controller.isRegisterMode.value
                      ? controller.register(userCtrl.text, passCtrl.text, emailCtrl.text)
                      : controller.login(userCtrl.text, passCtrl.text),
                ),
                const SizedBox(height: 8),

                // Error
                if (controller.errorMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(controller.errorMsg.value,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),

                // Server settings
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Get.toNamed(AppRoutes.settings),
                    child: const Text('服务器设置', style: TextStyle(fontSize: 12)),
                  ),
                ),

                // Submit button
                ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.isRegisterMode.value
                          ? controller.register(userCtrl.text, passCtrl.text, emailCtrl.text)
                          : controller.login(userCtrl.text, passCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0078D4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: controller.isLoading.value
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(controller.isRegisterMode.value ? '注册' : '登录'),
                ),
                const SizedBox(height: 12),

                // Toggle
                TextButton(
                  onPressed: () {
                    controller.isRegisterMode.toggle();
                    controller.errorMsg.value = '';
                  },
                  child: Text(controller.isRegisterMode.value ? '已有账号？去登录' : '没有账号？去注册'),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}
