import 'package:flutter/material.dart';
import 'package:dashcamapp/widgets/navigation.dart';
import 'package:dashcamapp/widgets/pages/home.dart';
import 'package:dashcamapp/widgets/pages/live_view.dart';
import 'package:dashcamapp/widgets/pages/recordings.dart';
import 'package:dashcamapp/widgets/pages/settings.dart';
import 'package:dashcamapp/widgets/pages/logs.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  PageIndex _currentIndex = PageIndex.home;

  final List<Widget> _pages = [
    const HomePage(),
    const LiveViewPage(),
    const RecordingsPage(),
    const SettingsPage(),
    const LogsPage(),
  ];

  void _onNavigationTapped(int index) {
    setState(() {
      _currentIndex = PageIndex.values[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex.index],
      bottomNavigationBar: Navigation(
        currentIndex: _currentIndex,
        onTap: _onNavigationTapped,
      ),
    );
  }
}


