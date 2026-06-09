import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Padding(
        // TVs have physical bezels that can cut off the edges (Overscan).
        // Always use generous padding!
        padding: const EdgeInsets.all(56.0),
        child: Row(
          children: [
            // Left Side: The QR Code Login
            Expanded(
              flex: 1,
              child: _buildQrSection(),
            ),

            // Middle Divider
            Container(
              width: 2,
              height: 400,
              color: Colors.white.withOpacity(0.1),
            ),

            // Right Side: Manual Login Form
            // FIXED: Passing context here so the navigator works
            Expanded(
              flex: 1,
              child: _buildFormSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Quick Login",
          style: TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Scan the QR code with your mobile camera\nor the CRICTRAX app to log in instantly.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 18,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
        // The QR Code Container
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
          child: const Icon(
            Icons.qr_code_2,
            size: 220,
            color: Colors.black,
          ), // Note: Later you can replace this Icon with the qr_flutter package
        ),
      ],
    );
  }

  // FIXED: Added BuildContext parameter so Navigator can use it
  Widget _buildFormSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 80.0, right: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Or Login Manually",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),

          // Custom TV Text Field: Email
          _buildTvTextField(
            hint: "Email or Mobile Number",
            icon: Icons.person_outline,
            isObscure: false,
          ),
          const SizedBox(height: 24),

          // Custom TV Text Field: Password
          _buildTvTextField(
            hint: "Password",
            icon: Icons.lock_outline,
            isObscure: true,
          ),
          const SizedBox(height: 40),

          // Custom TV Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              },
              style: ButtonStyle(
                // The button changes to Energy Blue when focused via D-pad
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.focused)) {
                    return const Color(0xFF00A3FF);
                  }
                  return Colors.white.withOpacity(0.1);
                }),
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 24)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              child: const Text(
                "LOGIN",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTvTextField({required String hint, required IconData icon, required bool isObscure}) {
    return TextField(
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white, fontSize: 20),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),

        // This is crucial for TV: The thick blue border appears ONLY when focused
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00A3FF), width: 3),
        ),

        // The default unfocused state
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),

        prefixIcon: Icon(icon, color: Colors.white54, size: 28),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      ),
    );
  }
}