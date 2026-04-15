import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/local_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _api;
  AuthRepository(this._api);

  Future<String> login(String username, String password) async {
    final res = await _api.post(ApiEndpoints.login,
        data: {'username': username, 'password': password});
    final token = res.data['token'] as String;
    LocalStorage.saveToken(token);
    return token;
  }

  Future<void> register(String username, String password, String email) async {
    final res = await _api.post(ApiEndpoints.register,
        data: {'username': username, 'password': password, 'email': email});
    final token = res.data['token'] as String;
    LocalStorage.saveToken(token);
  }

  Future<UserModel> me() async {
    final res = await _api.get(ApiEndpoints.me);
    return UserModel.fromJson(res.data);
  }

  Future<void> logout() async {
    await _api.post(ApiEndpoints.logout);
    LocalStorage.clearToken();
  }
}
