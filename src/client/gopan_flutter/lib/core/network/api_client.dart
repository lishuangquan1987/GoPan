import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import '../storage/local_storage.dart';
import '../../app/routes/app_routes.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: LocalStorage.serverUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = LocalStorage.token;
        if (token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          LocalStorage.clearToken();
          Get.offAllNamed(AppRoutes.login);
        }
        handler.next(error);
      },
    ));
  }

  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? params}) =>
      _dio.post(path, data: data, queryParameters: params);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  Future<Response> postForm(String path, FormData data,
      {void Function(int, int)? onSendProgress}) =>
      _dio.post(path, data: data, onSendProgress: onSendProgress);

  Future<Response> download(String path, String savePath,
      {void Function(int, int)? onReceiveProgress}) =>
      _dio.download(path, savePath, onReceiveProgress: onReceiveProgress);

  String fullUrl(String path) => '${_dio.options.baseUrl}$path';
}
