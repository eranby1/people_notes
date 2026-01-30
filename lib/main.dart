import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // קישור למסך הראשי שנמצא בתיקיית screens
import 'notification_service.dart'; // קישור לשירות ההתראות שנמצא ליד ה-main

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // אתחול שירות ההתראות לפני שהאפליקציה עולה
  await NotificationService().init();
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
      // תמיכה בעברית (יישור לימין)
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const HomeScreen(),
    );
  }
}
