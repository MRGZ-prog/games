import 'package:flutter/material.dart';

enum StatusBrick { empty, tick, star }

class StarsBrick extends StatelessWidget {
  final StatusBrick status;
  final Color color;
  final VoidCallback onTap;

  const StarsBrick({
    super.key,
    required this.status,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isStar = status.name == "star";
    final icon = status.name == "tick"
        ? Icons.close
        : status.name == "star"
        ? Icons.star
        : null;

    return Container(
      color: color,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: FittedBox(
          child: Icon(
            icon,
            color: isStar ? Colors.white : Colors.black,
            size: isStar ? 40 : 20,
            shadows: isStar
                ? [Shadow(color: Colors.black, offset: Offset(1, 1))]
                : [],
          ),
        ),
      ),
    );
  }
}
