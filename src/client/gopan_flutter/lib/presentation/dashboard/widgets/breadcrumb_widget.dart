import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';

class BreadcrumbWidget extends GetView<DashboardController> {
  const BreadcrumbWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final crumbs = controller.breadcrumb;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _crumbBtn('我的文件', Icons.home, () => controller.navigateToBreadcrumb(-1)),
            ...crumbs.asMap().entries.map((e) => Row(children: [
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
                  _crumbBtn(e.value.name, Icons.folder,
                      () => controller.navigateToBreadcrumb(e.key)),
                ])),
          ],
        ),
      );
    });
  }

  Widget _crumbBtn(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
        ]),
      ),
    );
  }
}
