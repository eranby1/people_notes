import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // מקשר למסך הראשי

void main() {
  runApp(const PeopleNotesApp());
}

class PeopleNotesApp extends StatelessWidget {
  const PeopleNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'People Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      builder: (context, child) {
        // מגדיר כיוון ימין-לשמאל (RTL) לכל האפליקציה
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const HomeScreen(), // מפעיל את המסך הראשי מהתיקייה החדשה
    );
  }
}
