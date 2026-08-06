enum SolverCell { empty, star, cross }

class HumanSolverResult {
  /// Vrai si le puzzle peut être résolu uniquement par la logique.
  final bool isSolvable;

  /// Nombre d'étapes logiques nécessaires pour résoudre la grille.
  final int stepsCount;

  /// Niveau de difficulté basé sur les règles utilisées (1 = Facile, 2 = Avancé).
  final int difficultyLevel;

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

  /// Tente de résoudre la grille avec des déductions logiques humaines.
  HumanSolverResult solve() {
    // Grille de travail interne
    List<List<SolverCell>> grid = List.generate(
      size,
      (_) => List.filled(size, SolverCell.empty),
    );

    bool progress = true;
    int steps = 0;
    int maxRuleLevel = 1;

    while (progress) {
      progress = false;

      // 1. Vérifier si la grille est déjà résolue
      if (_countTotalStars(grid) == size) {
        return HumanSolverResult(
          isSolvable: true,
          stepsCount: steps,
          difficultyLevel: maxRuleLevel,
        );
      }

      // 2. Règles de base (Niveau 1) : Placement forcé et élimination directe
      if (_applyBasicRules(grid)) {
        progress = true;
        steps++;
        continue;
      }

      // 3. Règles avancées (Niveau 2) : Alignements et intersections Zone/Ligne/Colonne
      if (_applyAlignmentRules(grid)) {
        progress = true;
        steps++;
        if (maxRuleLevel < 2) maxRuleLevel = 2;
        continue;
      }

      // Si aucune règle ne fait progresser la grille, le solveur est bloqué.
    }

    return HumanSolverResult(
      isSolvable: _countTotalStars(grid) == size,
      stepsCount: steps,
      difficultyLevel: maxRuleLevel,
    );
  }

  // ==========================================
  // RÈGLES DE NIVEAU 1 : DÉDUCTIONS DE BASE
  // ==========================================

  bool _applyBasicRules(List<List<SolverCell>> grid) {
    bool changed = false;

    // A. Élimination par proximité : Placer des croix autour de chaque étoile
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == SolverCell.star) {
          if (_crossOutNeighbors(grid, r, c)) changed = true;
        }
      }
    }

    // B. Élimination de ligne/colonne/zone quand une étoile est trouvée
    for (int i = 0; i < size; i++) {
      if (_getStarsInRow(grid, i) == 1 && _crossOutRow(grid, i)) changed = true;
      if (_getStarsInCol(grid, i) == 1 && _crossOutCol(grid, i)) changed = true;
      if (_getStarsInZone(grid, i) == 1 && _crossOutZone(grid, i))
        changed = true;
    }

    // C. Placement forcé : Si une ligne/colonne/zone n'a qu'1 seule case vide restante
    for (int i = 0; i < size; i++) {
      // Ligne
      if (_getStarsInRow(grid, i) == 0) {
        var empties = _getEmptyInRow(grid, i);
        if (empties.length == 1) {
          grid[empties[0][0]][empties[0][1]] = SolverCell.star;
          return true;
        }
      }
      // Colonne
      if (_getStarsInCol(grid, i) == 0) {
        var empties = _getEmptyInCol(grid, i);
        if (empties.length == 1) {
          grid[empties[0][0]][empties[0][1]] = SolverCell.star;
          return true;
        }
      }
      // Zone
      if (_getStarsInZone(grid, i) == 0) {
        var empties = _getEmptyInZone(grid, i);
        if (empties.length == 1) {
          grid[empties[0][0]][empties[0][1]] = SolverCell.star;
          return true;
        }
      }
    }

    return changed;
  }

  // ==========================================
  // RÈGLES DE NIVEAU 2 : ALIGNEMENTS
  // ==========================================

  bool _applyAlignmentRules(List<List<SolverCell>> grid) {
    bool changed = false;

    // A. Si TOUTES les cases vides d'une ZONE sont alignées sur une même LIGNE
    //    -> Aucune autre case de cette ligne ne peut contenir d'étoile.
    for (int z = 0; z < size; z++) {
      if (_getStarsInZone(grid, z) > 0) continue;
      var empties = _getEmptyInZone(grid, z);
      if (empties.isEmpty) continue;

      int firstRow = empties[0][0];
      bool sameRow = empties.every((p) => p[0] == firstRow);

      if (sameRow) {
        for (int c = 0; c < size; c++) {
          if (zones[firstRow][c] != z &&
              grid[firstRow][c] == SolverCell.empty) {
            grid[firstRow][c] = SolverCell.cross;
            changed = true;
          }
        }
      }

      // Même logique pour la COLONNE
      int firstCol = empties[0][1];
      bool sameCol = empties.every((p) => p[1] == firstCol);

      if (sameCol) {
        for (int r = 0; r < size; r++) {
          if (zones[r][firstCol] != z &&
              grid[r][firstCol] == SolverCell.empty) {
            grid[r][firstCol] = SolverCell.cross;
            changed = true;
          }
        }
      }
    }

    // B. Réciproque : Si TOUTES les cases vides d'une LIGNE sont dans la même ZONE
    //    -> Aucune autre case de cette zone ne peut contenir d'étoile.
    for (int r = 0; r < size; r++) {
      if (_getStarsInRow(grid, r) > 0) continue;
      var empties = _getEmptyInRow(grid, r);
      if (empties.isEmpty) continue;

      int targetZone = zones[empties[0][0]][empties[0][1]];
      bool sameZone = empties.every((p) => zones[p[0]][p[1]] == targetZone);

      if (sameZone) {
        for (var p in _getEmptyInZone(grid, targetZone)) {
          if (p[0] != r) {
            grid[p[0]][p[1]] = SolverCell.cross;
            changed = true;
          }
        }
      }
    }

    return changed;
  }

  // ==========================================
  // FONCTIONS UTILITAIRES
  // ==========================================

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
      int nr = r + d[0];
      int nc = c + d[1];
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        if (grid[nr][nc] == SolverCell.empty) {
          grid[nr][nc] = SolverCell.cross;
          changed = true;
        }
      }
    }
    return changed;
  }

  bool _crossOutRow(List<List<SolverCell>> grid, int r) {
    bool changed = false;
    for (int c = 0; c < size; c++) {
      if (grid[r][c] == SolverCell.empty) {
        grid[r][c] = SolverCell.cross;
        changed = true;
      }
    }
    return changed;
  }

  bool _crossOutCol(List<List<SolverCell>> grid, int c) {
    bool changed = false;
    for (int r = 0; r < size; r++) {
      if (grid[r][c] == SolverCell.empty) {
        grid[r][c] = SolverCell.cross;
        changed = true;
      }
    }
    return changed;
  }

  bool _crossOutZone(List<List<SolverCell>> grid, int z) {
    bool changed = false;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (zones[r][c] == z && grid[r][c] == SolverCell.empty) {
          grid[r][c] = SolverCell.cross;
          changed = true;
        }
      }
    }
    return changed;
  }

  int _countTotalStars(List<List<SolverCell>> grid) {
    int count = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == SolverCell.star) count++;
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
        if (zones[r][c] == z && grid[r][c] == SolverCell.empty)
          list.add([r, c]);
      }
    }
    return list;
  }
}
