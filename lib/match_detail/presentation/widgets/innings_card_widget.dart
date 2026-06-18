import 'dart:ui';
import 'package:flutter/material.dart';

class InningsCardWidget extends StatelessWidget {
  final Map<String, dynamic> innData;
  final int inningsNumber;

  const InningsCardWidget({
    Key? key,
    required this.innData,
    required this.inningsNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final battingTeamId =
        innData['battingTeamId'] ?? 'Innings $inningsNumber';
    final isSecond =
        innData['isSecondInnings'] ?? false;
    final targetRuns = innData['targetRuns'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Innings $inningsNumber',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 13)),
              Text(battingTeamId,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (isSecond && targetRuns != null)
                Text('Target: $targetRuns',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}