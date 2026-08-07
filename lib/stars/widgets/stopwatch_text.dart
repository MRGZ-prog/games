import 'dart:async';
import 'package:flutter/material.dart';

class StopwatchText extends StatefulWidget {
  final Stopwatch stopwatch;

  const StopwatchText({super.key, required this.stopwatch});

  @override
  State<StopwatchText> createState() => _StopwatchTextState();
}

class _StopwatchTextState extends State<StopwatchText> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (widget.stopwatch.isRunning && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.stopwatch.elapsed;
    final ms = duration.inMilliseconds % 60000;
    final bool isNearMinute = ms < 2000 || ms > 58000;

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String? hours = duration.inHours >= 1
        ? twoDigits(duration.inHours % 60)
        : null;
    String minutes = twoDigits(duration.inMinutes % 60);
    String seconds = twoDigits(duration.inSeconds % 60);

    final formattedText = hours == null
        ? "$minutes:$seconds"
        : "$hours:$minutes:$seconds";

    return Text(
      formattedText,
      style: TextStyle(
        fontSize: 16,
        fontWeight: isNearMinute ? FontWeight.bold : null,
        color: isNearMinute ? Colors.red : null,
      ),
    );
  }
}
