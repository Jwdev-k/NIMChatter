import 'package:flutter/material.dart';
import 'package:nim_chatter/ChatScreen.dart';

void main() {
  runApp(const NvidiaChatApp());
}

class NvidiaChatApp extends StatelessWidget {
  const NvidiaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NVIDIA Build AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF76B900), // NVIDIA Green
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}


