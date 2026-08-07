import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:games/stars/stars_brick.dart';
import 'package:games/stars/stars_solver.dart';

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

  int _currentSeed = 0;
  String puzzleId = "";

  String status = "Find the solution";
  bool _isGenerating = false;
  int _generationId = 0;

  final Stopwatch stopwatch = Stopwatch();
  Timer? _timer;

  bool hasTicks = true;
  bool autoTicks = false;

  static const List<Color> zoneColors = [
    // [COLOR USED]
    Color.fromARGB(255, 200, 75, 49),
    Color.fromARGB(255, 236, 154, 41),
    Color.fromARGB(255, 55, 110, 71),
    Color.fromARGB(255, 52, 185, 152),
    Color.fromARGB(255, 59, 91, 165),
    Color.fromARGB(255, 123, 82, 130),
    Color.fromARGB(255, 217, 107, 138),
    Color.fromARGB(255, 108, 122, 137),

    // [----]
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

  @override
  void initState() {
    super.initState();
    gridSize = widget.initGridSize;
    difficulty = widget.initDifficulty;
    _startNewGame(0);

    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (stopwatch.isRunning && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewGame(int neededLevel, {int? forceSeed}) {
    _generationId++;
    stopwatch.reset();

    _currentSeed = forceSeed ?? Random().nextInt(999999999);

    setState(() {
      puzzleId = "$gridSize-$neededLevel-$_currentSeed";

      _grid = createPuzzle(gridSize, difficulty, Random(_currentSeed));
      _zones = List.generate(gridSize, (_) => List.filled(gridSize, -1));
      status = "Generating...";
      _isGenerating = true;
    });

    _generateZonesAsync(_generationId, neededLevel, _currentSeed);
  }

  void _biggerSize() {
    if (_isGenerating) return;
    if (gridSize < min(zoneColors.length, 8)) {
      gridSize++;
      _generationId = 0;
      _startNewGame(0);
    }
  }

  void _smallerSize() {
    if (_isGenerating) return;
    if (gridSize > 4) {
      gridSize--;
      _generationId = 0;
      _startNewGame(0);
    }
  }

  void _newGameButton() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('New game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attention!'),
            const Text('You will launch a new game.'),
            const Text('Please select the difficulty.'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'Cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, 'Easy');
              _generationId = 0;
              _startNewGame(1);
            },
            child: const Text('Easy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, 'Normal');
              _generationId = 0;
              _startNewGame(2);
            },
            child: const Text('Normal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, 'Hard');
              _generationId = 0;
              _startNewGame(3);
            },
            child: const Text('Hard'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateZonesAsync(
    int currentGen,
    int neededLevel,
    int seed,
  ) async {
    Random random = Random(seed);
    int size = gridSize;
    List<List<List<int>>> frontiers = List.generate(size, (_) => []);

    int zoneId = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_grid[r][c] == StatusBrick.star) {
          _zones[r][c] = zoneId;
          _addNeighborsToFrontier(r, c, size, frontiers[zoneId]);
          zoneId++;
        }
      }
    }

    // --- PHASE 1 : CROISSANCE INITIALE DES ZONES ---
    while (true) {
      if (_generationId != currentGen) return;

      List<int> activeZones = [];
      for (int z = 0; z < size; z++) {
        frontiers[z].removeWhere((p) => _zones[p[0]][p[1]] != -1);
        if (frontiers[z].isNotEmpty) activeZones.add(z);
      }

      if (activeZones.isEmpty) break;

      int z = activeZones[random.nextInt(activeZones.length)];

      double stretchProb = difficulty / 100.0;
      int index = 0;
      if (random.nextDouble() < stretchProb) {
        index = random.nextBool()
            ? frontiers[z].length - 1
            : random.nextInt(frontiers[z].length);
      }

      var p = frontiers[z].removeAt(index);
      _zones[p[0]][p[1]] = z;
      _addNeighborsToFrontier(p[0], p[1], size, frontiers[z]);
    }

    // --- PHASE 2 : VALIDATION ET MUTATION ---
    bool success = false;
    int maxMutations = 50;
    int level = 1;

    for (int m = 0; m < maxMutations; m++) {
      if (_generationId != currentGen) return;

      int solutions = _countSolutions(_zones, size);

      if (solutions == 1) {
        // Vérifie la logique humaine
        HumanSolver solver = HumanSolver(size: size, zones: _zones);
        HumanSolverResult result = solver.solve();

        if (result.isSolvable) {
          level = result.difficultyLevel;
          if (neededLevel == 0 || neededLevel == level) {
            success = true;
            break; // VICTOIRE ! On sort de la boucle de mutation
          }
        }
      }

      // Si on arrive ici : Soit trop de solutions, soit pas résoluble par la logique.
      // On MUTE la grille !
      bool mutated = _mutateZones(_zones, _grid, random, size);

      if (!mutated) {
        break; // On ne peut plus rien muter sans briser la grille
      }
    }

    if (!success) {
      // Si même après 50 mutations on n'y arrive pas, on recommence de 0.
      // Cela arrivera beaucoup moins souvent qu'avant !
      if (_generationId == currentGen) {
        _startNewGame(neededLevel);
      }
      return;
    }

    // --- PHASE 3 : AFFICHAGE AU JOUEUR ---
    if (_generationId != currentGen) return;

    setState(() {
      puzzleId = "$size-$level-$seed";

      for (int r = 0; r < size; r++) {
        for (int c = 0; c < size; c++) {
          _grid[r][c] = StatusBrick.empty; // Cacher les étoiles
        }
      }
      final difficultyText = level == 1
          ? "Easy"
          : level == 2
          ? "Normal"
          : "Hard";
      status = "[$difficultyText] Find the solution";
      _isGenerating = false;

      stopwatch.start();
    });
  }

  /// Tente de muter la grille. Retourne `true` si une mutation a été faite, `false` sinon.
  bool _mutateZones(
    List<List<int>> tempZones,
    List<List<StatusBrick>> currentGrid,
    Random random,
    int size,
  ) {
    // 1. Trouver toutes les cases "frontières" candidates
    List<List<int>> candidates = [];

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        // Règle 1 : Ne JAMAIS muter une case contenant une étoile !
        if (currentGrid[r][c] == StatusBrick.star) continue;

        int currentZone = tempZones[r][c];

        // Regarder les zones voisines orthogonales
        Set<int> neighborZones = {};
        final dirs = [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ];
        for (var d in dirs) {
          int nr = r + d[0];
          int nc = c + d[1];
          if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            if (tempZones[nr][nc] != currentZone) {
              neighborZones.add(tempZones[nr][nc]);
            }
          }
        }

        // Si elle touche au moins une autre zone, c'est une candidate
        if (neighborZones.isNotEmpty) {
          // Format : [row, col, neighbor_zone_1, neighbor_zone_2...]
          candidates.add([r, c, ...neighborZones]);
        }
      }
    }

    // 2. Mélanger pour ne pas toujours muter le même coin
    candidates.shuffle(random);

    // 3. Essayer les mutations
    for (var candidate in candidates) {
      int r = candidate[0];
      int c = candidate[1];
      int currentZone = tempZones[r][c];

      // Règle 2 : S'assurer que si on enlève cette case, la zone reste un seul bloc continu
      if (_isZoneContiguousWithout(tempZones, currentZone, r, c, size)) {
        // Choisir une des zones voisines au hasard
        List<int> possibleNewZones = candidate.sublist(2);
        int newZone = possibleNewZones[random.nextInt(possibleNewZones.length)];

        // Appliquer la mutation
        tempZones[r][c] = newZone;
        return true;
      }
    }

    return false; // Impossible de muter
  }

  /// Vérifie par un algorithme de Flood-Fill (BFS) si la zone reste d'un seul bloc
  /// si on ignore la case (skipR, skipC).
  bool _isZoneContiguousWithout(
    List<List<int>> tempZones,
    int zoneId,
    int skipR,
    int skipC,
    int size,
  ) {
    int startR = -1, startC = -1;
    int totalCells = 0;

    // Compter les cases et trouver une case de départ (qui n'est pas la case à ignorer)
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (tempZones[r][c] == zoneId && (r != skipR || c != skipC)) {
          totalCells++;
          if (startR == -1) {
            startR = r;
            startC = c;
          }
        }
      }
    }

    if (totalCells == 0) return true;

    // Parcours (BFS) pour compter les cases connectées
    List<List<int>> queue = [
      [startR, startC],
    ];
    List<List<bool>> visited = List.generate(
      size,
      (_) => List.filled(size, false),
    );
    visited[startR][startC] = true;
    int visitedCount = 1;

    int head = 0;
    final dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    while (head < queue.length) {
      var curr = queue[head++];
      for (var d in dirs) {
        int nr = curr[0] + d[0];
        int nc = curr[1] + d[1];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          // Si c'est notre zone, non visitée, et PAS la case qu'on est en train d'enlever
          if (!visited[nr][nc] &&
              tempZones[nr][nc] == zoneId &&
              (nr != skipR || nc != skipC)) {
            visited[nr][nc] = true;
            visitedCount++;
            queue.add([nr, nc]);
          }
        }
      }
    }

    // Si on a visité autant de cases que le total, la zone n'a pas été brisée
    return visitedCount == totalCells;
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

  List<List<StatusBrick>> createPuzzle(
    int size,
    int difficulty,
    Random random,
  ) {
    // Create an empty grid
    List<List<StatusBrick>> list = List.generate(
      size,
      (y) => List.generate(size, (x) => StatusBrick.empty),
    );

    // Find positions for the stars
    if (difficulty > 0) {
      _placeStars(list, 0, size, random);
    }

    return list;
  }

  bool _placeStars(
    List<List<StatusBrick>> grid,
    int col,
    int size,
    Random random,
  ) {
    // Si on a réussi à remplir toutes les colonnes, on a gagné !
    if (col == size) return true;

    // Créer une liste de lignes (0 à size-1) et la mélanger pour l'aléatoire
    List<int> rows = List.generate(size, (i) => i)..shuffle(random);

    // Essayer de placer une étoile dans chaque ligne de cette colonne
    for (int row in rows) {
      if (_isValidPosition(grid, row, col, size)) {
        // Placer l'étoile
        grid[row][col] = StatusBrick.star;

        // Passer à la colonne suivante. Si elle réussit, on renvoie vrai !
        if (_placeStars(grid, col + 1, size, random)) {
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
                return;
              }
            }
          }
        }
      }
    }
    // Vérifier qu'il y a exactement 1 étoile par ligne et par colonne
    if (totalStars != gridSize) {
      return;
    }

    for (int i = 0; i < gridSize; i++) {
      if (starsInRow[i] != 1 || starsInCol[i] != 1 || starsInZone[i] != 1) {
        return;
      }
    }

    stopwatch.stop();
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
      if (solutionsCount > 1) return;

      if (row >= size) {
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

  Future<void> _onBrickTapped(int x, int y) async {
    if (_isGenerating) return;

    setState(() {
      _grid[y][x] = (_grid[y][x] == StatusBrick.empty)
          ? (hasTicks)
                ? StatusBrick.tick
                : StatusBrick.star
          : _grid[y][x] == StatusBrick.tick
          ? StatusBrick.star
          : StatusBrick.empty;

      _testVictory();
    });

    if (hasTicks && autoTicks && _grid[y][x] == StatusBrick.star) {
      await Future.delayed(Duration(milliseconds: 1200));
      if (hasTicks && autoTicks && _grid[y][x] == StatusBrick.star) {
        autoTicker(y, x);
      }
    }
  }

  void autoTicker(int y, int x) {
    final List<List<int>> adjacents = [
      [y - 1, x - 1],
      [y - 1, x],
      [y - 1, x + 1],
      [y, x - 1],
      [y, x + 1],
      [y + 1, x - 1],
      [y + 1, x],
      [y + 1, x + 1],
    ];
    List<List<int>> positions;
    positions = [];
    positions.addAll(adjacents);

    final zone = _zones[y][x];

    for (var i = 0; i < gridSize; i++) {
      positions.add([y, i]);
      positions.add([i, x]);
      for (var j = 0; j < gridSize; j++) {
        if (_zones[i][j] == zone) {
          positions.add([i, j]);
        }
      }
    }

    setState(() {
      for (var pos in positions) {
        if (pos[0] >= 0 &&
            pos[0] < gridSize &&
            pos[1] >= 0 &&
            pos[1] < gridSize &&
            !(pos[0] == y && pos[1] == x)) {
          if (_grid[pos[0]][pos[1]] != StatusBrick.star) {
            _grid[pos[0]][pos[1]] = StatusBrick.tick;
          }
        }
      }
    });
  }

  String _formatStopwatch() {
    final duration = stopwatch.elapsed;
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String? hours;
    if (duration >= Duration(hours: 1)) {
      hours = twoDigits(duration.inHours.remainder(60));
    }
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    final formattedText = hours == null
        ? "$minutes:$seconds"
        : "$hours:$minutes:$seconds";
    return formattedText;
  }

  void _showLoadPuzzleDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Load Puzzle ID"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Ex: 5-2-123456789",
            labelText: "Paste ID here",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              try {
                // Découper le texte "Taille-Niveau-Seed"
                List<String> parts = controller.text.trim().split('-');
                if (parts.length == 3) {
                  int loadedSize = int.parse(parts[0]);
                  int loadedLevel = int.parse(parts[1]);
                  int loadedSeed = int.parse(parts[2]);

                  // Mettre à jour la grille et lancer
                  gridSize = loadedSize;
                  Navigator.pop(context);

                  _generationId = 0; // Reset
                  _startNewGame(loadedLevel, forceSeed: loadedSeed);
                }
              } catch (e) {
                // L'ID est invalide (Optionnel: afficher un message d'erreur)
              }
            },
            child: const Text("Load"),
          ),
        ],
      ),
    );
  }

  // TODO
  // Mark stars as red when in conflict
  // Undo button + clear board

  @override
  Widget build(BuildContext context) {
    final int ms = stopwatch.elapsedMilliseconds % 60000;
    final bool isNearMinute = ms < 2000 || ms > 58000;

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
            onPressed: _newGameButton,
          ),
          IconButton(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Load an ID',
            onPressed: _showLoadPuzzleDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 6.0,
                horizontal: 6.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatStopwatch(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isNearMinute ? FontWeight.bold : null,
                            color: isNearMinute ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: puzzleId),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard!'),
                                ),
                              );
                            }
                          },
                          child: Text("ID: $puzzleId"),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: TextButton(
                      onPressed: () {
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('Rules'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Place EXACTLY ONE star in every column, row and color zone!',
                                ),
                                SizedBox(height: 12),
                                const Text(
                                  'Stars cannot touch each other, even diagonally.',
                                ),
                                SizedBox(height: 12),
                                const Text(
                                  'Activate Auto ticks to show these rules in action when you place a star.',
                                ),
                              ],
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'OK'),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text("Rules"),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    Text("Activate ticks"),
                    SizedBox(width: 6),
                    Switch(
                      value: hasTicks,
                      onChanged: (bool newValue) {
                        setState(() {
                          hasTicks = newValue;
                          if (!hasTicks) {
                            for (final column in _grid) {
                              for (var y = 0; y < column.length; y++) {
                                if (column[y] == StatusBrick.tick) {
                                  column[y] = StatusBrick.empty;
                                }
                              }
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),

                TextButton(onPressed: () {}, child: Text("Help")),

                Row(
                  children: [
                    Text("Auto ticks?"),
                    SizedBox(width: 6),
                    Checkbox(
                      value: autoTicks,
                      onChanged: (bool? newValue) {
                        setState(() {
                          autoTicks = newValue ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
