import 'package:dashcamapp/widgets/main_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  runApp(const IroneyeApp());
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