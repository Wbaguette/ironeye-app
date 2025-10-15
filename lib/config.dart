import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  final String webrtcUrl;
  final String playbackUrl;
  
  const Config._({
    required this.webrtcUrl,
    required this.playbackUrl,
  });
     
  static bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    if (!uri.hasScheme || uri.host.isEmpty) return false;
    
    if (!['http'].contains(uri.scheme.toLowerCase())) return false;
    
    return true;
  }
  
  static String _processUrl(String envKey) {
    String? envValue = dotenv.env[envKey];

    if (envValue == null || envValue.trim().isEmpty) {
      final error = 'FATAL: $envKey is missing or empty in .env file';
      throw ConfigurationException(error);
    }
    
    if (!_isValidUrl(envValue)) {
      final error = 'FATAL: $envKey contains invalid URL format: $envValue';
      throw ConfigurationException(error);
    }
    
    return envValue;
  }
  
  factory Config.create() {
    try {
      final webrtcUrl = _processUrl('WEBRTC_URL');
      final playbackUrl = _processUrl('PLAYBACK_URL');
      
      final config = Config._(
        webrtcUrl: webrtcUrl,
        playbackUrl: playbackUrl,
      );
      
      return config;
    } catch (e) {
      if (kDebugMode) {
        developer.log('Configuration Error: $e', name: 'Config');
      }
      
      rethrow; 
    }
  }
  
  // TODO: Need right date formatting 
  String buildPlaybackUrl({required String start, required String end}) {
    return playbackUrl
        .replaceAll('[start]', start)
        .replaceAll('[end]', end);
  }
}

class ConfigurationException implements Exception {
  final String message;
  const ConfigurationException(this.message);
  
  @override
  String toString() => 'ConfigurationException: $message';
}

// Global configuration instance - will throw if configuration is invalid
final config = Config.create();