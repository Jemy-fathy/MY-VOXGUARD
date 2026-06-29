/// Centralized API endpoints for the VoxGuard backend and AI microservices.
class ApiConfig {
  const ApiConfig._();

  
  static const String _backendHost = 'http://192.168.1.191:8000';
  static const String _sttHost = 'http://192.168.1.191:8003';
  static const String _emotionHost = 'http://192.168.1.191:8001';

  // --- Endpoints ---

  /// Backend API base
  static const String baseUrl = '$_backendHost/api';

  /// SOS / emergency endpoints
  static const String sosBaseUrl = '$baseUrl/sos';

  /// Speech-to-text service
  static const String sttUrl = '$_sttHost/transcribe';

  /// Emotion / voice-stress analysis service
  static const String emotionUrl = '$_emotionHost/analyze-smart/';

  /// Backend danger-word dictionary check
  static const String dictionaryCheckUrl = '$baseUrl/dictionary/check';

  /// Backend storage for periodic monitoring recordings
  static const String monitorAudioUrl = '$baseUrl/monitor/audio';
}