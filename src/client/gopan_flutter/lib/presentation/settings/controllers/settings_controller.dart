import 'package:get/get.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../app/routes/app_routes.dart';
import '../../../data/repositories/auth_repository.dart';

class SettingsController extends GetxController {
  final serverUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    serverUrl.value = LocalStorage.serverUrl;
  }

  void saveServerUrl(String url) {
    final trimmed = url.trim().replaceAll(RegExp(r'/$'), '');
    if (trimmed.isEmpty) return;
    LocalStorage.saveServerUrl(trimmed);
    Get.find<ApiClient>().updateBaseUrl(trimmed);
    serverUrl.value = trimmed;
    Get.snackbar('成功', '服务器地址已更新');
  }

  Future<void> logout() async {
    try {
      await Get.find<AuthRepository>().logout();
    } catch (_) {}
    Get.offAllNamed(AppRoutes.login);
  }
}
