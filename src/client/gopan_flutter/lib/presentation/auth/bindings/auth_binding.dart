import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../../data/repositories/auth_repository.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AuthController(Get.find<AuthRepository>()));
  }
}
