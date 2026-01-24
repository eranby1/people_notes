import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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
        // חזרנו לצבע הטורקיז המקורי שאהבת
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const HomeScreen(),
    );
  }
}
