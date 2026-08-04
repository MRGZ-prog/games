import 'package:flutter/material.dart';

class LightOutBrick extends StatefulWidget {
  final int x;
  final int y;

  const LightOutBrick({super.key, required this.x, required this.y});

  @override
  State<LightOutBrick> createState() => _LightOutBrickState();
}

class _LightOutBrickState extends State<LightOutBrick> {
  bool _lightOn = false;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    if (_lightOn) {
      color = Color(0xFFFFE306);
    } else {
      color = Colors.black;
    }
    return Container(
      color: color,
      child: OutlinedButton(
        onPressed: changeState,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Container(),
      ),
    );
  }

  void changeState() {
    setState(() {
      _lightOn = !_lightOn;
    });
  }
}
