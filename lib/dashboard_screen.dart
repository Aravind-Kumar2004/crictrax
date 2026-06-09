import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_match_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<Map<String, String>> tournaments = [
    {"title": "ICC T20 World Cup", "status": "Live", "teams": "20 Teams"},
    {"title": "Indian Premier League", "status": "Upcoming", "teams": "10 Teams"},
    {"title": "The Ashes", "status": "Completed", "teams": "AUS vs ENG"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Row(
        children: [
          // LEFT SIDE NAVIGATION RAIL
          _buildSideNav(),

          // MAIN CONTENT AREA
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 0, right: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // The Live Matches Section
                  const Text(
                    "Live Now",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // FIXED: Removed the 'const' from the children array list
                  SizedBox(
                    height: 200,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [  // <-- Removed 'const' from the array list
                        const GlassMatchCard(
                          matchTitle: "IND vs AUS - Final",
                          score: "IND 245/3 (20.0)",
                        ),
                        const SizedBox(width: 24),
                        const GlassMatchCard(
                          matchTitle: "ENG vs NZ - Semi Final",
                          score: "ENG 180/8 (19.4)",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48), // Space between sections
                  // -----------------------------------------------------------

                  const Text(
                    "Tournaments",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Horizontal Scrolling Tournament List
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tournaments.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 24),
                          child: _buildTournamentCard(tournaments[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Side Navigation ---
  Widget _buildSideNav() {
    return Container(
      width: 100,
      color: Colors.white.withOpacity(0.02),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavIcon(Icons.home_outlined, false),
          const SizedBox(height: 40),
          _buildNavIcon(Icons.emoji_events, true), // Tournaments active
          const SizedBox(height: 40),
          _buildNavIcon(Icons.play_circle_outline, false),
          const SizedBox(height: 40),
          _buildNavIcon(Icons.settings_outlined, false),
        ],
      ),
    );
  }

  // --- WIDGET: Focusable Nav Icon ---
  Widget _buildNavIcon(IconData icon, bool isActive) {
    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isFocused
                  ? const Color(0xFF00A3FF)
                  : (isActive ? Colors.white.withOpacity(0.1) : Colors.transparent),
              shape: BoxShape.circle,
              boxShadow: isFocused
                  ? [
                BoxShadow(
                  color: const Color(0xFF00A3FF).withOpacity(0.6),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isFocused || isActive ? Colors.white : Colors.white54,
              size: 32,
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET: Focusable 3D Glass Tournament Card ---
  Widget _buildTournamentCard(Map<String, String> data) {
    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: 340,
            transform: Matrix4.identity()..scale(isFocused ? 1.05 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isFocused ? Colors.white : Colors.white.withOpacity(0.1),
                width: isFocused ? 3 : 1,
              ),
              boxShadow: isFocused
                  ? [
                BoxShadow(
                  color: const Color(0xFF00A3FF).withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white.withOpacity(0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: data["status"] == "Live"
                              ? Colors.redAccent.withOpacity(0.8)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data["status"]!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data["title"]!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data["teams"]!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}