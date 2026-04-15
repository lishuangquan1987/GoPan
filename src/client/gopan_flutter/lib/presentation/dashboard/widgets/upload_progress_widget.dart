import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/upload_controller.dart';
import '../../../core/utils/file_utils.dart';

class UploadProgressWidget extends GetView<UploadController> {
  const UploadProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isVisible.value || controller.tasks.isEmpty) {
        return const SizedBox.shrink();
      }
      return Positioned(
        right: 16,
        bottom: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Text('上传任务', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: controller.dismiss,
                        child: const Text('清除已完成', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Task list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: controller.tasks.length,
                    itemBuilder: (_, i) {
                      final task = controller.tasks[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(task.fileName,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              _statusIcon(task.status),
                            ]),
                            const SizedBox(height: 4),
                            if (task.status == 'uploading')
                              LinearProgressIndicator(
                                value: task.progress,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF0078D4)),
                                minHeight: 4,
                              ),
                            if (task.status == 'error')
                              Text(task.error ?? '上传失败',
                                  style: const TextStyle(fontSize: 11, color: Colors.red)),
                            if (task.status != 'uploading')
                              Text(
                                task.status == 'done'
                                    ? FileUtils.formatSize(task.totalSize)
                                    : task.status == 'pending' ? '等待中...' : '',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'done':
        return const Icon(Icons.check_circle, size: 16, color: Colors.green);
      case 'error':
        return const Icon(Icons.error_outline, size: 16, color: Colors.red);
      case 'uploading':
        return const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0078D4)));
      default:
        return const Icon(Icons.schedule, size: 16, color: Colors.grey);
    }
  }
}
