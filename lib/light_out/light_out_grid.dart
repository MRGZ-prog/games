import 'package:flutter/material.dart';
import 'package:games/light_out/light_out_brick.dart';

class LightOutGrid extends StatelessWidget {
  final int gridSize;

  const LightOutGrid({super.key, this.gridSize = 5});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lights Out Grid')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          // Nombre de colonnes et espacement
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize, // Nombre de colonnes (ex: 5)
            crossAxisSpacing: 4.0, // Espacement horizontal entre les cases
            mainAxisSpacing: 4.0, // Espacement vertical entre les cases
          ),
          itemCount: gridSize * gridSize, // Total des cases (ex: 25)
          itemBuilder: (context, index) {
            final x = index ~/ gridSize;
            final y = index - x * gridSize;
            return LightOutBrick(x: x, y: y);
          },
        ),
      ),
    );
  }
}
