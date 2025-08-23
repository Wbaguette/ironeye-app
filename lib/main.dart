import 'package:dashcamapp/widgets/main_container.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const IroneyeApp());
}

class IroneyeApp extends StatelessWidget {
  const IroneyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ironeye Dashcam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainContainer(),
    );

  }
}