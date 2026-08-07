enum SolverCell { empty, star, cross }

class HumanSolverResult {
  final bool isSolvable;
  final int stepsCount;
  final int
  difficultyLevel; // 1: Facile, 2: Moyen (Formes), 3: Difficile (X-Wing)

  HumanSolverResult({
    required this.isSolvable,
    required this.stepsCount,
    required this.difficultyLevel,
  });
}

class HumanSolver {
  final int size;
  final List<List<int>> zones;

  HumanSolver({required this.size, required this.zones});

  HumanSolverResult solve() {
    List<List<SolverCell>> grid = List.generate(
      size,
      (_) => List.filled(size, SolverCell.empty),
    );

    bool progress = true;
    int steps = 0;
    int maxRuleLevel = 1;

    while (progress) {
      progress = false;

      // Victoire ?
      if (_countTotalStars(grid) == size) break;

      // Niveau 1 : Règles basiques (Placement forcé, proximité, remplissage)
      if (_applyBasicRules(grid)) {
        progress = true;
        steps++;
        continue;
      }

      // Niveau 2 : Règle d'Intersection Universelle (Gère TOUTES les formes : V, L, lignes de 2/3)
      if (_applyIntersectionRule(grid)) {
        progress = true;
        steps++;
        if (maxRuleLevel < 2) maxRuleLevel = 2;
        continue;
      }

      // Niveau 3 : Règle des Sous-ensembles (X zones cantonnées dans X lignes/colonnes)
      if (_applySubsetRules(grid)) {
        progress = true;
        steps++;
        if (maxRuleLevel < 3) maxRuleLevel = 3;
        continue;
      }
    }

    return HumanSolverResult(
      isSolvable: _countTotalStars(grid) == size,
      stepsCount: steps,
      difficultyLevel: maxRuleLevel,
    );
  }

  // ==========================================
  // NIVEAU 1 : RÈGLES DE BASE
  // ==========================================
  bool _applyBasicRules(List<List<SolverCell>> grid) {
    bool changed = false;

    // A. Élimination par proximité et lignes/colonnes/zones complètes
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == SolverCell.star) {
          if (_crossOutNeighbors(grid, r, c)) changed = true;
          if (_crossOutRow(grid, r, c)) changed = true;
          if (_crossOutCol(grid, c, r)) changed = true;
          if (_crossOutZone(grid, zones[r][c], r, c)) changed = true;
        }
      }
    }

    // B. Placement forcé (Une seule case vide restante)
    for (int i = 0; i < size; i++) {
      if (_getStarsInRow(grid, i) == 0) {
        var empties = _getEmptyInRow(grid, i);
        if (empties.length == 1 &&
            _placeStar(grid, empties[0][0], empties[0][1])) {
          return true;
        }
      }
      if (_getStarsInCol(grid, i) == 0) {
        var empties = _getEmptyInCol(grid, i);
        if (empties.length == 1 &&
            _placeStar(grid, empties[0][0], empties[0][1])) {
          return true;
        }
      }
      if (_getStarsInZone(grid, i) == 0) {
        var empties = _getEmptyInZone(grid, i);
        if (empties.length == 1 &&
            _placeStar(grid, empties[0][0], empties[0][1])) {
          return true;
        }
      }
    }

    return changed;
  }

  // ==========================================
  // NIVEAU 2 : INTERSECTIONS DYNAMIQUES (Formes)
  // ==========================================
  /// Magie mathématique : Au lieu de coder "Si forme en V, alors bloque le creux",
  /// on calcule l'intersection de TOUT ce qui est bloqué par TOUTES les cases vides
  /// d'une zone. Cela englobe naturellement les lignes, les L, les V et les alignements !
  bool _applyIntersectionRule(List<List<SolverCell>> grid) {
    bool changed = false;

    // Calcule ce que bloquerait une étoile placée en (r, c)
    Set<int> getBlockedBy(int r, int c) {
      Set<int> blocked = {};
      for (int i = 0; i < size; i++) {
        if (i != c) blocked.add(r * size + i); // Sa ligne
        if (i != r) blocked.add(i * size + c); // Sa colonne
      }
      int z = zones[r][c];
      for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
          if ((i != r || j != c) && zones[i][j] == z) {
            blocked.add(i * size + j); // Sa zone
          }
        }
      }
      final dirs = [
        [-1, -1],
        [-1, 0],
        [-1, 1],
        [0, -1],
        [0, 1],
        [1, -1],
        [1, 0],
        [1, 1],
      ];
      for (var d in dirs) {
        int nr = r + d[0], nc = c + d[1];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          blocked.add(nr * size + nc); // Ses 8 voisins
        }
      }
      return blocked;
    }

    bool checkGroup(List<List<int>> emptyCells) {
      if (emptyCells.isEmpty) return false;
      bool localChanged = false;

      // 1. Prendre ce qui est bloqué par la 1ère case
      Set<int> intersection = getBlockedBy(emptyCells[0][0], emptyCells[0][1]);

      // 2. Faire l'intersection avec les blocages de toutes les autres cases
      for (int i = 1; i < emptyCells.length; i++) {
        intersection = intersection.intersection(
          getBlockedBy(emptyCells[i][0], emptyCells[i][1]),
        );
        if (intersection.isEmpty) break;
      }

      // 3. Tout ce qui survit à l'intersection est FORCÉMENT bloqué
      for (int index in intersection) {
        int r = index ~/ size;
        int c = index % size;
        if (grid[r][c] == SolverCell.empty) {
          grid[r][c] = SolverCell.cross;
          localChanged = true;
        }
      }
      return localChanged;
    }

    // Appliquer à toutes les Zones, Lignes et Colonnes
    for (int i = 0; i < size; i++) {
      if (_getStarsInZone(grid, i) == 0 &&
          checkGroup(_getEmptyInZone(grid, i))) {
        changed = true;
      }
      if (_getStarsInRow(grid, i) == 0 && checkGroup(_getEmptyInRow(grid, i))) {
        changed = true;
      }
      if (_getStarsInCol(grid, i) == 0 && checkGroup(_getEmptyInCol(grid, i))) {
        changed = true;
      }
    }

    return changed;
  }

  // ==========================================
  // NIVEAU 3 : SOUS-ENSEMBLES (X-Wing / Naked Pairs)
  // ==========================================
  /// Implémente la règle : "Quand X zones sont cantonnées dans X lignes..."
  bool _applySubsetRules(List<List<SolverCell>> grid) {
    bool changed = false;
    List<int> allIndices = List.generate(size, (i) => i);

    // On teste les groupes de taille 2 jusqu'à (size - 1)
    for (int n = 2; n < size; n++) {
      var combinations = _getCombinations(allIndices, n);

      for (var combo in combinations) {
        // Règle 3.1 : X Zones confinées dans X Lignes
        Set<int> rowsUsedByZones = {};
        for (int z in combo) {
          rowsUsedByZones.addAll(_getEmptyInZone(grid, z).map((p) => p[0]));
        }
        if (rowsUsedByZones.length == n) {
          // Les N zones n'existent que dans N lignes
          for (int r in rowsUsedByZones) {
            for (int c = 0; c < size; c++) {
              if (grid[r][c] == SolverCell.empty &&
                  !combo.contains(zones[r][c])) {
                grid[r][c] =
                    SolverCell.cross; // Bloque les autres zones sur ces lignes
                changed = true;
              }
            }
          }
        }

        // Règle 3.2 : X Zones confinées dans X Colonnes
        Set<int> colsUsedByZones = {};
        for (int z in combo) {
          colsUsedByZones.addAll(_getEmptyInZone(grid, z).map((p) => p[1]));
        }
        if (colsUsedByZones.length == n) {
          for (int c in colsUsedByZones) {
            for (int r = 0; r < size; r++) {
              if (grid[r][c] == SolverCell.empty &&
                  !combo.contains(zones[r][c])) {
                grid[r][c] = SolverCell.cross;
                changed = true;
              }
            }
          }
        }

        // Règle 3.3 : X Lignes confinées dans X Zones
        Set<int> zonesUsedByRows = {};
        for (int r in combo) {
          zonesUsedByRows.addAll(
            _getEmptyInRow(grid, r).map((p) => zones[p[0]][p[1]]),
          );
        }
        if (zonesUsedByRows.length == n) {
          // Les N lignes n'ont des cases que dans N zones
          for (int z in zonesUsedByRows) {
            for (var p in _getEmptyInZone(grid, z)) {
              if (!combo.contains(p[0]) &&
                  grid[p[0]][p[1]] == SolverCell.empty) {
                grid[p[0]][p[1]] =
                    SolverCell.cross; // Bloque le reste des zones
                changed = true;
              }
            }
          }
        }

        // (Note: Par symétrie du jeu, implémenter les colonnes confinées dans les zones est souvent redondant,
        // mais le code est identique à 3.3 en inversant r et c).
      }
      if (changed) return true; // Fail-fast pour recommencer la logique de base
    }
    return changed;
  }

  // ==========================================
  // SYSTÈME D'INDICE INTELLIGENT
  // ==========================================
  List<List<int>> getHintCrosses(List<List<SolverCell>> currentState) {
    // 1. Créer une copie de travail de la grille actuelle
    List<List<SolverCell>> grid = List.generate(
      size,
      (r) => List.generate(size, (c) => currentState[r][c]),
    );

    // 2. Tenter d'appliquer les règles logiques (une seule passe)
    bool progress =
        _applyBasicRules(grid) ||
        _applyIntersectionRule(grid) ||
        _applySubsetRules(grid);

    List<List<int>> newCrosses = [];

    if (progress) {
      // 3. Comparer l'état initial et le nouvel état pour extraire les déductions
      for (int r = 0; r < size; r++) {
        for (int c = 0; c < size; c++) {
          // Si la logique a placé une croix là où il n'y avait rien
          if (currentState[r][c] == SolverCell.empty &&
              grid[r][c] == SolverCell.cross) {
            newCrosses.add([r, c]);
          }
        }
      }
    }
    return newCrosses;
  }

  // ==========================================
  // OUTILS & HELPERS
  // ==========================================

  bool _placeStar(List<List<SolverCell>> grid, int r, int c) {
    grid[r][c] = SolverCell.star;
    return true;
  }

  List<List<int>> _getCombinations(List<int> list, int n) {
    if (n == 0) return [[]];
    if (list.isEmpty) return [];
    List<List<int>> result = [];
    for (int i = 0; i <= list.length - n; i++) {
      int first = list[i];
      for (var combo in _getCombinations(list.sublist(i + 1), n - 1)) {
        result.add([first, ...combo]);
      }
    }
    return result;
  }

  bool _crossOutNeighbors(List<List<SolverCell>> grid, int r, int c) {
    bool changed = false;
    final dirs = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];
    for (var d in dirs) {
      int nr = r + d[0], nc = c + d[1];
      if (nr >= 0 &&
          nr < size &&
          nc >= 0 &&
          nc < size &&
          grid[nr][nc] == SolverCell.empty) {
        grid[nr][nc] = SolverCell.cross;
        changed = true;
      }
    }
    return changed;
  }

  bool _crossOutRow(List<List<SolverCell>> grid, int r, int ignoreCol) {
    bool changed = false;
    for (int c = 0; c < size; c++) {
      if (c != ignoreCol && grid[r][c] == SolverCell.empty) {
        grid[r][c] = SolverCell.cross;
        changed = true;
      }
    }
    return changed;
  }

  bool _crossOutCol(List<List<SolverCell>> grid, int c, int ignoreRow) {
    bool changed = false;
    for (int r = 0; r < size; r++) {
      if (r != ignoreRow && grid[r][c] == SolverCell.empty) {
        grid[r][c] = SolverCell.cross;
        changed = true;
      }
    }
    return changed;
  }

  bool _crossOutZone(
    List<List<SolverCell>> grid,
    int z,
    int ignoreR,
    int ignoreC,
  ) {
    bool changed = false;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (zones[r][c] == z &&
            (r != ignoreR || c != ignoreC) &&
            grid[r][c] == SolverCell.empty) {
          grid[r][c] = SolverCell.cross;
          changed = true;
        }
      }
    }
    return changed;
  }

  int _countTotalStars(List<List<SolverCell>> grid) {
    int count = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (cell == SolverCell.star) count++;
      }
    }
    return count;
  }

  int _getStarsInRow(List<List<SolverCell>> grid, int r) =>
      grid[r].where((c) => c == SolverCell.star).length;

  int _getStarsInCol(List<List<SolverCell>> grid, int c) => List.generate(
    size,
    (r) => grid[r][c],
  ).where((cell) => cell == SolverCell.star).length;

  int _getStarsInZone(List<List<SolverCell>> grid, int z) {
    int count = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (zones[r][c] == z && grid[r][c] == SolverCell.star) count++;
      }
    }
    return count;
  }

  List<List<int>> _getEmptyInRow(List<List<SolverCell>> grid, int r) {
    List<List<int>> list = [];
    for (int c = 0; c < size; c++) {
      if (grid[r][c] == SolverCell.empty) list.add([r, c]);
    }
    return list;
  }

  List<List<int>> _getEmptyInCol(List<List<SolverCell>> grid, int c) {
    List<List<int>> list = [];
    for (int r = 0; r < size; r++) {
      if (grid[r][c] == SolverCell.empty) list.add([r, c]);
    }
    return list;
  }

  List<List<int>> _getEmptyInZone(List<List<SolverCell>> grid, int z) {
    List<List<int>> list = [];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (zones[r][c] == z && grid[r][c] == SolverCell.empty) {
          list.add([r, c]);
        }
      }
    }
    return list;
  }
}
