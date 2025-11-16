import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, warning, error }

enum LogCategory { recordings, network, system }

class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.title,
    this.details,
    this.metadata,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    try {
      return LogEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: LogLevel.values[json['level'] as int],
        category: LogCategory.values[json['category'] as int],
        title: json['title'] as String,
        details: json['details'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        category: LogCategory.system,
        title: 'Failed to parse log entry',
        details: 'Corrupted log data: ${e.toString()}',
      );
    }
  }

  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String title;
  final String? details;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.index,
    'category': category.index,
    'title': title,
    'details': details,
    'metadata': metadata,
  };

  String get categoryName {
    switch (category) {
      case LogCategory.recordings:
        return 'Recordings';
      case LogCategory.network:
        return 'Network';
      case LogCategory.system:
        return 'System';
    }
  }
}

class LogService {
  static const String _logsKey = 'app_logs';
  static const int _maxLogs = 500;
  static const int _logRetentionDays = 30;
  static Completer<void>? _writeLock;

  static Future<void> log({
    required LogLevel level,
    required LogCategory category,
    required String title,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    while (_writeLock != null && !_writeLock!.isCompleted) {
      await _writeLock!.future;
    }

    _writeLock = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = await getLogs();

      final newLog = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        title: title,
        details: details,
        metadata: metadata,
      );

      logs.insert(0, newLog);

      if (logs.length > _maxLogs) {
        logs.removeRange(_maxLogs, logs.length);
      }

      final cutoffDate = DateTime.now().subtract(
        const Duration(days: _logRetentionDays),
      );
      logs.removeWhere((log) => log.timestamp.isBefore(cutoffDate));

      await _saveLogs(prefs, logs);
    } finally {
      _writeLock?.complete();
    }
  }

  static Future<List<LogEntry>> getLogs({
    LogLevel? level,
    LogCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getString(_logsKey);

    if (logsJson == null) return [];

    final List<dynamic> decoded = json.decode(logsJson);
    var logs = decoded.map((json) => LogEntry.fromJson(json)).toList();

    final hasSearchQuery = searchQuery != null && searchQuery.isNotEmpty;
    final query = hasSearchQuery ? searchQuery.toLowerCase() : '';

    logs = logs.where((log) {
      // Filter by level
      if (level != null && log.level != level) return false;

      // Filter by category
      if (category != null && log.category != category) return false;

      // Filter by start date
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;

      // Filter by end date
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;

      // Filter by search query
      if (hasSearchQuery) {
        final matchesTitle = log.title.toLowerCase().contains(query);
        final matchesDetails =
            log.details?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesDetails) return false;
      }

      return true;
    }).toList();

    return logs;
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logsKey);
  }

  static Future<void> _saveLogs(
    SharedPreferences prefs,
    List<LogEntry> logs,
  ) async {
    final encoded = json.encode(logs.map((log) => log.toJson()).toList());
    await prefs.setString(_logsKey, encoded);
  }

  static Future<String> exportLogs() async {
    final logs = await getLogs();

    final jsonData = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalLogs': logs.length,
      'logs': logs.map((log) => log.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(jsonData);
  }
}
