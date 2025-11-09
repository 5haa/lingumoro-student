import 'package:flutter/material.dart';
import 'package:student/screens/home/home_screen.dart';
import 'package:student/screens/packages/packages_screen.dart';
import 'package:student/screens/classes/classes_screen.dart';
import 'package:student/screens/practice/practice_screen.dart';
import 'package:student/screens/chat/chat_screen.dart';
import 'package:student/screens/profile/profile_screen.dart';
import 'package:student/screens/ai_voice/ai_voice_assistant_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const PackagesScreen(),
    const ClassesScreen(),
    const PracticeScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  void _openAIVoiceAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AiVoiceAssistantScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAIVoiceAssistant,
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.mic, color: Colors.white),
        label: const Text(
          'AI Tutor',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard),
            label: 'Packages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Practice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

