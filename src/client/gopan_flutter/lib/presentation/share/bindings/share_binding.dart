import 'package:get/get.dart';
import '../controllers/share_controller.dart';
import '../../../data/repositories/share_repository.dart';

class ShareBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ShareController(Get.find<ShareRepository>()));
  }
}
