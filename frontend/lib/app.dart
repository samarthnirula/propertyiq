import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/calculator_page.dart';

class PropertyIQApp extends StatelessWidget {
  const PropertyIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const CalculatorPage(),
    );
  }
}
