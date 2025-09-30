import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool isConnectedToWiFi = false;
  bool dashcamFound = false;
  bool isScanning = false;
  bool isConnecting = false;
  bool isProtected = false;
  String? dashcamSSID;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    // Check initial connectivity
    final ConnectivityResult connectivityResult = 
        await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_updateConnectionStatus);

    // Check permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request location permission (required for WiFi scan on Android)
      await Permission.location.request();
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      isConnectedToWiFi = result == ConnectivityResult.wifi;
    });

    if (isConnectedToWiFi && !dashcamFound) {
      _scanForDashcam();
    }
  }

  Future<void> _scanForDashcam() async {
    try {
      setState(() {
        isScanning = true;
        errorMessage = null;
      });

      // Check if WiFi scan is supported
      final canGetScannedResults = await WiFiScan.instance.canGetScannedResults();
      if (canGetScannedResults != CanGetScannedResults.yes) {
        setState(() {
          errorMessage = 'WiFi scanning not supported on this device';
          isScanning = false;
        });
        return;
      }

      // Start scan
      await WiFiScan.instance.startScan();
      
      // Get scan results
      final accessPoints = await WiFiScan.instance.getScannedResults();
      
      // Look for dashcam WiFi
      WiFiAccessPoint? dashcamAP;
      for (final ap in accessPoints) {
        if (ap.ssid.toLowerCase() == 'ironeye') {
          dashcamAP = ap;
          break;
        }
      }

      if (dashcamAP != null) {
        setState(() {
          dashcamSSID = dashcamAP!.ssid;
          dashcamFound = true;
          isProtected = dashcamAP.capabilities.contains('WPA') || 
                       dashcamAP.capabilities.contains('WEP');
        });
        
        if (isProtected) {
          _showPasswordDialog();
        } else {
          _connectToDashcam();
        }
      } else {
        setState(() {
          errorMessage = 'No dashcam WiFi found. Make sure your dashcam is powered on and in AP mode.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error scanning for WiFi: ${e.toString()}';
      });
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> _connectToDashcam([String? password]) async {
    try {
      setState(() {
        isConnecting = true;
        errorMessage = null;
      });

      // Note: Direct WiFi connection might require platform-specific code
      // For now, show instructions to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please connect to "$dashcamSSID" manually in your WiFi settings'
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to connect: ${e.toString()}';
      });
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  void _showPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('WiFi Password Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter password for "$dashcamSSID":'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _connectToDashcam(passwordController.text);
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionStatus() {
    if (isScanning) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Scanning for dashcam...'),
            ],
          ),
        ),
      );
    }

    if (isConnecting) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Connecting to dashcam...'),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade700),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (dashcamFound) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.wifi, color: Colors.green.shade700),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashcam Found: $dashcamSSID',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      'Ready to connect',
                      style: TextStyle(color: Colors.green.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!isConnectedToWiFi) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.orange.shade700),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'WiFi not connected. Please connect to WiFi to scan for dashcam.',
                  style: TextStyle(color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.search),
            const SizedBox(width: 16),
            const Expanded(
              child: Text('Tap "Scan for Dashcam" to search for your device'),
            ),
            ElevatedButton(
              onPressed: _scanForDashcam,
              child: const Text('Scan'),
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
          'Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isConnectedToWiFi ? Icons.wifi : Icons.wifi_off,
                          color: isConnectedToWiFi ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnectedToWiFi ? 'WiFi Connected' : 'WiFi Disconnected',
                          style: TextStyle(
                            color: isConnectedToWiFi ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildConnectionStatus(),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Power on your dashcam\n'
                      '2. Enable WiFi access point mode on your dashcam\n'
                      '3. Make sure your phone is connected to WiFi\n'
                      '4. Tap "Scan for Dashcam" to detect your device\n'
                      '5. Connect to the dashcam WiFi when found',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
