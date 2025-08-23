import 'package:flutter/material.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Logs Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
