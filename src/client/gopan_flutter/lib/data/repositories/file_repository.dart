import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/file_node_model.dart';
import '../models/capacity_model.dart';

class FileRepository {
  final ApiClient _api;
  FileRepository(this._api);

  Future<FileListResponse> getFiles({
    String? parentId,
    int page = 1,
    int pageSize = 50,
    String sortBy = 'name',
    String order = 'asc',
  }) async {
    final res = await _api.get(ApiEndpoints.files, params: {
      if (parentId != null) 'parent_id': parentId,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'order': order,
    });
    return FileListResponse.fromJson(res.data);
  }

  Future<List<FileNode>> getTree() async {
    final res = await _api.get(ApiEndpoints.tree);
    return (res.data as List).map((e) => FileNode.fromJson(e)).toList();
  }

  Future<List<FileNode>> search(String keyword) async {
    final res = await _api.get(ApiEndpoints.search, params: {'keyword': keyword});
    return (res.data['files'] as List? ?? []).map((e) => FileNode.fromJson(e)).toList();
  }

  Future<FileNode> createFolder(String name, {String? parentId}) async {
    final res = await _api.post(ApiEndpoints.folder,
        data: {'name': name, if (parentId != null) 'parent_id': parentId});
    return FileNode.fromJson(res.data['folder']);
  }

  Future<void> rename(String id, String name) async {
    await _api.put(ApiEndpoints.fileById(id), data: {'name': name});
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiEndpoints.fileById(id));
  }

  Future<void> move(List<String> ids, String? targetId) async {
    await _api.put(ApiEndpoints.moveFiles(),
        data: {'ids': ids, 'target_id': targetId});
  }

  Future<void> copy(List<String> ids, String? targetId) async {
    await _api.put(ApiEndpoints.copyFiles(),
        data: {'ids': ids, 'target_id': targetId});
  }

  Future<FileNode> uploadFile(
    String filePath,
    String fileName,
    int fileSize, {
    String? parentId,
    void Function(int, int)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      if (parentId != null) 'parent_id': parentId,
    });
    final res = await _api.postForm(ApiEndpoints.upload, form,
        onSendProgress: onProgress);
    return FileNode.fromJson(res.data['file']);
  }

  Future<Map<String, dynamic>> checkUploadStatus(
      String uploadId, int totalChunks) async {
    final res = await _api.post(ApiEndpoints.uploadStatus,
        data: {'upload_id': uploadId, 'total_chunks': totalChunks});
    return res.data;
  }

  Future<Map<String, dynamic>> uploadChunk(
    String uploadId,
    int chunkIndex,
    int totalChunks,
    List<int> bytes,
    String fileName, {
    String? parentId,
    void Function(int, int)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'upload_id': uploadId,
      'chunk_index': chunkIndex,
      'total_chunks': totalChunks,
      'filename': fileName,
      if (parentId != null) 'parent_id': parentId,
      'chunk': MultipartFile.fromBytes(bytes, filename: 'chunk'),
    });
    final res = await _api.postForm(ApiEndpoints.uploadChunk, form,
        onSendProgress: onProgress);
    return res.data;
  }

  Future<FileNode?> quickUpload(String hash, String fileName,
      int fileSize, {String? parentId}) async {
    try {
      final res = await _api.post(ApiEndpoints.quickUpload, data: {
        'hash': hash,
        'filename': fileName,
        'size': fileSize,
        if (parentId != null) 'parent_id': parentId,
      });
      return FileNode.fromJson(res.data['file']);
    } catch (_) {
      return null; // 404 = need actual upload
    }
  }

  Future<String> getDownloadUrl(String id) =>
      Future.value(_api.fullUrl(ApiEndpoints.download(id)));

  Future<void> downloadFile(String id, String savePath,
      {void Function(int, int)? onReceiveProgress}) async {
    await _api.download(
        ApiEndpoints.download(id), savePath,
        onReceiveProgress: onReceiveProgress);
  }

  Future<List<FileNode>> getTrash() async {
    final res = await _api.get(ApiEndpoints.trash);
    return (res.data['files'] as List? ?? []).map((e) => FileNode.fromJson(e)).toList();
  }

  Future<void> restore(List<String> ids) async {
    await _api.post(ApiEndpoints.restore, data: {'ids': ids});
  }

  Future<void> permanentlyDelete(String id) async {
    await _api.delete(ApiEndpoints.trashById(id));
  }

  Future<CapacityModel> getCapacity() async {
    final res = await _api.get(ApiEndpoints.capacity);
    return CapacityModel.fromJson(res.data);
  }

  String proxyUrl(String id) => _api.fullUrl(ApiEndpoints.proxy(id));
}
