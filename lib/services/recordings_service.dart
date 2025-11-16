import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dashcamapp/config.dart';
import 'package:dashcamapp/utils/date_utils.dart' as date_utils;
import 'package:dashcamapp/services/log_service.dart';

class RecordingsService {
  
  /// Fetches available recordings for a specific date
  static Future<List<Recording>> fetchRecordingsForDate(DateTime date) async {
    try {
      // Keep the date in local time since recordings are stored in local time on server
      // Get start and end of the selected day in local time
      final startOfDay = date_utils.DateUtils.getStartOfDay(date);
      final endOfDay = date_utils.DateUtils.getEndOfDay(date);
      
      // Convert to RFC3339 but keep local timezone
      final startRFC3339 = date_utils.DateUtils.toRFC3339Local(startOfDay);
      final endRFC3339 = date_utils.DateUtils.toRFC3339Local(endOfDay);
      
      // Use the buildListUrl method from config with raw RFC3339 strings
      final url = config.buildListUrl(
        path: 'ironeye',
        start: startRFC3339,
        end: endRFC3339,
      );

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Request timed out after 60 seconds');
        },
      );
      
      if (response.statusCode == 200) {
        try {
          final List<dynamic> jsonData = json.decode(response.body);
          
          await LogService.log(
            level: LogLevel.info,
            category: LogCategory.recordings,
            title: 'Raw response received',
            details: 'Received ${jsonData.length} recordings, response size: ${response.body.length} bytes',
            metadata: {
              'recordingCount': jsonData.length,
              'responseSize': response.body.length,
              'url': url,
            },
          );
          
          // Parse recordings with error handling for corrupted entries
          final recordings = <Recording>[];
          for (var json in jsonData) {
            try {
              recordings.add(Recording.fromJson(json));
            } catch (e) {
              await LogService.log(
                level: LogLevel.warning,
                category: LogCategory.recordings,
                title: 'Skipped corrupted recording',
                details: 'Failed to parse recording: $e',
                metadata: {'json': json},
              );
            }
          }
          
          await LogService.log(
            level: LogLevel.info,
            category: LogCategory.recordings,
            title: 'Recordings fetched successfully',
            details: 'Found ${recordings.length} recordings for ${date.toLocal().toString().split(' ')[0]}',
            metadata: {
              'count': recordings.length,
              'date': date.toIso8601String(),
              'url': url,
              'responseSize': response.body.length,
              'firstRecording': jsonData.isNotEmpty ? jsonData.first : null,
            },
          );
          
          return recordings;
        } catch (e) {
          await LogService.log(
            level: LogLevel.error,
            category: LogCategory.recordings,
            title: 'Failed to parse response',
            details: 'Error parsing JSON response: $e',
            metadata: {
              'url': url,
              'responseBody': response.body.length > 10000 
                ? '${response.body.substring(0, 10000)}... (truncated, total: ${response.body.length} bytes)'
                : response.body,
              'statusCode': response.statusCode,
            },
          );
          throw Exception('Failed to parse recordings response: $e');
        }
      } else if (response.statusCode == 404) {
        await LogService.log(
          level: LogLevel.info,
          category: LogCategory.recordings,
          title: 'No recordings found',
          details: 'No recordings available for ${date.toLocal().toString().split(' ')[0]}',
        );
        return [];
      } else {
        await LogService.log(
          level: LogLevel.error,
          category: LogCategory.recordings,
          title: 'Failed to fetch recordings',
          details: 'HTTP ${response.statusCode}',
          metadata: {
            'statusCode': response.statusCode,
            'url': url,
            'responseBody': response.body,
            'headers': response.headers,
          },
        );
        throw Exception('Failed to fetch recordings: ${response.statusCode}');
      }
    } catch (e) {
      await LogService.log(
        level: LogLevel.error,
        category: LogCategory.network,
        title: 'Network error fetching recordings',
        details: e.toString(),
      );
      throw Exception('Network error: $e');
    }
  }
  
  /// Downloads a recording file
  static Future<void> downloadRecording(Recording recording) async {
    try {
      final response = await http.get(
        Uri.parse(recording.getDownloadUrl()),
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
      await LogService.log(
        level: LogLevel.warning,
        category: LogCategory.recordings,
        title: 'Download not supported',
        details: 'Downloads are only supported on mobile platforms',
      );
      throw Exception('Downloads are only supported on mobile platforms');
    }
    
    await LogService.log(
      level: LogLevel.info,
      category: LogCategory.recordings,
      title: 'Download started',
      details: 'Starting download: ${durationSeconds.round()}s segment at ${offsetSeconds.round()}s offset',
      metadata: {
        'offsetSeconds': offsetSeconds,
        'durationSeconds': durationSeconds,
      },
    );
    
    try {
      final customUrl = recording.getDownloadUrl(
        offsetSeconds: offsetSeconds,
        customDuration: durationSeconds,
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
      
      await LogService.log(
        level: LogLevel.info,
        category: LogCategory.recordings,
        title: 'Download completed',
        details: 'Successfully downloaded ${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
        metadata: {
          'fileName': fileName,
          'sizeBytes': response.bodyBytes.length,
          'url': customUrl,
          'offsetSeconds': offsetSeconds,
          'durationSeconds': durationSeconds,
          'statusCode': response.statusCode,
          'contentType': response.headers['content-type'],
        },
      );
      
      return filePath;
    } on SocketException {
      await LogService.log(
        level: LogLevel.error,
        category: LogCategory.network,
        title: 'Download failed',
        details: 'No internet connection',
      );
      throw Exception('No internet connection');
    } on TimeoutException {
      await LogService.log(
        level: LogLevel.error,
        category: LogCategory.recordings,
        title: 'Download timed out',
        details: 'Connection timed out after 5 minutes',
      );
      throw Exception('Connection timed out');
    } on FormatException {
      await LogService.log(
        level: LogLevel.error,
        category: LogCategory.recordings,
        title: 'Download failed',
        details: 'Invalid URL format',
      );
      throw Exception('Invalid URL format');
    } catch (e) {
      await LogService.log(
        level: LogLevel.error,
        category: LogCategory.recordings,
        title: 'Download failed',
        details: e.toString(),
      );
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
  final String path;
  final String format;
  
  const Recording({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.path,
    required this.format,
  });
  
  /// Creates a Recording from JSON (API response)
  factory Recording.fromJson(Map<String, dynamic> json) {
    // Parse the DateTime - keep as local time since server stores in local time
    final parsedTime = DateTime.parse(json['start'] as String);
    final startTime = parsedTime.isUtc ? parsedTime.toLocal() : parsedTime;
    
    final duration = (json['duration'] as num).toDouble();
    final endTime = startTime.add(Duration(milliseconds: (duration * 1000).round()));
    
    // Generate a simple ID from the start time
    final id = startTime.millisecondsSinceEpoch.toString();
    
    // Extract path from URL query parameters
    final url = json['url'] as String;
    final uri = Uri.parse(url);
    final path = uri.queryParameters['path'] ?? 'ironeye';
    
    return Recording(
      id: id,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: duration,
      path: path,
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
  
  /// Generates download URL using the /get endpoint
  String getDownloadUrl({
    double? offsetSeconds,
    double? customDuration,
    String format = 'mp4',
  }) {
    // Calculate start time (add offset if provided)
    // startTime is in local time, keep it that way for the server
    final downloadStartTime = offsetSeconds != null 
        ? startTime.add(Duration(milliseconds: (offsetSeconds * 1000).round()))
        : startTime;
    
    // Use toRFC3339Local to maintain local timezone for server
    final startRFC3339 = date_utils.DateUtils.toRFC3339Local(downloadStartTime);
    
    // Calculate the maximum available duration from the download start time
    final maxAvailableDuration = endTime.difference(downloadStartTime).inMilliseconds / 1000.0;
    
    // Use custom duration if provided, otherwise use full recording duration
    // Clamp duration to not exceed what's available
    var duration = customDuration ?? durationSeconds;
    if (offsetSeconds != null && duration > maxAvailableDuration) {
      duration = maxAvailableDuration;
    }
    
    // Build the download URL using config (encoding handled by config)
    return config.buildGetUrl(
      path: path,
      start: startRFC3339,
      duration: duration.toString(),
      format: format,
    );
  }
}