import 'dart:math';

import 'package:flutter/material.dart';
import 'package:games/light_out/light_out_brick.dart';

class LightOutGrid extends StatefulWidget {
  final int initGridSize;
  final int initDifficulty;

  const LightOutGrid({
    super.key,
    this.initGridSize = 5,
    this.initDifficulty = 50,
  });

  @override
  State<LightOutGrid> createState() => _LightOutGridState();
}

class _LightOutGridState extends State<LightOutGrid> {
  late int gridSize;
  late int difficulty;
  late List<List<bool>> _grid;

  @override
  void initState() {
    super.initState();
    gridSize = widget.initGridSize;
    difficulty = widget.initDifficulty;
    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      _grid = createPuzzle(gridSize, difficulty);
    });
  }

  void _biggerSize() {
    gridSize++;
    _startNewGame();
  }

  void _smallerSize() {
    if (gridSize > 1) {
      gridSize--;
      _startNewGame();
    }
  }

  void _togglePositions(List<List<bool>> grid, int x, int y, int size) {
    grid[y][x] = !grid[y][x];

    if (y > 0) grid[y - 1][x] = !grid[y - 1][x];

    if (y < size - 1) grid[y + 1][x] = !grid[y + 1][x];

    if (x > 0) grid[y][x - 1] = !grid[y][x - 1];

    if (x < size - 1) grid[y][x + 1] = !grid[y][x + 1];
  }

  List<List<bool>> createPuzzle(int size, int difficulty) {
    List<List<bool>> list = List.generate(
      size,
      (y) => List.generate(size, (x) => false),
    );

    if (difficulty > 0) {
      final rand = Random();
      for (var i = 0; i < size * size * difficulty / 100; i++) {
        _togglePositions(list, rand.nextInt(size), rand.nextInt(size), size);
      }
    }

    return list;
  }

  void _onBrickTapped(int x, int y) {
    setState(() {
      _togglePositions(_grid, x, y, gridSize);
    });
  }

  int get _nbLightsOn {
    return _grid.fold(0, (sum, row) => sum + row.where((cell) => cell).length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lights Out'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: 'More size',
            onPressed: _biggerSize,
          ),
          IconButton(
            icon: const Icon(Icons.unfold_less),
            tooltip: 'Less size',
            onPressed: _smallerSize,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New game',
            onPressed: _startNewGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    "Size : ${gridSize}x$gridSize",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Lights on : $_nbLightsOn",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: List.generate(
                        gridSize,
                        (y) => Expanded(
                          child: Row(
                            children: List.generate(
                              gridSize,
                              (x) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: LightOutBrick(
                                    isLightOn: _grid[y][x],
                                    onTap: () => _onBrickTapped(x, y),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
