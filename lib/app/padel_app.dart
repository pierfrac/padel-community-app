import 'package:flutter/material.dart';
import 'app_shell.dart';

class PadelApp extends StatelessWidget {
  const PadelApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Padel Community',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146C5A)),
      scaffoldBackgroundColor: const Color(0xFFF7F8F7),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F8F7), foregroundColor: Color(0xFF17221F)),
      cardTheme: CardThemeData(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE3E9E6)))),
    ),
    home: const AppShell(),
  );
}
