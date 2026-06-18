import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../ data/models/repositories/dashboard_repository.dart';
import '../ data/models/tournament_model.dart';
import '../../login/presentation/login_screen.dart';
import '../../tournament_detail/presentation/tournament_detail_screen.dart';
import 'widgets/tournament_card_widget.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final String email;

  const DashboardScreen({
    Key? key,
    required this.userId,
    this.displayName = '',
    this.email = '',
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepository();
  List<TournamentModel> _tournaments = [];
  bool _loading = true;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    final tournaments = await _repo.getUserTournaments(widget.userId);
    if (mounted) {
      setState(() {
        _tournaments = tournaments;
        _loading = false;
      });
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout from this TV?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF050A18),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00A3FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Row(
        children: [
          _buildSideNav(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 40, left: 40, right: 40, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),

                  // Ad placeholder space — replaces the old live match hero section
                  Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: const Center(
                      child: Text(
                        'Ad space',
                        style: TextStyle(color: Colors.white24, fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('My Tournaments'),
                          const SizedBox(height: 16),
                          _tournaments.isEmpty
                              ? _buildEmpty()
                              : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: _tournaments.length,
                            itemBuilder: (context, index) {
                              final t = _tournaments[index];
                              return TournamentCardWidget(
                                tournament: t,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TournamentDetailScreen(
                                      tournamentId: t.id,
                                      tournament: t,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF00A3FF), Color(0xFF0066CC)]),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A3FF).withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              )
            ],
          ),
          child: Center(
            child: Text(
              widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back,',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
            Text(
              widget.displayName.isNotEmpty ? widget.displayName : 'Player',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Spacer(),
        _chip(Icons.emoji_events, '${_tournaments.length} Tournaments', const Color(0xFF00A3FF)),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.emoji_events, color: Colors.white.withOpacity(0.1), size: 70),
            const SizedBox(height: 16),
            const Text('No tournaments yet', style: TextStyle(color: Colors.white38, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Create a tournament in the CRICTRAX mobile app',
                style: TextStyle(color: Colors.white24, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold));
  }

  Widget _buildSideNav() {
    final navItems = [
      Icons.home_outlined,
      Icons.emoji_events,
      Icons.play_circle_outline,
      Icons.settings_outlined,
    ];

    return Container(
      width: 90,
      color: Colors.white.withOpacity(0.02),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(navItems.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Focus(
                child: Builder(builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedNavIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isFocused || _selectedNavIndex == index
                            ? const Color(0xFF00A3FF)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(navItems[index],
                          color: isFocused || _selectedNavIndex == index ? Colors.white : Colors.white38,
                          size: 28),
                    ),
                  );
                }),
              ),
            );
          }),
          const SizedBox(height: 20),
          Focus(
            child: Builder(builder: (context) {
              final isFocused = Focus.of(context).hasFocus;
              return GestureDetector(
                onTap: () => _showLogoutDialog(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isFocused ? Colors.redAccent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout, color: isFocused ? Colors.white : Colors.white30, size: 28),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}