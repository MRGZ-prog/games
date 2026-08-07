import 'dart:math';
import 'package:games/stars/stars_brick.dart';
import 'package:games/stars/stars_solver.dart';
import 'stars_constants.dart';

class PuzzleData {
  final List<List<StatusBrick>> grid;
  final List<List<int>> zones;
  final int level;

  PuzzleData(this.grid, this.zones, this.level);
}

class PuzzleLogic {
  static Future<PuzzleData?> generateAsync(
    int size,
    int difficulty,
    int neededLevel,
    int seed,
    int currentGen,
    int Function() getActiveGen,
  ) async {
    Random random = Random(seed);
    List<List<StatusBrick>> grid = _createPuzzle(size, difficulty, random);
    List<List<int>> zones = List.generate(size, (_) => List.filled(size, -1));
    List<List<List<int>>> frontiers = List.generate(size, (_) => []);

    int zoneId = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == StatusBrick.star) {
          zones[r][c] = zoneId;
          _addNeighborsToFrontier(r, c, size, zones, frontiers[zoneId]);
          zoneId++;
        }
      }
    }

    // PHASE 1 : CROISSANCE
    while (true) {
      if (getActiveGen() != currentGen) return null;

      List<int> activeZones = [];
      for (int z = 0; z < size; z++) {
        frontiers[z].removeWhere((p) => zones[p[0]][p[1]] != -1);
        if (frontiers[z].isNotEmpty) activeZones.add(z);
      }

      if (activeZones.isEmpty) break;

      int z = activeZones[random.nextInt(activeZones.length)];
      double stretchProb = difficulty / 100.0;
      int index = (random.nextDouble() < stretchProb)
          ? (random.nextBool()
                ? frontiers[z].length - 1
                : random.nextInt(frontiers[z].length))
          : 0;

      var p = frontiers[z].removeAt(index);
      zones[p[0]][p[1]] = z;
      _addNeighborsToFrontier(p[0], p[1], size, zones, frontiers[z]);
    }

    // PHASE 2 : MUTATION
    bool success = false;
    int level = 1;
    for (int m = 0; m < 50; m++) {
      if (getActiveGen() != currentGen) return null;

      int solutions = _countSolutions(zones, size);
      if (solutions == 1) {
        HumanSolver solver = HumanSolver(size: size, zones: zones);
        HumanSolverResult result = solver.solve();

        if (result.isSolvable) {
          level = result.difficultyLevel;
          if (neededLevel == 0 || neededLevel == level) {
            success = true;
            break;
          }
        }
      }

      if (!_mutateZones(zones, grid, random, size)) break;
    }

    if (!success) return null; // Retourne null si échec, l'UI gérera le retry

    // Masquer les étoiles pour le joueur
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        grid[r][c] = StatusBrick.empty;
      }
    }

    return PuzzleData(grid, zones, level);
  }

  // --- Méthodes privées recopiées depuis votre code original ---

  static List<List<StatusBrick>> _createPuzzle(
    int size,
    int difficulty,
    Random random,
  ) {
    List<List<StatusBrick>> list = List.generate(
      size,
      (y) => List.generate(size, (x) => StatusBrick.empty),
    );
    if (difficulty > 0) _placeStars(list, 0, size, random);
    return list;
  }

  static bool _placeStars(
    List<List<StatusBrick>> grid,
    int col,
    int size,
    Random random,
  ) {
    if (col == size) return true;
    List<int> rows = List.generate(size, (i) => i)..shuffle(random);
    for (int row in rows) {
      if (_isValidPosition(grid, row, col, size)) {
        grid[row][col] = StatusBrick.star;
        if (_placeStars(grid, col + 1, size, random)) return true;
        grid[row][col] = StatusBrick.empty;
      }
    }
    return false;
  }

  static bool _isValidPosition(
    List<List<StatusBrick>> grid,
    int row,
    int col,
    int size,
  ) {
    for (int x = 0; x < size; x++) {
      if (grid[row][x] == StatusBrick.star) return false;
    }
    for (var dir in GameConstants.directions8) {
      int checkY = row + dir[0];
      int checkX = col + dir[1];
      if (checkY >= 0 && checkY < size && checkX >= 0 && checkX < size) {
        if (grid[checkY][checkX] == StatusBrick.star) return false;
      }
    }
    return true;
  }

  static void _addNeighborsToFrontier(
    int r,
    int c,
    int size,
    List<List<int>> zones,
    List<List<int>> frontier,
  ) {
    for (var d in GameConstants.directions4) {
      int nr = r + d[0], nc = c + d[1];
      if (nr >= 0 && nr < size && nc >= 0 && nc < size && zones[nr][nc] == -1) {
        frontier.add([nr, nc]);
      }
    }
  }
}

int _countSolutions(List<List<int>> zones, int size) {
  int solutionsCount = 0;
  List<bool> colsOccupied = List.filled(size, false);
  List<bool> zonesOccupied = List.filled(size, false);
  List<List<bool>> stars = List.generate(size, (_) => List.filled(size, false));

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
