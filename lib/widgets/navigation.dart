import 'package:dashcamapp/constants/colors.dart';
import 'package:flutter/material.dart';

enum PageIndex {
  home,
  liveView,
  recordings,
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
        iconSize: 22.0,
        selectedItemColor: selectedItemColor,
        unselectedItemColor: textGrey,
        unselectedFontSize: 11.0,
        selectedFontSize: 11.0,
        enableFeedback: false,
        landscapeLayout: BottomNavigationBarLandscapeLayout.spread,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      items: [
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Icon(Icons.home_sharp),
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Icon(Icons.videocam),
          ),
          label: 'Live View',
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Icon(Icons.play_circle),
          ),
          label: 'Recordings',
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Icon(Icons.receipt_long),
          ),
          label: 'Logs',
        ),
      ],
      ),
    );
  }
}