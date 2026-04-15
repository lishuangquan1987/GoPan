import 'package:get/get.dart';
import '../../presentation/auth/bindings/auth_binding.dart';
import '../../presentation/auth/views/login_view.dart';
import '../../presentation/dashboard/bindings/dashboard_binding.dart';
import '../../presentation/dashboard/views/dashboard_view.dart';
import '../../presentation/preview/bindings/preview_binding.dart';
import '../../presentation/preview/views/preview_view.dart';
import '../../presentation/share/bindings/share_binding.dart';
import '../../presentation/share/views/share_list_view.dart';
import '../../presentation/share/views/share_access_view.dart';
import '../../presentation/trash/bindings/trash_binding.dart';
import '../../presentation/trash/views/trash_view.dart';
import '../../presentation/settings/views/settings_view.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.preview,
      page: () => const PreviewView(),
      binding: PreviewBinding(),
    ),
    GetPage(
      name: AppRoutes.shareList,
      page: () => const ShareListView(),
      binding: ShareBinding(),
    ),
    GetPage(
      name: AppRoutes.shareAccess,
      page: () => const ShareAccessView(),
      binding: ShareBinding(),
    ),
    GetPage(
      name: AppRoutes.trash,
      page: () => const TrashView(),
      binding: TrashBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
    ),
  ];
}
