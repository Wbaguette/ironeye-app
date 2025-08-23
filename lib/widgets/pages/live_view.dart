import 'package:flutter/material.dart';

class LiveViewPage extends StatelessWidget {
  const LiveViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live View'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Live View Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
