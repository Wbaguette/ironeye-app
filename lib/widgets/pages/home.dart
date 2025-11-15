import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dashcamapp/services/log_service.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool isConnectedToWiFi = false;
  bool isConnectedToDashcam = false;
  String? connectedSSID;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _startPeriodicCheck();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicCheck() {
    // Check connection status every 3 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && isConnectedToWiFi) {
        _checkDashcamConnection();
      }
    });
  }

  Future<void> _initConnectivity() async {
    // Check initial connectivity
    final ConnectivityResult connectivityResult = 
        await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);

    // Cancel existing subscription if any
    await _connectivitySubscription?.cancel();
    
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = isConnectedToWiFi;
    final newConnected = result == ConnectivityResult.wifi;
    
    setState(() {
      isConnectedToWiFi = newConnected;
      if (!newConnected) {
        isConnectedToDashcam = false;
        connectedSSID = null;
      }
    });

    // Log connectivity changes (fire-and-forget)
    if (mounted) {
      if (newConnected && !wasConnected) {
        LogService.log(
          level: LogLevel.info,
          category: LogCategory.network,
          title: 'WiFi connected',
          details: 'Device connected to WiFi network',
        );
        _checkDashcamConnection();
      } else if (!newConnected && wasConnected) {
        LogService.log(
          level: LogLevel.warning,
          category: LogCategory.network,
          title: 'WiFi disconnected',
          details: 'Device disconnected from WiFi network',
        );
      }
    }
  }

  Future<void> _checkDashcamConnection() async {
    if (!mounted || !isConnectedToWiFi) return;

    try {
      // Note: In a real implementation, you would check the connected SSID
      // and verify it's the dashcam network. This requires platform-specific code.
      // For now, we'll use a simple placeholder check.
      
      // You could also try to ping the dashcam's local IP or check if config endpoints respond
      // For example: http.get('http://192.168.1.1/api/status') with a short timeout
      
      // Placeholder: Assume connected to dashcam if WiFi name contains "ironeye"
      // In production, implement actual connectivity test
      
      if (mounted) {
        setState(() {
          // This is a placeholder - in production, get actual SSID from native code
          isConnectedToDashcam = true;
          connectedSSID = 'Dashcam Network';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isConnectedToDashcam = false;
        });
      }
    }
  }

  void _openWiFiSettings() {
    // Note: Opening WiFi settings requires platform-specific code
    // For iOS: app_settings package
    // For Android: android_intent_plus package
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please open your WiFi settings and connect to the dashcam network'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildConnectionCard() {
    if (!isConnectedToWiFi) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.wifi_off,
                size: 64,
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Not Connected to WiFi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please connect to your dashcam\'s WiFi network',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openWiFiSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open WiFi Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isConnectedToDashcam) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Connected to Dashcam',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can now access recordings and live view',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
              if (connectedSSID != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        connectedSSID!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Connected to WiFi but not dashcam
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              Icons.wifi_tethering_error,
              size: 64,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'Not Connected to Dashcam',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connected to WiFi, but not the dashcam network',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openWiFiSettings,
              icon: const Icon(Icons.router),
              label: const Text('Switch to Dashcam Network'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
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
          'Dashcam Connection',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConnectionCard(),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'How to Connect',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep(
                      1,
                      'Power on your dashcam',
                      'Make sure your dashcam is turned on and in WiFi mode',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      2,
                      'Open WiFi settings on your phone',
                      'Tap the button above to open your WiFi settings',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      3,
                      'Connect to dashcam network',
                      'Look for a network name containing "ironeye" or your dashcam\'s SSID',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      4,
                      'Return to the app',
                      'Once connected, return here to access recordings and live view',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isConnectedToDashcam) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.tips_and_updates, size: 48, color: Colors.blue.shade700),
                      const SizedBox(height: 12),
                      Text(
                        'Quick Access',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use the navigation bar below to:',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.videocam, color: Colors.blue.shade700),
                              const SizedBox(height: 4),
                              const Text('Live View', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.video_library, color: Colors.blue.shade700),
                              const SizedBox(height: 4),
                              const Text('Recordings', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.article, color: Colors.blue.shade700),
                              const SizedBox(height: 4),
                              const Text('Logs', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int step, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
