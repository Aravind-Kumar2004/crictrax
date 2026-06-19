import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';

class TvQrSection extends StatefulWidget {
  const TvQrSection({Key? key}) : super(key: key);

  @override
  State<TvQrSection> createState() => _TvQrSectionState();
}

class _TvQrSectionState extends State<TvQrSection> {
  String? _sessionId;
  String? _qrData;
  bool _expired = false;
  bool _linking = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  Future<void> _createSession() async {
    setState(() {
      _expired = false;
      _sessionId = null;
      _qrData = null;
      _linking = false;
    });

    final sessionId = const Uuid().v4();
    final expiresAt =
    DateTime.now().add(const Duration(minutes: 5));

    await FirebaseFirestore.instance
        .collection('tv_sessions')
        .doc(sessionId)
        .set({
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'userId': null,
      'displayName': null,
      'email': null,
    });

    setState(() {
      _sessionId = sessionId;
      _qrData = 'crictrax://link-tv?session=$sessionId';
    });

    _listenForLink(sessionId);

    Future.delayed(const Duration(minutes: 5), () {
      if (mounted && _sessionId == sessionId && !_linking) {
        setState(() => _expired = true);
        _sub?.cancel();
      }
    });
  }

  void _listenForLink(String sessionId) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('tv_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] == 'linked' && mounted) {
        _sub?.cancel();
        final userId = data['userId'] as String;
        final displayName = data['displayName'] as String? ?? '';
        final email = data['email'] as String? ?? '';

        setState(() => _linking = true);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration:
                const Duration(milliseconds: 800),
              pageBuilder: (_, __, ___) => DashboardScreen(
  userId: userId,
  displayName: displayName,
  email: email,
  sessionId: sessionId,
),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_linking) {
      return Column(
        key: const ValueKey('linking'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: Color(0xFF00A3FF), strokeWidth: 3),
          const SizedBox(height: 32),
          const Text('Account Linked!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Loading your dashboard...',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 18)),
        ],
      );
    }

    if (_expired) {
      return Column(
        key: const ValueKey('expired'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code,
              color: Colors.white38, size: 80),
          const SizedBox(height: 24),
          const Text('QR Expired',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _createSession,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A3FF)),
            child: const Text('Regenerate QR'),
          ),
        ],
      );
    }

    if (_qrData == null) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(color: Color(0xFF00A3FF)),
      );
    }

    return Column(
      key: const ValueKey('qr'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Quick Login',
            style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text(
          'Scan the QR code with your CRICTRAX mobile app.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white54, fontSize: 18, height: 1.5),
        ),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: QrImageView(
            data: _qrData!,
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text('Expires in 5 minutes',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13)),
      ],
    );
  }
}