import 'package:get_storage/get_storage.dart';

class LocalStorage {
  static final _box = GetStorage();

  static const _keyToken = 'token';
  static const _keyServerUrl = 'server_url';
  static const _defaultServer = 'http://localhost:8080';

  static String get token => _box.read(_keyToken) ?? '';
  static bool get hasToken => token.isNotEmpty;
  static void saveToken(String t) => _box.write(_keyToken, t);
  static void clearToken() => _box.remove(_keyToken);

  static String get serverUrl => _box.read(_keyServerUrl) ?? _defaultServer;
  static void saveServerUrl(String url) => _box.write(_keyServerUrl, url);
}
