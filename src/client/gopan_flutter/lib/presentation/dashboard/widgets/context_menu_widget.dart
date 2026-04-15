import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/file_node_model.dart';
import '../../../data/repositories/file_repository.dart';
import '../controllers/dashboard_controller.dart';
import '../../../app/routes/app_routes.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class ContextMenuWidget extends StatelessWidget {
  final FileNode node;
  final Offset position;

  const ContextMenuWidget({super.key, required this.node, required this.position});

  static void show(BuildContext context, FileNode node, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: _buildItems(context, node),
    );
  }

  static List<PopupMenuEntry> _buildItems(BuildContext context, FileNode node) {
    final ctrl = Get.find<DashboardController>();
    return [
      if (!node.isFolder)
        PopupMenuItem(
          onTap: () => Get.toNamed(AppRoutes.preview, arguments: node),
          child: const _MenuItem(Icons.visibility_outlined, '预览'),
        ),
      PopupMenuItem(
        onTap: () => downloadNode(node),
        child: const _MenuItem(Icons.download_outlined, '下载'),
      ),
      PopupMenuItem(
        onTap: () => _showRename(node, ctrl),
        child: const _MenuItem(Icons.drive_file_rename_outline, '重命名'),
      ),
      PopupMenuItem(
        onTap: () => _showShare(node),
        child: const _MenuItem(Icons.share_outlined, '分享'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        onTap: () => _confirmDelete(node, ctrl),
        child: const _MenuItem(Icons.delete_outline, '删除', color: Colors.red),
      ),
    ];
  }

  static Future<void> downloadNode(FileNode node) async {
    try {
      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final savePath = '${dir.path}${Platform.pathSeparator}${node.name}';
      Get.snackbar('下载', '开始下载 ${node.name}');
      final repo = Get.find<FileRepository>();
      await repo.downloadFile(node.id, savePath);
      await OpenFile.open(savePath);
    } catch (e) {
      Get.snackbar('错误', '下载失败');
    }
  }

  static void _showRename(FileNode node, DashboardController ctrl) {
    final textCtrl = TextEditingController(text: node.name);
    Get.dialog(AlertDialog(
      title: const Text('重命名'),
      content: TextField(controller: textCtrl, autofocus: true),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            ctrl.rename(node.id, textCtrl.text);
            Get.back();
          },
          child: const Text('确定'),
        ),
      ],
    ));
  }

  static void _showShare(FileNode node) {
    Get.toNamed(AppRoutes.shareList, arguments: {'createFor': node.id});
  }

  static void _confirmDelete(FileNode node, DashboardController ctrl) {
    ctrl.selectOnly(node.id);
    Get.dialog(AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定要删除 "${node.name}" 吗？'),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            ctrl.deleteSelected();
            Get.back();
          },
          child: const Text('删除', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuItem(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color ?? const Color(0xFF374151)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF374151))),
    ]);
  }
}
