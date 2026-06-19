import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../ data/models/repositories/dashboard_repository.dart';
import '../ data/models/tournament_model.dart';
import '../../login/presentation/login_screen.dart';
import '../../tournament_detail/presentation/tournament_detail_screen.dart';
import 'widgets/tournament_card_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
final String userId;
  final String displayName;
  final String email;
  final String? sessionId;

  const DashboardScreen({
    Key? key,
    required this.userId,
    this.displayName = '',
    this.email = '',
    this.sessionId,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
 final _repo = DashboardRepository();
  List<TournamentModel> _tournaments = [];
  bool _loading = true;
  int _selectedNavIndex = 0;
  StreamSubscription? _logoutSub;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
    _listenForLogout();
  }

 void _listenForLogout() {
    if (widget.sessionId == null) {
      debugPrint('⚠️ DashboardScreen: no sessionId provided — TV forced-logout listener not attached');
      return;
    }
    debugPrint('👂 DashboardScreen: listening for logout on tv_sessions/${widget.sessionId}');
    _logoutSub = FirebaseFirestore.instance
        .collection('tv_sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['loggedOut'] == true && mounted) {
        debugPrint('🚪 DashboardScreen: loggedOut flag detected, showing forced logout modal');
        _logoutSub?.cancel();
        _showForcedLogoutModal();
      }
    }, onError: (e) {
      debugPrint('❌ DashboardScreen: logout listener error: $e');
    });
  }
 void _showForcedLogoutModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 48),
              ),
              const SizedBox(height: 28),
              const Text(
                'You have been Logged out',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Go back and Login to continue.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFF00A3FF),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _logoutSub?.cancel();
    super.dispose();
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