import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:games/stars/stars_constants.dart';
import 'package:games/stars/stars_dialog_utils.dart';
import 'package:games/stars/stars_brick.dart';
import 'package:games/stars/stars_logic.dart';
import 'package:games/stars/stars_solver.dart';
import 'package:games/stars/widgets/stopwatch_text.dart';

class StarsGrid extends StatefulWidget {
  final int initGridSize;
  final int initDifficulty;

  const StarsGrid({super.key, this.initGridSize = 5, this.initDifficulty = 50});

  @override
  State<StarsGrid> createState() => _StarsGridState();
}

class _StarsGridState extends State<StarsGrid> {
  late int gridSize;
  late int difficulty;

  List<List<StatusBrick>>? _grid;
  List<List<int>>? _zones;
  List<List<StatusBrick>>? _solution;
  List<List<bool>>? _conflicts;

  String puzzleId = "";
  String status = "Find the solution";
  bool _isGenerating = false;
  int _generationId = 0;

  final Stopwatch stopwatch = Stopwatch();
  bool hasTicks = true;
  bool autoTicks = false;

  @override
  void initState() {
    super.initState();
    gridSize = widget.initGridSize;
    difficulty = widget.initDifficulty;
    _startNewGame(0);
  }

  void _startNewGame(int neededLevel, {int? forceSeed}) async {
    int currentGen = ++_generationId;
    int seed = forceSeed ?? Random().nextInt(999999999);

    setState(() {
      puzzleId = "$gridSize-$neededLevel-$seed";
      status = "Generating...";
      _isGenerating = true;
      _grid = null; // Affiche un loader
    });

    PuzzleData? data = await PuzzleLogic.generateAsync(
      gridSize,
      difficulty,
      neededLevel,
      seed,
      currentGen,
      () => _generationId,
    );

    if (currentGen != _generationId) return;

    if (data == null) {
      // Echec de génération, on recommence
      _startNewGame(neededLevel, forceSeed: forceSeed);
      return;
    }

    setState(() {
      _grid = data.grid;
      _zones = data.zones;
      _solution = data.solution;
      _conflicts = List.generate(gridSize, (_) => List.filled(gridSize, false));
      final diffText = data.level == 1
          ? "Easy"
          : data.level == 2
          ? "Normal"
          : "Hard";
      status = "[$diffText] Find the solution";
      puzzleId = "$gridSize-${data.level}-$seed";
      _isGenerating = false;

      stopwatch.reset();
      stopwatch.start();
    });
  }

  void _changeSize(int delta) {
    if (_isGenerating) return;
    int newSize = gridSize + delta;
    if (newSize >= 4 && newSize <= min(GameConstants.zoneColors.length, 8)) {
      gridSize = newSize;
      _startNewGame(0);
    }
  }

  void clearGrid() {
    _grid = List.generate(
      gridSize,
      (_) => List.filled(gridSize, StatusBrick.empty),
    );
  }

  void _giveHint() {
    if (_grid == null || _solution == null || _zones == null) return;

    List<List<int>> incorrectStars = [];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_grid![r][c] == StatusBrick.star &&
            _solution![r][c] != StatusBrick.star) {
          incorrectStars.add([r, c]);
        }
      }
    }

    setState(() {
      hasTicks = true; // On s'assure que les ticks sont activés visuellement

      if (incorrectStars.isNotEmpty) {
        // Le joueur a fait une erreur : on lui montre en remplaçant la fausse étoile par un tick
        incorrectStars.shuffle();
        var p = incorrectStars.first;
        _grid![p[0]][p[1]] = StatusBrick.tick;
        return;
      }

      // Solver help
      List<List<SolverCell>> solverGrid = List.generate(
        gridSize,
        (r) => List.generate(gridSize, (c) {
          if (_grid![r][c] == StatusBrick.star) return SolverCell.star;
          if (_grid![r][c] == StatusBrick.tick) return SolverCell.cross;
          return SolverCell.empty;
        }),
      );

      // Instancier le solveur avec l'état de la partie
      HumanSolver solver = HumanSolver(size: gridSize, zones: _zones!);
      List<List<int>> logicalCrosses = solver.getHintCrosses(solverGrid);

      if (logicalCrosses.isNotEmpty) {
        // On mélange et on révèle jusqu'à 3 ticks déduits par la logique
        // (pour ne pas résoudre toute la grille d'un coup si une règle bloque 10 cases)
        logicalCrosses.shuffle();
        int hintsToGive = min(1, logicalCrosses.length);
        for (int i = 0; i < hintsToGive; i++) {
          var p = logicalCrosses[i];
          _grid![p[0]][p[1]] = StatusBrick.tick;
        }
      } else {
        // Fallback (Rare) : S'il n'y a plus de logique possible (ou que la grille ne requiert que de forcer une étoile)
        // On donne un tick valide aléatoire
        // List<List<int>> fallbackTicks = [];
        // for (int r = 0; r < gridSize; r++) {
        //   for (int c = 0; c < gridSize; c++) {
        //     if (_grid![r][c] == StatusBrick.empty &&
        //         _solution![r][c] != StatusBrick.star) {
        //       fallbackTicks.add([r, c]);
        //     }
        //   }
        // }
        // if (fallbackTicks.isNotEmpty) {
        //   fallbackTicks.shuffle();
        //   var p = fallbackTicks.first;
        //   _grid![p[0]][p[1]] = StatusBrick.tick;
        // }
      }
    });
  }

  void _onBrickTapped(int x, int y) async {
    if (_isGenerating || _grid == null) return;

    setState(() {
      _grid![y][x] = (_grid![y][x] == StatusBrick.empty)
          ? (hasTicks ? StatusBrick.tick : StatusBrick.star)
          : _grid![y][x] == StatusBrick.tick
          ? StatusBrick.star
          : StatusBrick.empty;
      _checkVictory();
    });

    if (hasTicks && autoTicks && _grid![y][x] == StatusBrick.star) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted && _grid![y][x] == StatusBrick.star) {
        _applyAutoTicks(y, x);
      }
    }
  }

  void _applyAutoTicks(int y, int x) {
    final zone = _zones![y][x];
    setState(() {
      for (int i = 0; i < gridSize; i++) {
        for (int j = 0; j < gridSize; j++) {
          bool isSameRowOrCol = (i == y || j == x);
          bool isSameZone = _zones![i][j] == zone;
          bool isAdjacent = (i - y).abs() <= 1 && (j - x).abs() <= 1;

          if ((isSameRowOrCol || isSameZone || isAdjacent) &&
              !(i == y && j == x)) {
            if (_grid![i][j] != StatusBrick.star) {
              _grid![i][j] = StatusBrick.tick;
            }
          }
        }
      }
    });
  }

  void _checkVictory() {
    int totalStars = 0;
    List<int> starsInRow = List.filled(gridSize, 0);
    List<int> starsInCol = List.filled(gridSize, 0);
    List<int> starsInZone = List.filled(gridSize, 0);

    _conflicts = List.generate(gridSize, (_) => List.filled(gridSize, false));

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_grid![r][c] == StatusBrick.star) {
          totalStars++;
          starsInRow[r]++;
          starsInCol[c]++;
          starsInZone[_zones![r][c]]++;

          // for (var dir in GameConstants.directions8) {
          //   int nr = r + dir[0], nc = c + dir[1];
          //   if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          //     if (_grid![nr][nc] == StatusBrick.star) {
          //       return; // Touche une étoile
          //     }
          //   }
          // }
        }
      }
    }

    bool hasAnyConflict = false;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_grid![r][c] == StatusBrick.star) {
          bool isConflict = false;

          // Vérification Ligne, Colonne, Zone
          if (starsInRow[r] > 1) isConflict = true;
          if (starsInCol[c] > 1) isConflict = true;
          if (starsInZone[_zones![r][c]] > 1) isConflict = true;

          // Vérification de la Proximité (les 8 cases autour)
          for (var dir in GameConstants.directions8) {
            int nr = r + dir[0], nc = c + dir[1];
            if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
              if (_grid![nr][nc] == StatusBrick.star) {
                isConflict = true;
              }
            }
          }

          // Si un conflit est détecté, on met à jour notre matrice _conflicts
          if (isConflict) {
            _conflicts![r][c] = true;
            hasAnyConflict = true;
          }
        }
      }
    }

    if (totalStars != gridSize) return;
    if (hasAnyConflict) return;

    stopwatch.stop();
    status = "Victory";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Constellations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () => _changeSize(1),
          ),
          IconButton(
            icon: const Icon(Icons.unfold_less),
            onPressed: () => _changeSize(-1),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => DialogUtils.showNewGame(context, _startNewGame),
          ),
          IconButton(
            icon: const Icon(Icons.grid_on),
            onPressed: () =>
                DialogUtils.showLoadPuzzle(context, (size, level, seed) {
                  gridSize = size;
                  _startNewGame(level, forceSeed: seed);
                }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopInfo(),
            Expanded(child: Center(child: _buildGridBoard())),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInfo() {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Center(child: StopwatchText(stopwatch: stopwatch)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  "Size : ${gridSize}x$gridSize",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  status,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: puzzleId));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Copied!')));
                  },
                  child: Text("ID: $puzzleId"),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => DialogUtils.showRules(context),
              child: const Text("Rules"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridBoard() {
    if (_grid == null || _zones == null) {
      return const CircularProgressIndicator();
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(
            gridSize,
            (y) => Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(gridSize, (x) {
                  int zId = _zones![y][x];
                  Color brickColor = zId == -1
                      ? Colors.grey.shade300
                      : GameConstants.zoneColors[zId %
                            GameConstants.zoneColors.length];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: StarsBrick(
                        status: _grid![y][x],
                        color: brickColor,
                        hasConflict: _conflicts != null
                            ? _conflicts![y][x]
                            : false,
                        onTap: () => _onBrickTapped(x, y),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: TextButton(onPressed: _giveHint, child: const Text("Help")),
        ),

        Expanded(
          child: TextButton(
            onPressed: () {
              setState(() {
                _grid = List.generate(
                  gridSize,
                  (_) => List.filled(gridSize, StatusBrick.empty),
                );
              });
            },
            child: const Text("Clear"),
          ),
        ),

        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Activate ticks"),
                  SizedBox(width: 6),
                  Checkbox(
                    value: hasTicks,
                    onChanged: (newValue) {
                      setState(() {
                        hasTicks = newValue ?? false;
                        if (!hasTicks && _grid != null) {
                          for (var row in _grid!) {
                            for (int i = 0; i < row.length; i++) {
                              if (row[i] == StatusBrick.tick) {
                                row[i] = StatusBrick.empty;
                              }
                            }
                          }
                        }
                      });
                    },
                  ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Auto ticks"),
                  SizedBox(width: 6),
                  Checkbox(
                    value: autoTicks,
                    onChanged: hasTicks
                        ? (newValue) => setState(() {
                            autoTicks = newValue ?? false;
                          })
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
