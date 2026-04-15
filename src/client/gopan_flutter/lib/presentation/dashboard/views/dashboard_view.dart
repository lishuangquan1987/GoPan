import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/toolbar_widget.dart';
import '../widgets/breadcrumb_widget.dart';
import '../widgets/capacity_bar_widget.dart';
import '../widgets/upload_progress_widget.dart';
import 'file_list_view.dart';
import 'file_tree_view.dart';
import '../../../core/utils/platform_utils.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('GoPan'),
              backgroundColor: const Color(0xFF0078D4),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _showMobileSearch(context),
                ),
              ],
            ),
      drawer: isDesktop
          ? null
          : Drawer(
              child: Column(children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Color(0xFF0078D4)),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text('GoPan 网盘',
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                ),
                Expanded(child: FileTreeView()),
                CapacityBarWidget(),
              ]),
            ),
      body: isDesktop ? _desktopLayout() : _mobileLayout(),
      bottomNavigationBar: isDesktop ? null : _mobileBottomNav(),
    );
  }

  Widget _desktopLayout() {
    final isNativeDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Column(
      children: [
        // Custom title bar (draggable on native desktop)
        isNativeDesktop
            ? _NativeTitleBar(onLogout: controller.logout)
            : _WebTitleBar(),
        Expanded(
          child: Row(
            children: [
              // Left sidebar
              Container(
                width: 200,
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Column(
                  children: [
                    Expanded(child: FileTreeView()),
                    CapacityBarWidget(),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Column(
                  children: [
                    ToolbarWidget(),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: BreadcrumbWidget(),
                      ),
                    ),
                    Expanded(child: Stack(
                      children: [
                        const FileListView(),
                        const UploadProgressWidget(),
                      ],
                    )),
                    // Status bar
                    Obx(() => Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: const Color(0xFFF9FAFB),
                      child: Row(children: [
                        Text(
                          controller.selectedIds.isEmpty
                              ? '${controller.files.length} 个项目'
                              : '已选择 ${controller.selectedIds.length} 个项目',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ]),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return Stack(
      children: [
        Column(
          children: [
            ToolbarWidget(),
            const BreadcrumbWidget(),
            const Expanded(child: FileListView()),
          ],
        ),
        const UploadProgressWidget(),
      ],
    );
  }

  Widget _mobileBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: const Color(0xFF0078D4),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), label: '文件'),
        BottomNavigationBarItem(icon: Icon(Icons.share_outlined), label: '分享'),
        BottomNavigationBarItem(icon: Icon(Icons.delete_outline), label: '回收站'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '设置'),
      ],
      onTap: (i) {
        switch (i) {
          case 1: Get.toNamed('/shares'); break;
          case 2: Get.toNamed('/trash'); break;
          case 3: Get.toNamed('/settings'); break;
        }
      },
    );
  }

  void _showMobileSearch(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('搜索文件'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入文件名...'),
            onSubmitted: (v) {
              controller.search(v);
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                controller.search(ctrl.text);
                Navigator.pop(context);
              },
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );
  }
}


// Native desktop draggable title bar using window_manager
class _NativeTitleBar extends StatelessWidget {
  final VoidCallback onLogout;
  const _NativeTitleBar({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 40,
        color: const Color(0xFF0078D4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.cloud, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('GoPan 网盘',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
            // Window controls
            _winBtn(Icons.remove, () => windowManager.minimize()),
            _winBtn(Icons.crop_square, () async {
              if (await windowManager.isMaximized()) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            }),
            _winBtn(Icons.close, () => windowManager.close(),
                hoverColor: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _winBtn(IconData icon, VoidCallback onTap, {Color? hoverColor}) {
    return InkWell(
      onTap: onTap,
      hoverColor: hoverColor ?? Colors.white24,
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }
}

class _WebTitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: const Color(0xFF0078D4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(children: [
        Icon(Icons.cloud, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('GoPan 网盘', style: TextStyle(color: Colors.white, fontSize: 13)),
      ]),
    );
  }
}
