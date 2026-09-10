import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'theme/tomo_theme.dart';

void main() {
  runApp(const TomoApp());
}

class TomoApp extends StatelessWidget {
  const TomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TOMO',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: tomoBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: tomoPink,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
