import 'dart:math';

import 'package:flutter/material.dart';
import 'package:games/queens/stars_brick.dart';
import 'package:games/queens/stars_solver.dart';

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
  late List<List<StatusBrick>> _grid;
  late List<List<int>> _zones;

  String status = "Find the solution";
  bool _isGenerating = false;
  int _generationId = 0;

  static const List<Color> zoneColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.green,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.white,
    Colors.yellow,
    Colors.deepOrangeAccent,
    Colors.indigoAccent,
    Colors.lightGreenAccent,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    gridSize = widget.initGridSize;
    difficulty = widget.initDifficulty;
    _startNewGame();
  }

  void _startNewGame() {
    _generationId++;
    setState(() {
      _grid = createPuzzle(gridSize, difficulty);
      _zones = List.generate(gridSize, (_) => List.filled(gridSize, -1));
      status = "Generating... attempt $_generationId";
      _isGenerating = true;
    });

    _generateZonesAsync(_generationId);
  }

  void _biggerSize() {
    if (_isGenerating) return;
    if (gridSize < zoneColors.length) {
      gridSize++;
      _startNewGame();
    }
  }

  void _smallerSize() {
    if (_isGenerating) return;
    if (gridSize > 4) {
      gridSize--;
      _startNewGame();
    }
  }

  Future<void> _generateZonesAsync(int currentGen) async {
    Random random = Random();
    int size = gridSize;

    // Frontières pour chaque zone (les cases voisines disponibles)
    List<List<List<int>>> frontiers = List.generate(size, (_) => []);

    int zoneId = 0;
    // 1. Initialiser les zones autour des étoiles
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_grid[r][c] == StatusBrick.star) {
          _zones[r][c] = zoneId;
          _addNeighborsToFrontier(r, c, size, frontiers[zoneId]);
          zoneId++;
        }
      }
    }
    bool changed = true;
    while (changed) {
      if (_generationId != currentGen) return;

      changed = false;
      // Mélanger l'ordre d'expansion pour que les zones grandissent de façon équilibrée
      List<int> zOrder = List.generate(size, (i) => i)..shuffle(random);

      for (int z in zOrder) {
        // Nettoyer la frontière des cases déjà assignées
        frontiers[z].removeWhere((p) => _zones[p[0]][p[1]] != -1);
        if (frontiers[z].isEmpty) continue;

        // Choix du prochain pixel en fonction de la difficulté
        double stretchProb = difficulty / 100.0;
        int index =
            0; // Par défaut : comportement BFS (Compact, proche de l'étoile)

        if (random.nextDouble() < stretchProb) {
          // Comportement DFS ou Aléatoire : Allongement de la zone
          index = random.nextBool()
              ? frontiers[z].length - 1
              : random.nextInt(frontiers[z].length);
        }

        var p = frontiers[z].removeAt(index);
        _zones[p[0]][p[1]] = z;
        _addNeighborsToFrontier(p[0], p[1], size, frontiers[z]);
        changed = true;
      }

      setState(() {});
    }

    if (_generationId != currentGen) return;

    int solutions = _countSolutions(_zones, size);

    if (solutions == 0 || solutions > 2) {
      // S'il y a 0 ou plusieurs solutions, on recommence tout
      if (_generationId == currentGen) {
        _startNewGame();
      }
      return;
    }

    HumanSolver solver = HumanSolver(size: size, zones: _zones);
    HumanSolverResult result = solver.solve();

    if (!result.isSolvable) {
      await Future.delayed(Duration(microseconds: 1));
      // Le puzzle nécessite de deviner/faire des essais-erreurs -> Recommencer !
      _startNewGame();
      return;
    }

    // 2. Nettoyer les étoiles pour laisser le joueur jouer
    setState(() {
      for (int r = 0; r < size; r++) {
        for (int c = 0; c < size; c++) {
          _grid[r][c] = StatusBrick.empty;
        }
      }
      status = "Find the solution";
      _isGenerating = false;
    });
  }

  void _addNeighborsToFrontier(
    int r,
    int c,
    int size,
    List<List<int>> frontier,
  ) {
    // Connexions orthogonales pour la construction des zones (Haut, Bas, Gauche, Droite)
    final List<List<int>> dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (var d in dirs) {
      int nr = r + d[0];
      int nc = c + d[1];
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        if (_zones[nr][nc] == -1) {
          frontier.add([nr, nc]);
        }
      }
    }
  }

  List<List<StatusBrick>> createPuzzle(int size, int difficulty) {
    // Create an empty grid
    List<List<StatusBrick>> list = List.generate(
      size,
      (y) => List.generate(size, (x) => StatusBrick.empty),
    );

    // Find positions for the stars
    if (difficulty > 0) {
      _placeStars(list, 0, size);
    }

    return list;
  }

  bool _placeStars(List<List<StatusBrick>> grid, int col, int size) {
    // Si on a réussi à remplir toutes les colonnes, on a gagné !
    if (col == size) return true;

    // Créer une liste de lignes (0 à size-1) et la mélanger pour l'aléatoire
    List<int> rows = List.generate(size, (i) => i)..shuffle();

    // Essayer de placer une étoile dans chaque ligne de cette colonne
    for (int row in rows) {
      if (_isValidPosition(grid, row, col, size)) {
        // Placer l'étoile
        grid[row][col] = StatusBrick.star;

        // Passer à la colonne suivante. Si elle réussit, on renvoie vrai !
        if (_placeStars(grid, col + 1, size)) {
          return true;
        }

        // BACKTRACKING : Si la colonne suivante a échoué, on retire l'étoile
        // et on essaye la prochaine ligne de notre liste mélangée.
        grid[row][col] = StatusBrick.empty;
      }
    }
    // Si aucune ligne n'a fonctionné, on prévient la colonne précédente qu'elle doit changer
    return false;
  }

  bool _isValidPosition(
    List<List<StatusBrick>> grid,
    int row,
    int col,
    int size,
  ) {
    // 1. Vérifier la ligne entière
    for (int x = 0; x < size; x++) {
      if (grid[row][x] == StatusBrick.star) return false;
    }

    // 2. Vérifier les 8 cases autour (voisins et diagonales)
    final List<List<int>> directions = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];

    for (var dir in directions) {
      int checkY = row + dir[0];
      int checkX = col + dir[1];

      // Si la case est dans la grille
      if (checkY >= 0 && checkY < size && checkX >= 0 && checkX < size) {
        if (grid[checkY][checkX] == StatusBrick.star) return false;
      }
    }

    return true;
  }

  void _testVictory() {
    int totalStars = 0;
    List<int> starsInRow = List.filled(gridSize, 0);
    List<int> starsInCol = List.filled(gridSize, 0);
    List<int> starsInZone = List.filled(gridSize, 0);

    final List<List<int>> directions = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_grid[r][c] == StatusBrick.star) {
          totalStars++;
          starsInRow[r]++;
          starsInCol[c]++;
          if (_zones[r][c] != -1) {
            starsInZone[_zones[r][c]]++;
          }

          // Vérifier les 8 cases adjacentes (pas de contact diagonal ou direct)
          for (var dir in directions) {
            int nr = r + dir[0];
            int nc = c + dir[1];
            if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
              if (_grid[nr][nc] == StatusBrick.star) {
                status = "Find the solution";
                return;
              }
            }
          }
        }
      }
    }
    // Vérifier qu'il y a exactement 1 étoile par ligne et par colonne
    if (totalStars != gridSize) {
      status = "Find the solution";
      return;
    }

    for (int i = 0; i < gridSize; i++) {
      if (starsInRow[i] != 1 || starsInCol[i] != 1 || starsInZone[i] != 1) {
        status = "Find the solution";
        return;
      }
    }

    status = "Victory";
  }

  int _countSolutions(List<List<int>> zones, int size) {
    int solutionsCount = 0;
    List<bool> colsOccupied = List.filled(size, false);
    List<bool> zonesOccupied = List.filled(size, false);
    List<List<bool>> stars = List.generate(
      size,
      (_) => List.filled(size, false),
    );

    // Fonction récursive interne pour tester les lignes une par une
    void solve(int row) {
      if (solutionsCount > 1)
        return; // Optimisation : on s'arrête si on a déjà trouvé plusieurs solutions

      if (row == size) {
        solutionsCount++;
        return;
      }

      for (int col = 0; col < size; col++) {
        int zoneId = zones[row][col];

        // Vérifier si la colonne ou la zone est déjà occupée
        if (colsOccupied[col] || zonesOccupied[zoneId]) continue;

        // Vérifier les 8 cases autour (seulement celles au-dessus et à gauche car on remplit de haut en bas)
        bool hasAdjacentStar = false;
        final List<List<int>> directions = [
          [-1, -1],
          [-1, 0],
          [-1, 1],
          [0, -1],
        ];
        for (var dir in directions) {
          int r = row + dir[0];
          int c = col + dir[1];
          if (r >= 0 && r < size && c >= 0 && c < size) {
            if (stars[r][c]) {
              hasAdjacentStar = true;
              break;
            }
          }
        }
        if (hasAdjacentStar) continue;

        // Placer une étoile pour tester
        stars[row][col] = true;
        colsOccupied[col] = true;
        zonesOccupied[zoneId] = true;

        solve(row + 1); // Tester la ligne suivante

        // Backtracking : retirer l'étoile
        stars[row][col] = false;
        colsOccupied[col] = false;
        zonesOccupied[zoneId] = false;
      }
    }

    solve(0);
    return solutionsCount;
  }

  void _onBrickTapped(int x, int y) {
    if (_isGenerating) return;

    setState(() {
      _grid[y][x] = _grid[y][x] == StatusBrick.empty
          ? StatusBrick.tick
          : _grid[y][x] == StatusBrick.tick
          ? StatusBrick.star
          : StatusBrick.empty;

      _testVictory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Constellations'),
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
                    status,
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(
                        gridSize,
                        (y) => Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(gridSize, (x) {
                              int zId = _zones[y][x];
                              Color brickColor = zId == -1
                                  ? Colors.grey.shade300
                                  : zoneColors[zId % zoneColors.length];

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: StarsBrick(
                                    status: _grid[y][x],
                                    color: brickColor,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
