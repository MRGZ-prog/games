import 'package:flutter/material.dart';
import 'package:games/light_out/light_out_grid.dart';
import 'package:games/queens/stars_grid.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text("Choose a game:"),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              onPressed: () => changePage(context, const LightOutGrid()),
              child: Text("Lights out"),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              onPressed: () => changePage(context, const StarsGrid()),
              child: Text("Constellations"),
            ),
          ),
        ],
      ),
    );
  }
}

void changePage(BuildContext context, Widget page) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (BuildContext context) => page),
  );
}
