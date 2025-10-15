import 'package:dashcamapp/config.dart';
import 'package:dashcamapp/widgets/main_container.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    final _ = config; 
    
    runApp(const IroneyeApp());
  } catch (e) {
    if (kDebugMode) {
      runApp(ConfigErrorApp(error: e.toString()));
    } else {
      throw Exception('Configuration validation failed: $e');
    }
  }
}

class IroneyeApp extends StatelessWidget {
  const IroneyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ironeye Dashcam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'SF Pro Display', 
        ),
      ),
      home: const MainContainer(),
    );
  }
}

class ConfigErrorApp extends StatelessWidget {
  final String error;
  
  const ConfigErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuration Error',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Configuration Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Please check your .env file and fix the configuration issues.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}