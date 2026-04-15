import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/upload_controller.dart';
import '../../../data/repositories/file_repository.dart';
import '../../../data/repositories/auth_repository.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DashboardController(
          Get.find<FileRepository>(),
          Get.find<AuthRepository>(),
        ));
    Get.lazyPut(() => UploadController(Get.find<FileRepository>()));
  }
}
