import 'package:flutter/material.dart';

class GameConstants {
  static const List<Color> zoneColors = [
    // [COLORS USED]
    Color.fromARGB(255, 200, 75, 49),
    Color.fromARGB(255, 236, 154, 41),
    Color.fromARGB(255, 55, 110, 71),
    Color.fromARGB(255, 52, 185, 152),
    Color.fromARGB(255, 59, 91, 165),
    Color.fromARGB(255, 123, 82, 130),
    Color.fromARGB(255, 217, 107, 138),
    Color.fromARGB(255, 108, 122, 137),

    // [--Reserve--]
    Color.fromARGB(255, 76, 127, 175),
    Color.fromARGB(255, 0, 128, 128),
    Color.fromARGB(255, 214, 40, 40),
    Color(0xFFF77F00),
    Color(0xFFFCBF49),
    Color(0xFF2A9D8F),
    Color(0xFF000A8E),
    Color(0xFF7209B7),
    Color.fromARGB(255, 141, 153, 174),
    Color(0xFF08D99A),
    Color(0xFFF72585),
  ];

  static const List<List<int>> directions8 = [
    [-1, -1],
    [-1, 0],
    [-1, 1],
    [0, -1],
    [0, 1],
    [1, -1],
    [1, 0],
    [1, 1],
  ];

  static const List<List<int>> directions4 = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];
}
