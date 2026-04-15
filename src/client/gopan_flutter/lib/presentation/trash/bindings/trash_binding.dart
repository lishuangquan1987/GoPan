import 'package:get/get.dart';
import '../controllers/trash_controller.dart';
import '../../../data/repositories/file_repository.dart';

class TrashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TrashController(Get.find<FileRepository>()));
  }
}
