import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../tournament_detail/domain/entities/match_entity.dart';

class MatchCardWidget extends StatelessWidget {
  final TournamentMatchEntity match;
  final VoidCallback onTap;

  const MatchCardWidget({
    Key? key,
    required this.match,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLive = match.isLive;
    final isCompleted = match.isCompleted;

    return Focus(
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 16),
            transform:
            Matrix4.identity()..scale(isFocused ? 1.02 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLive
                    ? Colors.redAccent
                    .withOpacity(isFocused ? 1.0 : 0.5)
                    : isFocused
                    ? const Color(0xFF00A3FF)
                    : Colors.white.withOpacity(0.1),
                width: isFocused ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter:
                ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: isLive
                      ? Colors.redAccent.withOpacity(0.05)
                      : Colors.white.withOpacity(0.03),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLive
                              ? Colors.redAccent
                              : isCompleted
                              ? Colors.white
                              .withOpacity(0.15)
                              : const Color(0xFF00A3FF)
                              .withOpacity(0.2),
                          borderRadius:
                          BorderRadius.circular(8),
                        ),
                        child: Text(
                          isLive
                              ? 'LIVE'
                              : isCompleted
                              ? 'DONE'
                              : 'UPCOMING',
                          style: TextStyle(
                            color: isLive
                                ? Colors.white
                                : isCompleted
                                ? Colors.white54
                                : const Color(0xFF00A3FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${match.teamId1Name}  vs  ${match.teamId2Name}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('${match.overs} overs',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white38, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}