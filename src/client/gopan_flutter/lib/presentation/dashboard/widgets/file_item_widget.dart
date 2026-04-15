import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../data/models/file_node_model.dart';
import '../controllers/dashboard_controller.dart';
import '../../../core/utils/file_utils.dart';
import 'context_menu_widget.dart';
import 'package:intl/intl.dart';

class FileItemWidget extends StatelessWidget {
  final FileNode node;
  final bool isGrid;

  const FileItemWidget({super.key, required this.node, this.isGrid = false});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DashboardController>();
    return Obx(() {
      final selected = ctrl.selectedIds.contains(node.id);
      return isGrid ? _buildGrid(context, ctrl, selected) : _buildRow(context, ctrl, selected);
    });
  }

  Widget _buildRow(BuildContext context, DashboardController ctrl, bool selected) {
    return GestureDetector(
      onTap: () => _handleTap(ctrl),
      onDoubleTap: () => ctrl.openFile(node),
      onSecondaryTapUp: (d) => ContextMenuWidget.show(context, node, d.globalPosition),
      child: Container(
        color: selected ? const Color(0xFF0078D4) : Colors.transparent,
        child: Row(children: [
          const SizedBox(width: 8),
          Icon(FileUtils.iconData(node.name, node.isFolder),
              size: 18,
              color: selected ? Colors.white : FileUtils.iconColor(node.name, node.isFolder)),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(node.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: selected ? Colors.white : const Color(0xFF111827))),
          ),
          Expanded(
            flex: 1,
            child: Text(node.isFolder ? '' : FileUtils.formatSize(node.size),
                style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : const Color(0xFF6B7280))),
          ),
          Expanded(
            flex: 2,
            child: Text(DateFormat('yyyy/MM/dd HH:mm').format(node.updatedAt),
                style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : const Color(0xFF6B7280))),
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, DashboardController ctrl, bool selected) {
    return GestureDetector(
      onTap: () => _handleTap(ctrl),
      onDoubleTap: () => ctrl.openFile(node),
      onLongPress: () => ctrl.toggleSelect(node.id),
      onSecondaryTapUp: (d) => ContextMenuWidget.show(context, node, d.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0078D4) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FileUtils.iconData(node.name, node.isFolder),
                size: 40,
                color: selected ? Colors.white : FileUtils.iconColor(node.name, node.isFolder)),
            const SizedBox(height: 6),
            Text(node.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: selected ? Colors.white : const Color(0xFF111827))),
          ],
        ),
      ),
    );
  }

  void _handleTap(DashboardController ctrl) {
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    if (isCtrl) {
      ctrl.toggleSelect(node.id);
    } else {
      ctrl.selectOnly(node.id);
    }
  }
}
