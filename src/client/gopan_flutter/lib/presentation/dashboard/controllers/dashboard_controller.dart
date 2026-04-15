import 'package:get/get.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/file_repository.dart';
import '../../../data/models/file_node_model.dart';
import '../../../data/models/capacity_model.dart';
import '../../../app/routes/app_routes.dart';

class DashboardController extends GetxController {
  final FileRepository _fileRepo;
  final AuthRepository _authRepo;
  DashboardController(this._fileRepo, this._authRepo);

  final files = <FileNode>[].obs;
  final treeNodes = <FileNode>[].obs;
  final selectedIds = <String>{}.obs;
  final breadcrumb = <FileNode>[].obs; // path stack
  final isLoading = false.obs;
  final isGridView = false.obs;
  final sortBy = 'name'.obs;
  final sortOrder = 'asc'.obs;
  final searchQuery = ''.obs;
  final capacity = Rxn<CapacityModel>();
  final currentParentId = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    loadFiles();
    loadTree();
    loadCapacity();
  }

  Future<void> loadFiles({String? parentId}) async {
    isLoading.value = true;
    selectedIds.clear();
    try {
      final res = await _fileRepo.getFiles(
        parentId: parentId,
        sortBy: sortBy.value,
        order: sortOrder.value,
      );
      // Folders first
      final folders = res.files.where((f) => f.isFolder).toList();
      final filesList = res.files.where((f) => !f.isFolder).toList();
      files.value = [...folders, ...filesList];
    } catch (e) {
      Get.snackbar('错误', '加载文件失败');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadTree() async {
    try {
      treeNodes.value = await _fileRepo.getTree();
    } catch (_) {}
  }

  Future<void> loadCapacity() async {
    try {
      capacity.value = await _fileRepo.getCapacity();
    } catch (_) {}
  }

  void navigateTo(FileNode folder) {
    breadcrumb.add(folder);
    currentParentId.value = folder.id;
    loadFiles(parentId: folder.id);
  }

  void navigateToBreadcrumb(int index) {
    if (index < 0) {
      // root
      breadcrumb.clear();
      currentParentId.value = null;
      loadFiles();
    } else {
      breadcrumb.removeRange(index + 1, breadcrumb.length);
      currentParentId.value = breadcrumb[index].id;
      loadFiles(parentId: breadcrumb[index].id);
    }
  }

  void toggleSelect(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  void selectOnly(String id) {
    selectedIds.clear();
    selectedIds.add(id);
  }

  void clearSelection() => selectedIds.clear();

  void selectAll() => selectedIds.addAll(files.map((f) => f.id));

  Future<void> createFolder(String name) async {
    try {
      await _fileRepo.createFolder(name, parentId: currentParentId.value);
      await loadFiles(parentId: currentParentId.value);
      await loadTree();
    } catch (e) {
      Get.snackbar('错误', '创建文件夹失败');
    }
  }

  Future<void> rename(String id, String newName) async {
    try {
      await _fileRepo.rename(id, newName);
      await loadFiles(parentId: currentParentId.value);
    } catch (e) {
      Get.snackbar('错误', '重命名失败');
    }
  }

  Future<void> deleteSelected() async {
    final ids = selectedIds.toList();
    try {
      for (final id in ids) {
        await _fileRepo.delete(id);
      }
      selectedIds.clear();
      await loadFiles(parentId: currentParentId.value);
      await loadCapacity();
    } catch (e) {
      Get.snackbar('错误', '删除失败');
    }
  }

  Future<void> search(String keyword) async {
    if (keyword.isEmpty) {
      searchQuery.value = '';
      await loadFiles(parentId: currentParentId.value);
      return;
    }
    isLoading.value = true;
    searchQuery.value = keyword;
    try {
      final results = await _fileRepo.search(keyword);
      files.value = results;
    } catch (e) {
      Get.snackbar('错误', '搜索失败');
    } finally {
      isLoading.value = false;
    }
  }

  void setSortBy(String field) {
    if (sortBy.value == field) {
      sortOrder.value = sortOrder.value == 'asc' ? 'desc' : 'asc';
    } else {
      sortBy.value = field;
      sortOrder.value = 'asc';
    }
    loadFiles(parentId: currentParentId.value);
  }

  Future<void> logout() async {
    try {
      await _authRepo.logout();
    } catch (_) {}
    Get.offAllNamed(AppRoutes.login);
  }

  void openFile(FileNode node) {
    if (node.isFolder) {
      navigateTo(node);
    } else {
      Get.toNamed(AppRoutes.preview, arguments: node);
    }
  }
}
