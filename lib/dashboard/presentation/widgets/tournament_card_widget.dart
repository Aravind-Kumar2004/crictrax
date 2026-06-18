import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../dashboard/domain/entities/tournament_entity.dart';

class TournamentCardWidget extends StatelessWidget {
  final TournamentEntity tournament;
  final VoidCallback onTap;

  const TournamentCardWidget({
    Key? key,
    required this.tournament,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = tournament.status == 'Active'
        ? Colors.greenAccent
        : tournament.status == 'Upcoming'
        ? const Color(0xFF00A3FF)
        : Colors.white38;

    return Focus(
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            transform:
            Matrix4.identity()..scale(isFocused ? 1.04 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isFocused
                    ? const Color(0xFF00A3FF)
                    : Colors.white.withOpacity(0.08),
                width: isFocused ? 2 : 1,
              ),
              boxShadow: isFocused
                  ? [
                BoxShadow(
                  color: const Color(0xFF00A3FF)
                      .withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                )
              ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter:
                ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white.withOpacity(0.04),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                          statusColor.withOpacity(0.12),
                          borderRadius:
                          BorderRadius.circular(8),
                          border: Border.all(
                              color: statusColor
                                  .withOpacity(0.3)),
                        ),
                        child: Text(tournament.status,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight:
                                FontWeight.bold)),
                      ),
                      Text(
                        tournament.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.location_on,
                                color: Colors.white38,
                                size: 13),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(tournament.ground,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12),
                                  overflow:
                                  TextOverflow.ellipsis),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(
                                Icons.format_list_bulleted,
                                color: Colors.white38,
                                size: 13),
                            const SizedBox(width: 4),
                            Text(tournament.format,
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12)),
                          ]),
                          if (tournament.endDate != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white38,
                                  size: 13),
                              const SizedBox(width: 4),
                              Text(
                                'Ends ${tournament.endDate!.day}/${tournament.endDate!.month}/${tournament.endDate!.year}',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12),
                              ),
                            ]),
                          ],
                        ],
                      ),
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