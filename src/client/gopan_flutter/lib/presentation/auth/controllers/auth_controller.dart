import 'package:get/get.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../app/routes/app_routes.dart';

class AuthController extends GetxController {
  final AuthRepository _repo;
  AuthController(this._repo);

  final isLoading = false.obs;
  final isRegisterMode = false.obs;
  final errorMsg = ''.obs;

  Future<void> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      errorMsg.value = '请输入用户名和密码';
      return;
    }
    isLoading.value = true;
    errorMsg.value = '';
    try {
      await _repo.login(username, password);
      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      errorMsg.value = _parseError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register(String username, String password, String email) async {
    if (username.isEmpty || password.isEmpty) {
      errorMsg.value = '请输入用户名和密码';
      return;
    }
    if (password.length < 6) {
      errorMsg.value = '密码至少6位';
      return;
    }
    isLoading.value = true;
    errorMsg.value = '';
    try {
      await _repo.register(username, password, email);
      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      errorMsg.value = _parseError(e);
    } finally {
      isLoading.value = false;
    }
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('409') || msg.contains('already exists')) return '用户名已存在';
    if (msg.contains('401') || msg.contains('Invalid')) return '用户名或密码错误';
    if (msg.contains('SocketException') || msg.contains('connection')) return '无法连接服务器';
    return '操作失败，请重试';
  }
}
