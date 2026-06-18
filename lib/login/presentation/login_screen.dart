import 'package:crictrax/login/presentation/widgets/tv_qr_section.dart';
import 'package:flutter/material.dart';

import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/repositories/auth_repository.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Padding(
        padding: const EdgeInsets.all(56.0),
        child: Row(
          children: [
            const Expanded(flex: 1, child: TvQrSection()),
            Container(
              width: 2,
              height: 400,
              color: Colors.white.withOpacity(0.1),
            ),
            Expanded(
              flex: 1,
              child: _ManualLoginForm(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualLoginForm extends StatefulWidget {
  @override
  State<_ManualLoginForm> createState() =>
      _ManualLoginFormState();
}

class _ManualLoginFormState extends State<_ManualLoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repo = AuthRepository();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _repo.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              userId: user.uid,
              displayName: user.displayName,
              email: user.email,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Login failed. Check your credentials.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 80.0, right: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Or Login Manually',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          _TvTextField(
            hint: 'Email',
            icon: Icons.person_outline,
            controller: _emailController,
          ),
          const SizedBox(height: 24),
          _TvTextField(
            hint: 'Password',
            icon: Icons.lock_outline,
            isObscure: true,
            controller: _passwordController,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 14)),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00A3FF)))
                : ElevatedButton(
              onPressed: _login,
              style: ButtonStyle(
                backgroundColor:
                WidgetStateProperty.resolveWith<Color>(
                        (states) {
                      if (states.contains(WidgetState.focused)) {
                        return const Color(0xFF00A3FF);
                      }
                      return Colors.white.withOpacity(0.1);
                    }),
                padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 24)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              child: const Text('LOGIN',
                  style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white, fontSize: 20),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFF00A3FF), width: 3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        prefixIcon:
        Icon(icon, color: Colors.white54, size: 28),
        hintText: hint,
        hintStyle: const TextStyle(
            color: Colors.white38, fontSize: 20),
        contentPadding: const EdgeInsets.symmetric(
            vertical: 24, horizontal: 20),
      ),
    );
  }
}