import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dashcamapp/config.dart';
import 'package:dashcamapp/utils/date_utils.dart' as date_utils;

class RecordingsService {
  
  /// Fetches available recordings for a specific date
  static Future<List<Recording>> fetchRecordingsForDate(DateTime date) async {
    try {
      // Convert date to RFC3339 format for the API
      final startOfDay = date_utils.DateUtils.getStartOfDay(date);
      final endOfDay = date_utils.DateUtils.getEndOfDay(date);
      
      final startRFC3339 = date_utils.DateUtils.toRFC3339(startOfDay);
      final endRFC3339 = date_utils.DateUtils.toRFC3339(endOfDay);
      
      // URL encode the parameters
      final encodedStart = Uri.encodeComponent(startRFC3339);
      final encodedEnd = Uri.encodeComponent(endRFC3339);
      
      // Use the buildPlaybackUrl method from config with encoded parameters
      final url = config.buildPlaybackUrl(
        start: encodedStart,
        end: encodedEnd,
      );

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final recordings = jsonData.map((json) => Recording.fromJson(json)).toList();
        return recordings;
      } else if (response.statusCode == 404) {
        // No recordings found for this date
        return [];
      } else {
        throw Exception('Failed to fetch recordings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// Downloads a recording file
  static Future<void> downloadRecording(Recording recording) async {
    try {
      final response = await http.get(
        Uri.parse(recording.downloadUrl),
        headers: {
          'Accept': 'application/octet-stream',
        },
      );
      
      if (response.statusCode == 200) {
        // TODO: Implement actual file saving logic
        // This would typically involve using a plugin like path_provider
        // and file_picker to save the file to the user's device
        // For now, we'll simulate a successful download
        await Future.delayed(const Duration(seconds: 2)); // Simulate download time
        // In a real implementation, you would save response.bodyBytes to a file
        return; // Success
      } else {
        throw Exception('Failed to download recording: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Download error: $e');
    }
  }
  
  /// Downloads a custom segment of a recording with specific offset and duration
  /// Only supports mobile platforms (iOS/Android)
  static Future<String> downloadCustomSegment({
    required Recording recording,
    required double offsetSeconds,
    required double durationSeconds,
  }) async {
    if (kIsWeb) {
      throw Exception('Downloads are only supported on mobile platforms');
    }
    
    try {
      final customUrl = recording.getCustomDownloadUrl(
        offsetSeconds: offsetSeconds,
        downloadDurationSeconds: durationSeconds,
        format: 'mp4',
      );
      
      if (customUrl.isEmpty) {
        throw Exception('Invalid download URL');
      }
      
      // Generate filename based on recording time and duration
      final startTime = recording.startTime.add(Duration(seconds: offsetSeconds.round()));
      final formattedTime = startTime.toLocal().toString().replaceAll(':', '-').replaceAll(' ', '_').substring(0, 19);
      final fileName = 'dashcam_${formattedTime}_${durationSeconds.round()}s.mp4';
      
      // Download the file using http
      final response = await http.get(
        Uri.parse(customUrl),
        headers: {'Accept': 'application/octet-stream'},
      ).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Download timed out after 5 minutes');
        },
      );
      
      if (response.statusCode == 404) {
        throw Exception('Recording not found on server');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to recording');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error (${response.statusCode})');
      } else if (response.statusCode != 200) {
        throw Exception('Download failed with status code ${response.statusCode}');
      }
      
      if (response.bodyBytes.isEmpty) {
        throw Exception('Downloaded file is empty');
      }
      
      // For iOS, save to temp directory and return the path
      final tempDir = Directory.systemTemp;
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      
      try {
        await file.writeAsBytes(response.bodyBytes);
      } catch (e) {
        throw Exception('Failed to save file: $e');
      }
      
      if (!await file.exists()) {
        throw Exception('File was not saved successfully');
      }
      
      return filePath;
    } on SocketException {
      throw Exception('No internet connection');
    } on TimeoutException {
      throw Exception('Connection timed out');
    } on FormatException {
      throw Exception('Invalid URL format');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unexpected error: $e');
    }
  }
}

/// Data class representing a recording
class Recording {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double durationSeconds;
  final String downloadUrl;
  final String format;
  
  const Recording({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.downloadUrl,
    required this.format,
  });
  
  /// Creates a Recording from JSON (API response)
  factory Recording.fromJson(Map<String, dynamic> json) {
    // Parse the DateTime and ensure it's converted to local time
    final parsedTime = DateTime.parse(json['start'] as String);
    // If the parsed time is UTC, convert to local time
    final startTime = parsedTime.isUtc ? parsedTime.toLocal() : parsedTime;
    
    final duration = (json['duration'] as num).toDouble();
    final endTime = startTime.add(Duration(milliseconds: (duration * 1000).round()));
    
    // Generate a simple ID from the start time
    final id = startTime.millisecondsSinceEpoch.toString();
    
    return Recording(
      id: id,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: duration,
      downloadUrl: json['url'] as String,
      format: 'mp4', // Default format since it's not provided in API
    );
  }
  
  /// Gets human readable file size (estimated based on duration)
  String get humanReadableSize {
    // Estimate file size based on duration (rough approximation)
    // Assuming ~1MB per minute for typical dash cam quality
    final estimatedMB = durationSeconds / 60;
    if (estimatedMB < 1) {
      return '~${(estimatedMB * 1024).toStringAsFixed(0)} KB';
    } else if (estimatedMB < 1024) {
      return '~${estimatedMB.toStringAsFixed(1)} MB';
    } else {
      return '~${(estimatedMB / 1024).toStringAsFixed(1)} GB';
    }
  }
  
  /// Gets human readable duration
  String get humanReadableDuration {
    final totalSeconds = durationSeconds.round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  /// Generates streaming URL for video preview using the /get endpoint
  String getStreamingUrl({String format = 'fmp4'}) {
    // Extract base URL and path from the original downloadUrl
    final uri = Uri.parse(downloadUrl);
    final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';
    String path = '';
    
    // Try to extract path from query parameters
    if (uri.queryParameters.containsKey('path')) {
      path = uri.queryParameters['path']!;
    } else {
      // If no path query param, use the path component or default
      path = uri.path.replaceFirst('/', '');
      if (path.isEmpty) {
        path = 'ironeye'; // Default path based on your API calls
      }
    }
    
    // Convert start time to RFC3339 format (UTC for API)
    final startTimeUtc = startTime.toUtc();
    final startRFC3339 = startTimeUtc.toIso8601String();
    
    // Build the streaming URL with proper encoding
    final encodedPath = Uri.encodeComponent(path);
    final encodedStart = Uri.encodeComponent(startRFC3339);
    final encodedDuration = Uri.encodeComponent(durationSeconds.toString());
    final encodedFormat = Uri.encodeComponent(format);
    
    final streamingUrl = '$baseUrl/get?path=$encodedPath&start=$encodedStart&duration=$encodedDuration&format=$encodedFormat';
 
    return streamingUrl;
  }
  
  /// Generates custom download URL with specific offset and duration
  String getCustomDownloadUrl({
    required double offsetSeconds,
    required double downloadDurationSeconds,
    String format = 'mp4'
  }) {
    // Extract base URL and path from the original downloadUrl
    final uri = Uri.parse(downloadUrl);
    final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';
    String path = '';
    
    // Try to extract path from query parameters
    if (uri.queryParameters.containsKey('path')) {
      path = uri.queryParameters['path']!;
    } else {
      // If no path query param, use the path component or default
      path = uri.path.replaceFirst('/', '');
      if (path.isEmpty) {
        path = 'ironeye'; // Default path based on your API calls
      }
    }
    
    // Calculate the new start time by adding offset to the original start time
    final customStartTime = startTime.add(Duration(milliseconds: (offsetSeconds * 1000).round()));
    final customStartTimeUtc = customStartTime.toUtc();
    final customStartRFC3339 = customStartTimeUtc.toIso8601String();
    
    // Build the custom download URL with proper encoding
    final encodedPath = Uri.encodeComponent(path);
    final encodedStart = Uri.encodeComponent(customStartRFC3339);
    final encodedDuration = Uri.encodeComponent(downloadDurationSeconds.toString());
    final encodedFormat = Uri.encodeComponent(format);
    
    return '$baseUrl/get?path=$encodedPath&start=$encodedStart&duration=$encodedDuration&format=$encodedFormat';
  }
}