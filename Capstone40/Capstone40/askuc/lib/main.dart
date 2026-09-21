import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/routes.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final rememberMe = await AuthService.shouldAutoLogin();

  if (FirebaseAuth.instance.currentUser != null && !rememberMe) {
    await FirebaseAuth.instance.signOut();
  }

  runApp(
    AskUCApp(
      initialRoute:
          FirebaseAuth.instance.currentUser != null && rememberMe
              ? AppRoutes.main
              : AppRoutes.login,
    ),
  );
}