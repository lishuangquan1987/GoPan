import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/share_controller.dart';

class ShareListView extends GetView<ShareController> {
  const ShareListView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    if (args is Map && args['createFor'] != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showCreateDialog(context, args['createFor'] as String));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的分享'),
        backgroundColor: const Color(0xFF0078D4),
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.shares.isEmpty) {
          return const Center(
              child: Text('暂无分享', style: TextStyle(color: Color(0xFF9CA3AF))));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: controller.shares.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final s = controller.shares[i];
            return Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(s.isFolder ? Icons.folder : Icons.insert_drive_file,
                          size: 18,
                          color: s.isFolder
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.nodeName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (s.hasPassword)
                        const Icon(Icons.lock_outline,
                            size: 14, color: Color(0xFF9CA3AF)),
                      if (s.isExpired)
                        const Chip(
                          label: Text('已过期', style: TextStyle(fontSize: 10)),
                          backgroundColor: Color(0xFFFEE2E2),
                          padding: EdgeInsets.zero,
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '访问 ${s.accessCount} 次 · ${s.shareType == 0 ? '永久' : '限时'}'
                      '${s.expiresAt != null ? ' · 到期 ${DateFormat('yyyy/MM/dd').format(s.expiresAt!)}' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      TextButton.icon(
                        onPressed: () => controller.shareLink(s.code),
                        icon: const Icon(Icons.share, size: 14),
                        label: const Text('分享', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton.icon(
                        onPressed: () => controller.openInBrowser(s.code),
                        icon: const Icon(Icons.open_in_browser, size: 14),
                        label: const Text('浏览器打开',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        onPressed: () => _confirmDelete(s.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _confirmDelete(String id) {
    Get.dialog(AlertDialog(
      title: const Text('删除分享'),
      content: const Text('确定要删除此分享链接吗？'),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            controller.deleteShare(id);
            Get.back();
          },
          child: const Text('删除', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _showCreateDialog(BuildContext context, String nodeId) {
    int shareType = 0;
    DateTime? expiresAt;
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('创建分享'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Text('类型：'),
                DropdownButton<int>(
                  value: shareType,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('永久分享')),
                    DropdownMenuItem(value: 1, child: Text('限时分享')),
                  ],
                  onChanged: (v) => setState(() => shareType = v!),
                ),
              ]),
              if (shareType == 1)
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => expiresAt = d);
                  },
                  child: Text(expiresAt == null
                      ? '选择过期时间'
                      : '过期：${expiresAt!.toLocal().toString().substring(0, 10)}'),
                ),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                    labelText: '访问密码（可选）', hintText: '留空则无密码'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final share = await controller.createShare(nodeId,
                    shareType: shareType,
                    expiresAt: expiresAt,
                    password:
                        passCtrl.text.isEmpty ? null : passCtrl.text);
                if (share != null) {
                  final link = controller.getLinkForCode(share.code);
                  Get.dialog(AlertDialog(
                    title: const Text('分享创建成功'),
                    content: SelectableText(link),
                    actions: [
                      TextButton(
                        onPressed: () {
                          controller.shareLink(share.code);
                          Get.back();
                        },
                        child: const Text('分享链接'),
                      ),
                      ElevatedButton(
                          onPressed: Get.back, child: const Text('关闭')),
                    ],
                  ));
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      }),
    );
  }
}
