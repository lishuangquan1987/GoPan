import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../../../core/utils/file_utils.dart';

class CapacityBarWidget extends GetView<DashboardController> {
  const CapacityBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cap = controller.capacity.value;
      if (cap == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('存储空间', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  '${FileUtils.formatSize(cap.usedQuota)} / ${FileUtils.formatSize(cap.totalQuota)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: cap.ratio.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(
                  cap.ratio > 0.9 ? Colors.red : const Color(0xFF0078D4),
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    });
  }
}
