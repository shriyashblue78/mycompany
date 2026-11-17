import 'package:flutter/foundation.dart';

class PrimotAiConfig {
  static const String _envUrl = String.fromEnvironment('PRIMOT_AI_URL');

  /// Base URL of the deployed Primot AI FastAPI Backend.
  /// Default: https://api.primotai.tech
  /// Overridable via `--dart-define=PRIMOT_AI_URL=...`
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    return 'https://api.primotai.tech';
  }

  /// Network timeout for chat inference (accommodates cloud/model inference and cold-starts)
  static const Duration requestTimeout = Duration(seconds: 95);
}
