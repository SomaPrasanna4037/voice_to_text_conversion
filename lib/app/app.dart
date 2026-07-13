import 'package:flutter/material.dart';

import '../pages/speech_to_text_page/speech_to_text_page.dart';
import '../pages/azure_speech_test_page/azure_speech_test_page.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice to Text POC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _HomeWithTabs(),
    );
  }
}

class _HomeWithTabs extends StatefulWidget {
  const _HomeWithTabs();

  @override
  State<_HomeWithTabs> createState() => _HomeWithTabsState();
}

class _HomeWithTabsState extends State<_HomeWithTabs> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          SpeechToTextPage(),
          AzureSpeechTestPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Speech to Text',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud),
            label: 'Azure Speech Test',
          ),
        ],
      ),
    );
  }
}
