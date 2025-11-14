import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:dashcamapp/config.dart';

enum LiveViewErrorType {
  networkConnection,
  authentication,
  streamNotAvailable,
  configurationError,
  webViewError,
  unknown
}

class LiveViewError {
  final LiveViewErrorType type;
  final String message;
  final String? technicalDetails;
  final bool isRetryable;
  
  const LiveViewError({
    required this.type,
    required this.message,
    this.technicalDetails,
    required this.isRetryable,
  });
}

class LiveViewPage extends StatefulWidget {
  const LiveViewPage({super.key});

  @override
  State<LiveViewPage> createState() => _LiveViewPageState();
}

class _LiveViewPageState extends State<LiveViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false; 
  LiveViewError? _currentError; 

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  String _cleanErrorMessage(String errorMessage) {
    if (errorMessage.isEmpty) return errorMessage;
    
    String cleaned = errorMessage.endsWith('.') 
        ? errorMessage.substring(0, errorMessage.length - 1)
        : errorMessage;
    
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    
    return cleaned;
  }

  LiveViewError _categorizeError(WebResourceError error) {
    if (error.errorCode == -1009 || error.errorCode == -1001 || error.errorCode == -1004) {
      return LiveViewError(
        type: LiveViewErrorType.networkConnection,
        message: "Can't connect to camera",
        technicalDetails: "${error.description} (${error.errorCode})",
        isRetryable: true,
      );
    }
    
    // Authentication errors 
    if (error.errorCode == 401 || error.errorCode == 403) {
      return LiveViewError(
        type: LiveViewErrorType.authentication,
        message: "Camera access denied",
        technicalDetails: "Check camera credentials",
        isRetryable: false,
      );
    }
    
    // Stream unavailable
    if (error.errorCode == 404 || error.errorCode == 503) {
      return LiveViewError(
        type: LiveViewErrorType.streamNotAvailable,
        message: "Camera stream offline",
        technicalDetails: "Stream may be temporarily unavailable",
        isRetryable: true,
      );
    }
    
    if (error.errorCode >= -999 && error.errorCode <= -100) {
      return LiveViewError(
        type: LiveViewErrorType.webViewError,
        message: "Display error occurred",
        technicalDetails: _cleanErrorMessage("${error.description} (${error.errorCode})"),
        isRetryable: true,
      );
    }
    
    return LiveViewError(
      type: LiveViewErrorType.unknown,
      message: "Something went wrong",
      technicalDetails: _cleanErrorMessage("${error.description} (${error.errorCode})"),
      isRetryable: true,
    );
  }


  void _initializeWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);
    
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _currentError = _categorizeError(error);
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
      
    controller.loadRequest(
      Uri.parse(config.webrtcUrl),
    );
    
    _controller = controller;
  }

  void _refreshStream() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentError = null;
    });
    
    try {
      _controller.clearCache();
      _controller.clearLocalStorage();
      _controller.loadRequest(
        Uri.parse(config.webrtcUrl),
      );
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _currentError = LiveViewError(
          type: LiveViewErrorType.webViewError,
          message: 'Failed to refresh stream',
          technicalDetails: e.toString(),
          isRetryable: true,
        );
      });
    }
  }

  IconData _getErrorIcon(LiveViewErrorType type) {
    switch (type) {
      case LiveViewErrorType.networkConnection:
        return Icons.wifi_off;
      case LiveViewErrorType.authentication:
        return Icons.lock;
      case LiveViewErrorType.streamNotAvailable:
        return Icons.videocam_off;
      case LiveViewErrorType.configurationError:
        return Icons.settings_applications;
      case LiveViewErrorType.webViewError:
        return Icons.error_outline;
      case LiveViewErrorType.unknown:
        return Icons.help_outline;
    }
  }

  Color _getErrorColor(LiveViewErrorType type) {
    switch (type) {
      case LiveViewErrorType.networkConnection:
        return Colors.orange;
      case LiveViewErrorType.authentication:
        return Colors.red;
      case LiveViewErrorType.streamNotAvailable:
        return Colors.amber;
      case LiveViewErrorType.configurationError:
        return Colors.purple;
      case LiveViewErrorType.webViewError:
        return Colors.blue;
      case LiveViewErrorType.unknown:
        return Colors.grey;
    }
  }

  void _showNetworkDiagnostics() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Network Diagnostics'),
          content: const Text('Check your network connection and ensure the camera URL is accessible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Camera Settings'),
          content: const Text('Please check camera credentials and permissions in the settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showCameraStatus() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Camera Status'),
          content: const Text('The camera may be offline or the stream is temporarily unavailable. Try again in a few moments.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorActions(LiveViewError error) {
    switch (error.type) {
      case LiveViewErrorType.networkConnection:
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: error.isRetryable ? _refreshStream : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _showNetworkDiagnostics,
              child: const Text('Network Diagnostics'),
            ),
          ],
        );
        
      case LiveViewErrorType.authentication:
        return ElevatedButton.icon(
          onPressed: _showSettingsDialog,
          icon: const Icon(Icons.settings),
          label: const Text('Check Settings'),
        );
        
      case LiveViewErrorType.streamNotAvailable:
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: _refreshStream,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _showCameraStatus,
              child: const Text('Camera Status'),
            ),
          ],
        );
        
      default:
        return ElevatedButton.icon(
          onPressed: error.isRetryable ? _refreshStream : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        );
    }
  }

  Widget _buildErrorUI(LiveViewError error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(error.type),
              size: 64,
              color: _getErrorColor(error.type),
            ),
            const SizedBox(height: 24),
            Text(
              error.message,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (error.technicalDetails != null) ...[
              const SizedBox(height: 12),
              Text(
                error.technicalDetails!,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            _buildErrorActions(error),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live View',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStream,
            tooltip: 'Refresh Stream',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasError && _currentError != null)
            _buildErrorUI(_currentError!)
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading stream...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
