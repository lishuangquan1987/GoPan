import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/repositories/share_repository.dart';
import '../../../data/models/share_model.dart';
import '../../../data/models/file_node_model.dart';

class ShareController extends GetxController {
  final ShareRepository _repo;
  ShareController(this._repo);

  final shares = <ShareModel>[].obs;
  final isLoading = false.obs;

  // For share access view
  final accessNode = Rxn<Map<String, dynamic>>();
  final accessFiles = <FileNode>[].obs;
  final accessCode = ''.obs;
  final needPassword = false.obs;
  final accessError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final code = Get.parameters['code'];
    if (code != null && code.isNotEmpty) {
      accessCode.value = code;
      loadShare(code);
    } else {
      loadMyShares();
    }
  }

  Future<void> loadMyShares() async {
    isLoading.value = true;
    try {
      shares.value = await _repo.getMyShares();
    } catch (_) {
      Get.snackbar('错误', '加载分享列表失败');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteShare(String id) async {
    try {
      await _repo.deleteShare(id);
      shares.removeWhere((s) => s.id == id);
    } catch (_) {
      Get.snackbar('错误', '删除分享失败');
    }
  }

  void shareLink(String code) {
    final link = _repo.shareLink(code);
    Share.share(link, subject: 'GoPan 分享链接');
  }

  Future<void> openInBrowser(String code) async {
    final url = Uri.parse(_repo.shareLink(code));
    if (await canLaunchUrl(url)) launchUrl(url);
  }

  String getLinkForCode(String code) => _repo.shareLink(code);

  Future<ShareModel?> createShare(String nodeId, {
    int shareType = 0,
    DateTime? expiresAt,
    String? password,
  }) async {
    try {
      final share = await _repo.createShare(nodeId,
          shareType: shareType, expiresAt: expiresAt,
          password: password?.isEmpty == true ? null : password);
      shares.insert(0, share);
      return share;
    } catch (_) {
      Get.snackbar('错误', '创建分享失败');
      return null;
    }
  }

  // Share access
  Future<void> loadShare(String code, {String? password}) async {
    isLoading.value = true;
    accessError.value = '';
    try {
      final data = await _repo.getShare(code, password: password);
      accessNode.value = data;
      if (data['is_folder'] == true) {
        accessFiles.value = (data['files'] as List? ?? [])
            .map((e) => FileNode.fromJson(e))
            .toList();
      }
      needPassword.value = false;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('password')) {
        needPassword.value = true;
      } else {
        accessError.value = '分享不存在或已过期';
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveToMyDrive() async {
    try {
      await _repo.saveToMyDrive(accessCode.value);
      Get.snackbar('成功', '已保存到我的网盘');
    } catch (_) {
      Get.snackbar('错误', '保存失败');
    }
  }
}
