import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:dashcamapp/config.dart';

class LiveViewPage extends StatefulWidget {
  const LiveViewPage({super.key});

  @override
  State<LiveViewPage> createState() => _LiveViewPageState();
}

class _LiveViewPageState extends State<LiveViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false; 
  String? _errorMessage; // Error message to display (config error or web view error)


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
              _errorMessage = _cleanErrorMessage(error.description);
            });
          },
        ),
      );
      
    if (config.hasError) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = _cleanErrorMessage(config.errorMessage!);
      });
      return;
    }
    
    // There should be no error thrown here, config takes care of it
    controller.loadRequest(Uri.parse(config.webrtcUrl!));
    
    _controller = controller;
  }

  void _refreshStream() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      if (config.hasError) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _cleanErrorMessage(config.errorMessage!);
        });
        return;
      }
      
      _controller.clearCache();
      _controller.clearLocalStorage();
      _controller.loadRequest(Uri.parse(config.webrtcUrl!));
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = _cleanErrorMessage('Failed to refresh stream');
      });
    }
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
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load live view',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshStream,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
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
