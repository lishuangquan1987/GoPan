import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/local_storage.dart';
import '../models/share_model.dart';
import '../models/file_node_model.dart';

class ShareRepository {
  final ApiClient _api;
  ShareRepository(this._api);

  Future<ShareModel> createShare(String nodeId, {
    int shareType = 0,
    DateTime? expiresAt,
    String? password,
    int? maxAccessCount,
  }) async {
    final res = await _api.post(ApiEndpoints.shares, data: {
      'node_id': nodeId,
      'share_type': shareType,
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      if (password != null && password.isNotEmpty) 'password': password,
      if (maxAccessCount != null) 'max_access_count': maxAccessCount,
    });
    return ShareModel.fromJson(res.data['share']);
  }

  Future<List<ShareModel>> getMyShares() async {
    final res = await _api.get(ApiEndpoints.shares);
    return (res.data['shares'] as List? ?? [])
        .map((e) => ShareModel.fromJson(e))
        .toList();
  }

  Future<void> deleteShare(String id) async {
    await _api.delete(ApiEndpoints.shareById(id));
  }

  Future<Map<String, dynamic>> getShare(String code, {String? password}) async {
    final res = await _api.get(ApiEndpoints.shareByCode(code),
        params: {if (password != null) 'password': password});
    return res.data;
  }

  Future<List<FileNode>> getShareFolder(String code, String folderId,
      {String? password}) async {
    final res = await _api.get(ApiEndpoints.shareFolder(code, folderId),
        params: {if (password != null) 'password': password});
    return (res.data['files'] as List? ?? [])
        .map((e) => FileNode.fromJson(e))
        .toList();
  }

  Future<void> saveToMyDrive(String code, {String? targetId}) async {
    await _api.post(ApiEndpoints.shareSave(code),
        data: {if (targetId != null) 'target_id': targetId});
  }

  String shareLink(String code) =>
      '${LocalStorage.serverUrl}/share.html?code=$code';

  String shareDownloadUrl(String code) =>
      _api.fullUrl(ApiEndpoints.shareDownload(code));
}
