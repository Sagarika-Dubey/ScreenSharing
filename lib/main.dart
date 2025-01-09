import 'package:flutter/material.dart';
import 'pages/signin_login/sign.dart';
import 'pages/signin_login/login.dart';
import 'pages/home.dart';
import 'pages/meetings.dart';
import 'video_chat_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/signin',
      routes: {
        '/signin': (context) => const MeetSignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MyHomePage(),
        '/meetings': (context) => const Meeting(),
      },
    );
  }
}
