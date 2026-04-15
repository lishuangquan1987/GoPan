import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';
import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'core/storage/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // Initialize window_manager for desktop platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1100, 700),
        minimumSize: Size(800, 500),
        center: true,
        title: 'GoPan 网盘',
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(const GoPanApp());
}

class GoPanApp extends StatelessWidget {
  const GoPanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'GoPan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0078D4)),
        useMaterial3: true,
      ),
      initialBinding: InitialBinding(),
      initialRoute: LocalStorage.hasToken ? AppRoutes.dashboard : AppRoutes.login,
      getPages: AppPages.pages,
    );
  }
}
