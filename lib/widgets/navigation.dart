import 'package:dashcamapp/constants/colors.dart';
import 'package:flutter/material.dart';

enum PageIndex {
  home,
  liveView,
  recordings,
  settings,
  logs,
}

class Navigation extends StatelessWidget {
  final PageIndex currentIndex;
  final Function(int) onTap;

  const Navigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex.index,
        onTap: onTap,
        backgroundColor: bgBlack,
        iconSize: 24.0,
        selectedItemColor: selectedItemColor,
        unselectedFontSize: 12.0,
        selectedFontSize: 12.0,
        enableFeedback: false,
        landscapeLayout: BottomNavigationBarLandscapeLayout.spread,
        type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_sharp),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.videocam),
          label: 'Live View',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.play_circle),
          label: 'Recordings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Logs',
        ),
      ],
      ),
    );
  }
}