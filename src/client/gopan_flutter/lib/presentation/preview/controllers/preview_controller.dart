import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../../data/models/file_node_model.dart';
import '../../../data/repositories/file_repository.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/network/api_endpoints.dart';

class PreviewController extends GetxController {
  final FileRepository _repo;
  PreviewController(this._repo);

  final node = Rxn<FileNode>();
  final isLoading = false.obs;
  final textContent = ''.obs;
  final localPath = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is FileNode) {
      node.value = arg;
      _prepare(arg);
    }
  }

  Future<void> _prepare(FileNode n) async {
    isLoading.value = true;
    try {
      if (FileUtils.isText(n.name)) {
        // Fetch text content via proxy URL
        final url = _repo.proxyUrl(n.id);
        // Text content loaded in view via NetworkImage or http
        localPath.value = url;
      } else if (FileUtils.isImage(n.name)) {
        localPath.value = _repo.proxyUrl(n.id);
      } else if (FileUtils.isPdf(n.name) || FileUtils.isVideo(n.name)) {
        // Download to temp for local player
        final tmp = await getTemporaryDirectory();
        final path = '${tmp.path}${Platform.pathSeparator}${n.name}';
        if (!File(path).existsSync()) {
          await _repo.downloadFile(n.id, path);
        }
        localPath.value = path;
      }
    } catch (e) {
      Get.snackbar('错误', '加载预览失败');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> downloadAndOpen() async {
    final n = node.value;
    if (n == null) return;
    isLoading.value = true;
    try {
      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final path = '${dir.path}${Platform.pathSeparator}${n.name}';
      await _repo.downloadFile(n.id, path);
      await OpenFile.open(path);
    } catch (e) {
      Get.snackbar('错误', '下载失败');
    } finally {
      isLoading.value = false;
    }
  }

  String get authProxyUrl {
    final n = node.value;
    if (n == null) return '';
    return '${LocalStorage.serverUrl}${ApiEndpoints.proxy(n.id)}';
  }
}
