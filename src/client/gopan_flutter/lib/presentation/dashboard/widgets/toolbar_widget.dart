import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/upload_controller.dart';
import '../widgets/context_menu_widget.dart';
import '../../../app/routes/app_routes.dart';

class ToolbarWidget extends GetView<DashboardController> {
  const ToolbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final upload = Get.find<UploadController>();
    return Obx(() {
      final hasSelection = controller.selectedIds.isNotEmpty;
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            _btn(Icons.upload_file, '上传', () async {
              final result = await FilePicker.platform.pickFiles(allowMultiple: true);
              if (result != null) {
                final paths = result.paths.whereType<String>().toList();
                upload.uploadFiles(paths, parentId: controller.currentParentId.value);
              }
            }),
            _btn(Icons.create_new_folder_outlined, '新建文件夹', () => _showCreateFolder()),
            const VerticalDivider(width: 16, indent: 8, endIndent: 8),
            if (hasSelection) ...[
              _btn(Icons.download_outlined, '下载', () => _downloadSelected()),
              _btn(Icons.share_outlined, '分享', () => _shareSelected()),
              _btn(Icons.drive_file_rename_outline, '重命名', () => _renameSelected(),
                  enabled: controller.selectedIds.length == 1),
              _btn(Icons.delete_outline, '删除', () => _confirmDelete(),
                  color: Colors.red),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
            ],
            const Spacer(),
            // Search
            SizedBox(
              width: 200,
              height: 30,
              child: TextField(
                decoration: InputDecoration(
                  hintText: '搜索文件...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: controller.search,
              ),
            ),
            const SizedBox(width: 8),
            // View toggle
            IconButton(
              icon: Icon(controller.isGridView.value ? Icons.list : Icons.grid_view,
                  size: 18),
              onPressed: () => controller.isGridView.toggle(),
              tooltip: controller.isGridView.value ? '列表视图' : '网格视图',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      );
    });
  }

  Widget _btn(IconData icon, String tooltip, VoidCallback onTap,
      {bool enabled = true, Color? color}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(children: [
            Icon(icon, size: 16,
                color: enabled ? (color ?? const Color(0xFF374151)) : Colors.grey),
            const SizedBox(width: 4),
            Text(tooltip,
                style: TextStyle(
                    fontSize: 12,
                    color: enabled ? (color ?? const Color(0xFF374151)) : Colors.grey)),
          ]),
        ),
      ),
    );
  }

  void _showCreateFolder() {
    final ctrl = TextEditingController();
    Get.dialog(AlertDialog(
      title: const Text('新建文件夹'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: '文件夹名称'),
        onSubmitted: (_) {
          if (ctrl.text.isNotEmpty) {
            controller.createFolder(ctrl.text);
            Get.back();
          }
        },
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.isNotEmpty) {
              controller.createFolder(ctrl.text);
              Get.back();
            }
          },
          child: const Text('创建'),
        ),
      ],
    ));
  }

  void _renameSelected() {
    final id = controller.selectedIds.first;
    final node = controller.files.firstWhere((f) => f.id == id);
    final ctrl = TextEditingController(text: node.name);
    Get.dialog(AlertDialog(
      title: const Text('重命名'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: '新名称'),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.isNotEmpty) {
              controller.rename(id, ctrl.text);
              Get.back();
            }
          },
          child: const Text('确定'),
        ),
      ],
    ));
  }

  void _confirmDelete() {
    Get.dialog(AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定要删除选中的 ${controller.selectedIds.length} 个文件吗？'),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            controller.deleteSelected();
            Get.back();
          },
          child: const Text('删除', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Future<void> _downloadSelected() async {
    final nodes = controller.files
        .where((f) => controller.selectedIds.contains(f.id) && !f.isFolder)
        .toList();
    if (nodes.isEmpty) {
      Get.snackbar('提示', '文件夹暂不支持直接下载');
      return;
    }
    for (final node in nodes) {
      await ContextMenuWidget.downloadNode(node);
    }
  }

  void _shareSelected() {
    if (controller.selectedIds.length != 1) {
      Get.snackbar('提示', '请选择单个文件进行分享');
      return;
    }
    Get.toNamed(AppRoutes.shareList,
        arguments: {'createFor': controller.selectedIds.first});
  }
}
