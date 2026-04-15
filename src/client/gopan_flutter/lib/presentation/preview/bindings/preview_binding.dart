import 'package:get/get.dart';
import '../controllers/preview_controller.dart';
import '../../../data/repositories/file_repository.dart';

class PreviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PreviewController(Get.find<FileRepository>()));
  }
}
