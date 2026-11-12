import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const AudacityPlayerApp());
}

class AudacityPlayerApp extends StatelessWidget {
  const AudacityPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audacity Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3AAFA9),
          secondary: Color(0xFFF4D03F),
        ),
      ),
      home: const PlayerScreen(),
    );
  }
}
