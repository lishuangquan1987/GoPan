import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/share_controller.dart';
import '../../../core/utils/file_utils.dart';

class ShareAccessView extends GetView<ShareController> {
  const ShareAccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
            controller.accessNode.value?['node_name'] ?? '分享文件')),
        backgroundColor: const Color(0xFF0078D4),
        foregroundColor: Colors.white,
        actions: [
          Obx(() => controller.accessNode.value != null
              ? TextButton(
                  onPressed: controller.saveToMyDrive,
                  child: const Text('保存到网盘', style: TextStyle(color: Colors.white)),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.needPassword.value) {
          return _PasswordPrompt(
            onSubmit: (pwd) => controller.loadShare(controller.accessCode.value, password: pwd),
          );
        }

        if (controller.accessError.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 64, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 12),
                Text(controller.accessError.value,
                    style: const TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          );
        }

        final data = controller.accessNode.value;
        if (data == null) return const SizedBox.shrink();

        // Single file
        if (data['is_folder'] != true) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(data['node_name'] ?? '', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text(FileUtils.formatSize(data['size'] ?? 0),
                    style: const TextStyle(color: Color(0xFF9CA3AF))),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: controller.saveToMyDrive,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('保存到我的网盘'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0078D4), foregroundColor: Colors.white),
                ),
              ],
            ),
          );
        }

        // Folder
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: controller.accessFiles.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final f = controller.accessFiles[i];
            return ListTile(
              leading: Icon(FileUtils.iconData(f.name, f.isFolder),
                  color: FileUtils.iconColor(f.name, f.isFolder)),
              title: Text(f.name, style: const TextStyle(fontSize: 13)),
              subtitle: f.isFolder
                  ? null
                  : Text(FileUtils.formatSize(f.size),
                      style: const TextStyle(fontSize: 11)),
              onTap: f.isFolder
                  ? () => controller.loadShare(controller.accessCode.value)
                  : null,
            );
          },
        );
      }),
    );
  }
}

class _PasswordPrompt extends StatelessWidget {
  final void Function(String) onSubmit;
  const _PasswordPrompt({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Color(0xFF0078D4)),
            const SizedBox(height: 16),
            const Text('此分享需要密码', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: '访问密码', border: OutlineInputBorder()),
              onSubmitted: onSubmit,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => onSubmit(ctrl.text),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0078D4), foregroundColor: Colors.white),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }
}
