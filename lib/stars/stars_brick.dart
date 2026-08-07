import 'package:flutter/material.dart';

enum StatusBrick { empty, tick, star }

class StarsBrick extends StatelessWidget {
  final StatusBrick status;
  final Color color;
  final VoidCallback onTap;
  final bool hasConflict;

  const StarsBrick({
    super.key,
    required this.status,
    required this.color,
    required this.onTap,
    this.hasConflict = false,
  });

  @override
  Widget build(BuildContext context) {
    final isStar = status.name == "star";
    final isTick = status.name == "tick";
    final icon = isTick
        ? Icons.close
        : isStar
        ? Icons.star
        : null;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: (!isTick && !isStar)
            ? color
            : Color.fromARGB(
                240,
                (color.r * 255).round(),
                (color.g * 255).round(),
                (color.b * 255).round(),
              ),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17.0),
        ),
      ),
      child: FittedBox(
        child: Icon(
          icon,
          color: hasConflict
              ? Colors.red
              : isStar
              ? Colors.white
              : Colors.white12,
          size: isStar ? 40 : 17.5,
          shadows: isStar
              ? [Shadow(color: Colors.black, offset: Offset(1, 1))]
              : [Shadow(color: Colors.black, offset: Offset(0.5, 0.5))],
        ),
      ),
    );
  }
}
