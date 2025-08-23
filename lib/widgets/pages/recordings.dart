import 'package:flutter/material.dart';

class RecordingsPage extends StatelessWidget {
  const RecordingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Recordings Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
