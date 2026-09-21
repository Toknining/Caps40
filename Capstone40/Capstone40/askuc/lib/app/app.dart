import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/main/main_screen.dart';
import '../features/home/home_screen.dart';
import '../features/chatbot/chat_screen.dart';
import '../features/navigation/map_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/settings/settings_screen.dart';

class AskUCApp extends StatelessWidget {
  const AskUCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AskUC',

      debugShowCheckedModeBanner: false,

      theme: AskUCTheme.lightTheme,

      initialRoute: AppRoutes.login,

      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.main: (_) => const MainScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.chat: (_) => const ChatScreen(),
        AppRoutes.map: (_) => const MapScreen(),
        AppRoutes.announcements: (_) => const AnnouncementsScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
      },
    );
  }
}
