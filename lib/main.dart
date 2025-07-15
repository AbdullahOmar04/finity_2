import 'package:finity_2/login/reg/login.dart';
import 'package:finity_2/login/reg/mainpage.dart';
import 'package:finity_2/utlis/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final user = FirebaseAuth.instance.currentUser;
  runApp(
    MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      home: user == null ? const LoginPage() : const MainPage(),
      theme: blueTheme,
    ),
  );
}
