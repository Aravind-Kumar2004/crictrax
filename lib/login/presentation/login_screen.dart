import 'package:flutter/material.dart';
import ' widgets/tv_qr_section.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/repositories/auth_repository.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: const Center(
        child: TvQrSection(),
      ),
    );
  }
}

class _TvTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool isObscure;
  final TextEditingController controller;

  const _TvTextField({
    required this.hint,
    required this.icon,
    required this.controller,
    this.isObscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Center(
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sports_cricket,
                size: 70,
                color: Color(0xFF00A3FF),
              ),
              const SizedBox(height: 20),
              const Text(
                'CRICTRAX TV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scan the QR code using the mobile app',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 40),
              const TvQrSection(),
            ],
          ),
        ),
      ),
    );
  }
}