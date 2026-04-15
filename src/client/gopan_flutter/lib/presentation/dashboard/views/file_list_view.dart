import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/upload_controller.dart';
import '../widgets/file_item_widget.dart';

class FileListView extends GetView<DashboardController> {
  const FileListView({super.key});

  @override
  Widget build(BuildContext context) {
    final upload = Get.find<UploadController>();
    final isDragging = false.obs;

    return DropTarget(
      onDragEntered: (_) => isDragging.value = true,
      onDragExited: (_) => isDragging.value = false,
      onDragDone: (detail) {
        isDragging.value = false;
        final paths = detail.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          upload.uploadFiles(paths, parentId: controller.currentParentId.value);
        }
      },
      child: Obx(() {
        // Drag overlay
        if (isDragging.value) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0078D4), width: 2),
              color: const Color(0xFF0078D4).withValues(alpha: 0.05),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, size: 48, color: Color(0xFF0078D4)),
                  SizedBox(height: 8),
                  Text('松开以上传文件',
                      style: TextStyle(color: Color(0xFF0078D4), fontSize: 16)),
                ],
              ),
            ),
          );
        }

        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.files.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  controller.searchQuery.isNotEmpty ? '没有找到相关文件' : '拖拽文件到此处上传，或点击工具栏上传',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        if (controller.isGridView.value) {
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.85,
            ),
            itemCount: controller.files.length,
            itemBuilder: (_, i) =>
                FileItemWidget(node: controller.files[i], isGrid: true),
          );
        }

        // List view with header
        return Column(
          children: [
            Container(
              height: 32,
              color: const Color(0xFFF9FAFB),
              child: Row(children: [
                const SizedBox(width: 34),
                Expanded(flex: 4, child: _headerBtn('名称', 'name')),
                Expanded(flex: 1, child: _headerBtn('大小', 'size')),
                Expanded(flex: 2, child: _headerBtn('修改时间', 'updated_at')),
                const SizedBox(width: 8),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: controller.files.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (_, i) => SizedBox(
                  height: 36,
                  child: FileItemWidget(node: controller.files[i]),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _headerBtn(String label, String field) {
    return Obx(() {
      final active = controller.sortBy.value == field;
      return InkWell(
        onTap: () => controller.setSortBy(field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active
                        ? const Color(0xFF0078D4)
                        : const Color(0xFF6B7280))),
            if (active)
              Icon(
                controller.sortOrder.value == 'asc'
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 12,
                color: const Color(0xFF0078D4),
              ),
          ]),
        ),
      );
    });
  }
}
