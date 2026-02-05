import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PropertyIQApp());
}

class PropertyIQApp extends StatelessWidget {
  const PropertyIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String backendStatus = "Not checked yet";

  Future<void> checkBackend() async {
    try {
      final url = Uri.parse("http://127.0.0.1:8000/health");
      final res = await http.get(url);

      final data = jsonDecode(res.body);

      setState(() {
        backendStatus = data["status"];
      });
    } catch (e) {
  setState(() {
    backendStatus = "Error: $e";
  });
}

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PropertyIQ"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Backend Connection Test",
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: checkBackend,
              child: const Text("Check Backend"),
            ),

            const SizedBox(height: 20),

            Text(
              "Backend status: $backendStatus",
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
