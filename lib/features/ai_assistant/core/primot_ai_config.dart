import 'package:flutter/foundation.dart';

class PrimotAiConfig {
  static const String _envUrl = String.fromEnvironment('PRIMOT_AI_URL');

  /// Base URL of the Primot AI FastAPI Backend.
  /// Overridable via `--dart-define=PRIMOT_AI_URL=http://...`
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  /// Network timeout for chat inference (accommodates local model cold-start and prefill)
  static const Duration requestTimeout = Duration(seconds: 95);
}
