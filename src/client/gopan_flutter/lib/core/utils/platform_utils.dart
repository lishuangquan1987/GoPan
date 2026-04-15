import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformUtils {
  static bool get isDesktop =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWeb => kIsWeb;

  static bool isDesktopLayout(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;
}
