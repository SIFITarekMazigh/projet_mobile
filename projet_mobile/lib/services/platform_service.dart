import 'package:flutter/foundation.dart';

class PlatformService {
  // Singleton pattern
  static final PlatformService _instance = PlatformService._internal();
  factory PlatformService() => _instance;
  PlatformService._internal();

  // Check if running on web
  bool get isWeb => kIsWeb;

  // Check if running on mobile (Android or iOS)
  bool get isMobile => !kIsWeb;
}
