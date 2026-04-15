import 'package:get/get.dart';
import '../../../data/repositories/file_repository.dart';
import '../../../data/models/file_node_model.dart';

class TrashController extends GetxController {
  final FileRepository _repo;
  TrashController(this._repo);

  final files = <FileNode>[].obs;
  final selectedIds = <String>{}.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      files.value = await _repo.getTrash();
    } catch (_) {
      Get.snackbar('错误', '加载回收站失败');
    } finally {
      isLoading.value = false;
    }
  }

  void toggleSelect(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  void selectAll() => selectedIds.addAll(files.map((f) => f.id));
  void clearSelection() => selectedIds.clear();

  Future<void> restoreSelected() async {
    try {
      await _repo.restore(selectedIds.toList());
      selectedIds.clear();
      await load();
      Get.snackbar('成功', '已恢复到原位置');
    } catch (_) {
      Get.snackbar('错误', '恢复失败');
    }
  }

  Future<void> permanentlyDeleteSelected() async {
    for (final id in selectedIds.toList()) {
      try {
        await _repo.permanentlyDelete(id);
      } catch (_) {}
    }
    selectedIds.clear();
    await load();
  }
}
