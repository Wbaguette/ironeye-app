import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dashcamapp/services/log_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LogEntry> _logs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLogs();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    LogCategory? category;
    switch (_tabController.index) {
      case 1:
        category = LogCategory.recordings;
        break;
      case 2:
        category = LogCategory.network;
        break;
      case 3:
        category = LogCategory.system;
        break;
    }

    final logs = await LogService.getLogs(
      category: category,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _exportLogs() async {
    String? filePath;
    try {
      final logsJson = await LogService.exportLogs();
      final tempDir = Directory.systemTemp;
      final fileName = 'dashcam_logs_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.json';
      filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsString(logsJson);

      if (mounted) {
        try {
          await Share.shareXFiles(
            [XFile(filePath, mimeType: 'application/json')],
          );
        } finally {
          // Clean up temp file after sharing
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {
            // Ignore cleanup errors
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export logs: $e')),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text('Are you sure you want to clear all logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LogService.clearLogs();
      _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Logs',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Recordings'),
            Tab(text: 'Network'),
            Tab(text: 'System'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportLogs,
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadLogs();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  setState(() => _searchQuery = value);
                  _loadLogs();
                });
              },
            ),
          ),

          // Logs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No logs found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Logs will appear here as you use the app',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.builder(
                          itemCount: _logs.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            return _LogCard(log: _logs[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatefulWidget {
  final LogEntry log;

  const _LogCard({required this.log});

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _isExpanded = false;

  Color _getLevelColor() {
    switch (widget.log.level) {
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getLevelColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForCategory(),
                      color: _getLevelColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.log.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              _isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.log.categoryName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM dd, HH:mm:ss').format(widget.log.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isExpanded && widget.log.details != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.log.details!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
              if (_isExpanded && widget.log.metadata != null && widget.log.metadata!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metadata:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...widget.log.metadata!.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForCategory() {
    switch (widget.log.category) {
      case LogCategory.recordings:
        return Icons.videocam;
      case LogCategory.network:
        return Icons.wifi;
      case LogCategory.system:
        return Icons.error_outline;
    }
  }
}

