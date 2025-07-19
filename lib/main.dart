import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oodaa_messenger/ui/screens/home_screen.dart';

void main() {
  runApp(const OodaaMessengerApp());
}

class OodaaMessengerApp extends StatelessWidget {
  const OodaaMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oodaa Messenger',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
