import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trash_controller.dart';
import '../../../core/utils/file_utils.dart';

class TrashView extends GetView<TrashController> {
  const TrashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        backgroundColor: const Color(0xFF0078D4),
        foregroundColor: Colors.white,
        actions: [
          Obx(() => controller.selectedIds.isNotEmpty
              ? Row(children: [
                  TextButton(
                    onPressed: controller.restoreSelected,
                    child: const Text('恢复', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () => _confirmPermanentDelete(),
                    child: const Text('彻底删除', style: TextStyle(color: Color(0xFFFFCDD2))),
                  ),
                ])
              : TextButton(
                  onPressed: controller.selectAll,
                  child: const Text('全选', style: TextStyle(color: Colors.white)),
                )),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.files.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, size: 64, color: Color(0xFFD1D5DB)),
                SizedBox(height: 12),
                Text('回收站为空', style: TextStyle(color: Color(0xFF9CA3AF))),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: controller.files.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final f = controller.files[i];
            return Obx(() {
              final selected = controller.selectedIds.contains(f.id);
              return ListTile(
                tileColor: selected ? const Color(0xFFEFF6FF) : null,
                leading: Icon(FileUtils.iconData(f.name, f.isFolder),
                    color: FileUtils.iconColor(f.name, f.isFolder)),
                title: Text(f.name, style: const TextStyle(fontSize: 13)),
                subtitle: f.isFolder
                    ? null
                    : Text(FileUtils.formatSize(f.size),
                        style: const TextStyle(fontSize: 11)),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: Color(0xFF0078D4))
                    : null,
                onTap: () => controller.toggleSelect(f.id),
              );
            });
          },
        );
      }),
    );
  }

  void _confirmPermanentDelete() {
    Get.dialog(AlertDialog(
      title: const Text('彻底删除'),
      content: Text('确定要永久删除选中的 ${controller.selectedIds.length} 个文件吗？此操作不可恢复！'),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            controller.permanentlyDeleteSelected();
            Get.back();
          },
          child: const Text('永久删除', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}
