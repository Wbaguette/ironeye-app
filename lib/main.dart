import 'package:flutter/material.dart';

void main() {
  runApp( DashCamApp() );

}

class DashCamApp extends StatelessWidget {
  const DashCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: const Text("Dash Cam App"),
        ),
      ),
      // theme: ,
      // routes: ,
    );

  }
}