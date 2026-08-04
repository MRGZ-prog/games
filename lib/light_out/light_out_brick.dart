import 'package:flutter/material.dart';

class LightOutBrick extends StatelessWidget {
  final bool isLightOn;
  final VoidCallback onTap;

  const LightOutBrick({
    super.key,
    required this.isLightOn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isLightOn ? const Color(0xFFFFE306) : Colors.black;

    return Container(
      color: color,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Container(),
      ),
    );
  }
}
