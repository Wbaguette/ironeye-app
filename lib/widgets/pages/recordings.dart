import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dashcamapp/constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dashcamapp/services/recordings_service.dart';
import 'package:dashcamapp/services/log_service.dart';

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  DateTime _selectedDate = DateTime.now();
  List<Recording> _recordings = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRecordings();
  }

  Future<void> _fetchRecordings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      var recordings = await RecordingsService.fetchRecordingsForDate(
        _selectedDate,
      );
      if (!mounted) return;

      // Cap recordings list to prevent memory issues
      if (recordings.length > 1000) {
        recordings = recordings.take(1000).toList();
        LogService.log(
          level: LogLevel.warning,
          category: LogCategory.system,
          title: 'Recordings list truncated',
          details: 'Recording list exceeded 1000 entries and was truncated',
        );
      }

      setState(() {
        _recordings = recordings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 7),
      ), // 7 days back
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: primaryBlue, onPrimary: textWhite),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await LogService.log(
        level: LogLevel.info,
        category: LogCategory.recordings,
        title: 'Date selected',
        details: 'User selected ${picked.toLocal().toString().split(' ')[0]}',
      );
      _fetchRecordings();
    }
  }

  void _showWebNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: warningOrangeIcon),
              const SizedBox(width: 8),
              const Text('Not Available on Web'),
            ],
          ),
          content: const Text(
            'Downloads are only supported on mobile devices (iOS/Android). Please use the mobile app to download recordings.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadRecording(Recording recording) async {
    // Check if running on web platform
    if (kIsWeb) {
      _showWebNotSupportedDialog();
      return;
    }

    final Map<String, dynamic>? downloadConfig =
        await _showCustomDownloadDialog(recording);
    if (downloadConfig == null || !mounted) return;

    // Store context before async operations
    final scaffoldContext = context;

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            final startTime = recording.startTime.add(
              Duration(seconds: downloadConfig['offsetSeconds'].round()),
            );
            final durationMinutes = (downloadConfig['durationSeconds'] / 60)
                .toStringAsFixed(1);
            final fileName =
                'dashcam_${startTime.toLocal().toString().replaceAll(':', '-').replaceAll(' ', '_').substring(0, 19)}_${downloadConfig['durationSeconds'].round()}s.mp4';

            return AlertDialog(
              title: const Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Downloading'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preparing your custom segment for download...',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: textGreyMedium),
                      const SizedBox(width: 8),
                      Text(
                        'Start: ${DateFormat('HH:mm:ss').format(startTime)}',
                        style: TextStyle(color: textGreyMedium, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: textGreyMedium),
                      const SizedBox(width: 8),
                      Text(
                        'Duration: $durationMinutes minutes',
                        style: TextStyle(color: textGreyMedium, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.video_file, size: 16, color: textGreyMedium),
                      const SizedBox(width: 8),
                      Text(
                        'Format: MP4',
                        style: TextStyle(color: textGreyMedium, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'File: $fileName',
                    style: TextStyle(
                      color: infoBlueDark,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }

      final double offsetSeconds = downloadConfig['offsetSeconds'];
      final double durationSeconds = downloadConfig['durationSeconds'];

      final filePath = await RecordingsService.downloadCustomSegment(
        recording: recording,
        offsetSeconds: offsetSeconds,
        durationSeconds: durationSeconds,
      );

      if (!context.mounted) return;

      if (mounted) {
        Navigator.of(scaffoldContext).pop();

        LogService.log(
          level: LogLevel.info,
          category: LogCategory.recordings,
          title: 'Recording shared',
          details:
              'User shared recording segment (${durationSeconds.round()}s)',
          metadata: {
            'offsetSeconds': offsetSeconds,
            'durationSeconds': durationSeconds,
          },
        );

        try {
          await Share.shareXFiles([XFile(filePath, mimeType: 'video/mp4')]);
        } finally {
          // Clean up temp file after sharing
          try {
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            // Ignore cleanup errors
          }
        }
      }
    } catch (e) {
      if (!context.mounted) return;

      if (mounted) {
        Navigator.of(scaffoldContext).pop();

        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        if (errorMessage.contains('Custom download error:')) {
          errorMessage = errorMessage.replaceFirst(
            'Custom download error: ',
            '',
          );
        }

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: errorRedIcon),
                  const SizedBox(width: 8),
                  const Text('Download Failed'),
                ],
              ),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _downloadRecording(recording);
                  },
                  child: const Text('Retry'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<Map<String, dynamic>?> _showCustomDownloadDialog(
    Recording recording,
  ) async {
    DateTime startTime = recording.startTime;
    DateTime endTime = recording.startTime.add(
      const Duration(minutes: 1),
    ); // Default to 1 minute duration

    // Ensure end time doesn't exceed recording bounds
    final maxEndTime = recording.endTime;

    if (endTime.isAfter(maxEndTime)) {
      endTime = maxEndTime;
    }

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Ensure end time is always after start time
            if (endTime.isBefore(startTime) ||
                endTime.isAtSameMomentAs(startTime)) {
              endTime = startTime.add(
                const Duration(seconds: 6),
              ); // Minimum 6 seconds
              if (endTime.isAfter(maxEndTime)) {
                endTime = maxEndTime;
                startTime = endTime.subtract(const Duration(seconds: 6));
              }
            }

            final selectedDuration = endTime.difference(startTime);

            return AlertDialog(
              title: const Text('Download'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recording info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: infoBlueLight,
                        border: Border.all(color: infoBlueBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Original: ${DateFormat('HH:mm:ss').format(recording.startTime)} - ${DateFormat('HH:mm:ss').format(recording.endTime)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: infoBlueDarker,
                            ),
                          ),
                          Text(
                            'Total Duration: ${recording.humanReadableDuration}',
                            style: TextStyle(
                              color: infoBlueDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Time range display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Start: ${DateFormat('HH:mm:ss').format(startTime)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'End: ${DateFormat('HH:mm:ss').format(endTime)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Duration slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Download Segment',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        RangeSlider(
                          values: RangeValues(
                            startTime
                                .difference(recording.startTime)
                                .inSeconds
                                .toDouble(),
                            endTime
                                .difference(recording.startTime)
                                .inSeconds
                                .toDouble(),
                          ),
                          max: recording.endTime
                              .difference(recording.startTime)
                              .inSeconds
                              .toDouble(),
                          divisions:
                              (recording.endTime
                                          .difference(recording.startTime)
                                          .inSeconds /
                                      5)
                                  .round(),
                          labels: RangeLabels(
                            DateFormat('HH:mm:ss').format(startTime),
                            DateFormat('HH:mm:ss').format(endTime),
                          ),
                          onChanged: (RangeValues values) {
                            setState(() {
                              startTime = recording.startTime.add(
                                Duration(seconds: values.start.round()),
                              );
                              endTime = recording.startTime.add(
                                Duration(seconds: values.end.round()),
                              );

                              // Ensure minimum duration of 6 seconds
                              if (endTime.difference(startTime).inSeconds < 6) {
                                endTime = startTime.add(
                                  const Duration(seconds: 6),
                                );
                                if (endTime.isAfter(recording.endTime)) {
                                  endTime = recording.endTime;
                                  startTime = endTime.subtract(
                                    const Duration(seconds: 6),
                                  );
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Duration display
                    Text(
                      'Duration: ${selectedDuration.inMinutes}m ${selectedDuration.inSeconds % 60}s',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: infoBlueDark,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop({
                    'offsetSeconds': startTime
                        .difference(recording.startTime)
                        .inSeconds
                        .toDouble(),
                    'durationSeconds': selectedDuration.inSeconds.toDouble(),
                  }),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: textWhite,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recordings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRecordings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: infoBlueLight,
              border: Border.all(color: infoBlueBorder),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: infoBlueDark, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recordings are automatically deleted after 7 days to save storage space.',
                    style: TextStyle(color: infoBlueDarker, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // Date Selection Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ListTile(
              leading: const Icon(Icons.calendar_month, color: primaryBlue),
              title: Text(
                'View recordings from',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: textGreyDark,
                ),
              ),
              subtitle: Text(
                DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _selectDate,
            ),
          ),

          // Content Area
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading recordings...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: errorRed),
              const SizedBox(height: 16),
              const Text(
                'Failed to load recordings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error occurred',
                style: TextStyle(fontSize: 14, color: textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchRecordings,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recordings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 64, color: textGreyLight),
              const SizedBox(height: 16),
              Text(
                'No recordings found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textGreyMedium,
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today),
                label: const Text('Select Different Date'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _recordings.length,
      itemBuilder: (context, index) {
        final recording = _recordings[index];
        return _buildRecordingCard(recording);
      },
    );
  }

  Widget _buildRecordingCard(Recording recording) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with time and download button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('HH:mm:ss').format(recording.startTime)} - ${DateFormat('HH:mm:ss').format(recording.endTime)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recording.humanReadableDuration,
                        style: TextStyle(fontSize: 14, color: textGreyMedium),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _downloadRecording(recording),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: textWhite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
