import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/file_repository.dart';
import '../../data/repositories/share_repository.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ApiClient(), permanent: true);
    Get.lazyPut(() => AuthRepository(Get.find()), fenix: true);
    Get.lazyPut(() => FileRepository(Get.find()), fenix: true);
    Get.lazyPut(() => ShareRepository(Get.find()), fenix: true);
  }
}
