import 'package:flutter/material.dart';

import '../pages/speech_to_text_page/speech_to_text_page.dart';
import '../pages/flutter_speech_to_text_page/flutter_speech_to_text_page.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentPageIndex = 0;

  final List<Widget> _pages = const [
    SpeechToTextPage(),
    FlutterSpeechToTextPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice to Text POC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: _pages[_currentPageIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentPageIndex,
          onTap: (index) {
            setState(() {
              _currentPageIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.text_fields),
              label: 'Speech to Text',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mic),
              label: 'Flutter Speech',
            ),
          ],
        ),
      ),
    );
  }
}
