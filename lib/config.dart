import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  const Config._({required this.webrtcUrl, required this.playbackUrl});

  factory Config.create() {
    try {
      final webrtcUrl = _processUrl('WEBRTC_URL');
      final playbackUrl = _processUrl('PLAYBACK_URL');

      final config = Config._(webrtcUrl: webrtcUrl, playbackUrl: playbackUrl);

      return config;
    } catch (e) {
      if (kDebugMode) {
        developer.log('Configuration Error: $e', name: 'Config');
      }

      rethrow;
    }
  }

  final String webrtcUrl;
  final String playbackUrl;

  static bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    if (!uri.hasScheme || uri.host.isEmpty) return false;

    if (!['http'].contains(uri.scheme.toLowerCase())) return false;

    return true;
  }

  static String _processUrl(String envKey) {
    final String? envValue = dotenv.env[envKey];

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

  String buildListUrl({
    required String path,
    required String start,
    required String end,
  }) {
    final uri = Uri.parse('$playbackUrl/list');
    final urlWithParams = uri.replace(
      queryParameters: {'path': path, 'start': start, 'end': end},
    );
    return urlWithParams.toString();
  }

  String buildGetUrl({
    required String path,
    required String start,
    required String duration,
    String format = 'mp4',
  }) {
    final uri = Uri.parse('$playbackUrl/get');
    final urlWithParams = uri.replace(
      queryParameters: {
        'path': path,
        'start': start,
        'duration': duration,
        'format': format,
      },
    );
    return urlWithParams.toString();
  }
}

class ConfigurationException implements Exception {
  const ConfigurationException(this.message);
  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}

// Global configuration instance - will throw if configuration is invalid
final config = Config.create();
