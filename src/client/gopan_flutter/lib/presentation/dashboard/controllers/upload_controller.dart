import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../data/repositories/file_repository.dart';
import 'dashboard_controller.dart';

class UploadTask {
  final String id;
  final String fileName;
  final int totalSize;
  int uploadedBytes;
  String status; // pending, uploading, done, error
  String? error;

  UploadTask({
    required this.id,
    required this.fileName,
    required this.totalSize,
    this.uploadedBytes = 0,
    this.status = 'pending',
    this.error,
  });

  double get progress => totalSize > 0 ? uploadedBytes / totalSize : 0;
}

class UploadController extends GetxController {
  final FileRepository _repo;
  UploadController(this._repo);

  final tasks = <UploadTask>[].obs;
  final isVisible = false.obs;

  static const _chunkSize = 5 * 1024 * 1024; // 5MB

  Future<void> uploadFiles(List<String> paths, {String? parentId}) async {
    isVisible.value = true;
    for (final path in paths) {
      final file = File(path);
      final name = file.path.split(Platform.pathSeparator).last;
      final size = await file.length();
      final task = UploadTask(id: const Uuid().v4(), fileName: name, totalSize: size);
      tasks.add(task);
      await _processUpload(task, file, parentId: parentId);
    }
    final dash = Get.find<DashboardController>();
    dash.loadFiles(parentId: dash.currentParentId.value);
    dash.loadCapacity();
  }

  Future<void> _processUpload(UploadTask task, File file, {String? parentId}) async {
    task.status = 'uploading';
    tasks.refresh();
    try {
      final hash = await _computeHash(file);
      final quick = await _repo.quickUpload(hash, task.fileName, task.totalSize,
          parentId: parentId);
      if (quick != null) {
        task.status = 'done';
        task.uploadedBytes = task.totalSize;
        tasks.refresh();
        return;
      }

      if (task.totalSize <= 10 * 1024 * 1024) {
        await _repo.uploadFile(file.path, task.fileName, task.totalSize,
            parentId: parentId, onProgress: (sent, total) {
          task.uploadedBytes = sent;
          tasks.refresh();
        });
      } else {
        await _chunkedUpload(task, file, parentId: parentId);
      }
      task.status = 'done';
    } catch (e) {
      task.status = 'error';
      task.error = e.toString();
    }
    tasks.refresh();
  }

  Future<void> _chunkedUpload(UploadTask task, File file, {String? parentId}) async {
    final totalChunks = (task.totalSize / _chunkSize).ceil();
    final uploadId = const Uuid().v4();
    final bytes = await file.readAsBytes();

    for (int i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize).clamp(0, task.totalSize);
      final chunk = bytes.sublist(start, end);
      await _repo.uploadChunk(uploadId, i, totalChunks, chunk, task.fileName,
          parentId: parentId);
      task.uploadedBytes = end;
      tasks.refresh();
    }
  }

  Future<String> _computeHash(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  void dismiss() {
    tasks.removeWhere((t) => t.status == 'done' || t.status == 'error');
    if (tasks.isEmpty) isVisible.value = false;
  }
}
