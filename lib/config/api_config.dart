/// Centralized API endpoints for the VoxGuard backend and AI microservices.
///
/// Network calls should reference these constants instead of hard-coding the
/// host, so the address only ever has to change in one place.
class ApiConfig {
  const ApiConfig._();

  /// Host shared by the backend and the AI microservices.
  static const String host = 'http://192.168.1.191';

  /// Base address of the main REST API (Laravel backend).
  static const String baseUrl = '$host:8000/api';

  /// SOS / emergency endpoints, e.g. `$sosBaseUrl/start`.
  static const String sosBaseUrl = '$baseUrl/sos';

  // --- AI microservices ------------------------------------------------------

  /// Speech-to-text service.
  static const String sttUrl = '$host:8003/transcribe';

  /// Emotion / voice-stress analysis service.
  static const String emotionUrl = '$host:8001/analyze-smart/';

  /// Backend danger-word dictionary check.
  static const String dictionaryCheckUrl = '$baseUrl/dictionary/check';

  /// Backend storage for periodic monitoring recordings (when no SOS is
  /// active). NOTE: assumed route — adjust to match your backend.
  static const String monitorAudioUrl = '$baseUrl/monitor/audio';
}
