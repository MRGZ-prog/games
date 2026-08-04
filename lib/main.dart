import 'package:flutter/material.dart';
import 'package:games/light_out/light_out_grid.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: LightOutGrid())),
    );
  }
}
