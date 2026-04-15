import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../../../data/models/file_node_model.dart';
import '../../../app/routes/app_routes.dart';

class FileTreeView extends GetView<DashboardController> {
  const FileTreeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nav items
        _navItem(Icons.folder_outlined, '我的文件', () {
          controller.breadcrumb.clear();
          controller.currentParentId.value = null;
          controller.loadFiles();
        }),
        _navItem(Icons.share_outlined, '我的分享', () => Get.toNamed(AppRoutes.shareList)),
        _navItem(Icons.delete_outline, '回收站', () => Get.toNamed(AppRoutes.trash)),
        const Divider(height: 16),
        // Folder tree
        Expanded(
          child: Obx(() => ListView(
            children: controller.treeNodes
                .where((n) => n.isFolder && n.parentId == null)
                .map((n) => _TreeNode(node: n, depth: 0))
                .toList(),
          )),
        ),
        const Divider(height: 1),
        // Settings & logout
        _navItem(Icons.settings_outlined, '设置', () => Get.toNamed(AppRoutes.settings)),
        _navItem(Icons.logout, '退出登录', controller.logout, color: Colors.red),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: color ?? const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF374151))),
        ]),
      ),
    );
  }
}

class _TreeNode extends StatefulWidget {
  final FileNode node;
  final int depth;
  const _TreeNode({required this.node, required this.depth});

  @override
  State<_TreeNode> createState() => _TreeNodeState();
}

class _TreeNodeState extends State<_TreeNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DashboardController>();
    final children = ctrl.treeNodes
        .where((n) => n.isFolder && n.parentId == widget.node.id)
        .toList();
    final hasChildren = children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            ctrl.navigateTo(widget.node);
            if (hasChildren) setState(() => _expanded = !_expanded);
          },
          child: Padding(
            padding: EdgeInsets.only(
                left: 12.0 + widget.depth * 16, top: 6, bottom: 6, right: 8),
            child: Row(children: [
              if (hasChildren)
                Icon(_expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 14, color: const Color(0xFF9CA3AF))
              else
                const SizedBox(width: 14),
              const SizedBox(width: 4),
              const Icon(Icons.folder, size: 14, color: Color(0xFFFBBF24)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.node.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              ),
            ]),
          ),
        ),
        if (_expanded && hasChildren)
          ...children.map((c) => _TreeNode(node: c, depth: widget.depth + 1)),
      ],
    );
  }
}
