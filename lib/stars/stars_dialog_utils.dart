import 'package:flutter/material.dart';

class DialogUtils {
  static void showRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rules'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Place EXACTLY ONE star in every column, row and color zone!'),
            SizedBox(height: 12),
            Text('Stars cannot touch each other, even diagonally.'),
            SizedBox(height: 12),
            Text('Activate Auto ticks to show these rules in action.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void showNewGame(BuildContext context, Function(int) onStart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New game'),
        content: const Text(
          'You will launch a new game. Please select the difficulty.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onStart(1);
            },
            child: const Text('Easy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onStart(2);
            },
            child: const Text('Normal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onStart(3);
            },
            child: const Text('Hard'),
          ),
        ],
      ),
    );
  }

  static void showLoadPuzzle(
    BuildContext context,
    Function(int size, int level, int seed) onLoad,
  ) {
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
                List<String> parts = controller.text.trim().split('-');
                if (parts.length == 3) {
                  onLoad(
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                    int.parse(parts[2]),
                  );
                  Navigator.pop(context);
                }
              } catch (_) {}
            },
            child: const Text("Load"),
          ),
        ],
      ),
    );
  }
}
