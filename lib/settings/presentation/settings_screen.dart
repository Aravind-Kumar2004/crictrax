import 'dart:ui';
import 'package:flutter/material.dart';

// ─── Design Tokens (Shared from Dashboard) ────────────────────────────────────
class _DS {
  static const bg = Color(0xFF050A18);
  static const surface = Color(0xFF0A1628);
  static const surfaceHigh = Color(0xFF0F1E35);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live = Color(0xFFFF6B35);
  static const danger = Color(0xFFFF3D3D);

  static const navWidth = 110.0;

  static const accentGrad = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Settings Screen ──────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  final int initialNavIndex;

  const SettingsScreen({
    Key? key,
    this.initialNavIndex = 3, // Assuming 3 is Settings in your nav rail
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedNavIndex = 3;

  // Mock state for toggle switches
  bool _enableSound = true;
  bool _highContrast = false;
  bool _autoConnectBLE = true;

  @override
  void initState() {
    super.initState();
    _selectedNavIndex = widget.initialNavIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: Stack(
        children: [
          // Ambient background glow
          Positioned(
            top: -120,
            left: 60,
            child: _AmbientGlow(color: _DS.accent, size: 400),
          ),
          Positioned(
            bottom: -80,
            right: 100,
            child: _AmbientGlow(color: const Color(0xFF6C3AFF), size: 300),
          ),

          // Main layout
          Row(
            children: [
              // Assuming you extract _SideNavRail into a shared widget.
              // Using a placeholder container here for visual structure.
              Container(
                width: _DS.navWidth,
                decoration: BoxDecoration(
                  color: _DS.surface.withOpacity(0.6),
                  border: Border(
                    right: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                  ),
                ),
                child: Center(
                  child: Icon(Icons.settings_rounded, color: _DS.accent, size: 32),
                ),
              ),

              // Settings Content
              Expanded(child: _buildMainContent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 36, left: 40, right: 48, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 36),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Preferences'),
                  const SizedBox(height: 16),
                  _SettingsTile(
                    icon: Icons.volume_up_rounded,
                    title: 'UI Sound Effects',
                    subtitle: 'Play subtle sounds on D-pad navigation',
                    trailing: _buildToggle(_enableSound),
                    onTap: () => setState(() => _enableSound = !_enableSound),
                  ),
                  _SettingsTile(
                    icon: Icons.contrast_rounded,
                    title: 'High Contrast Mode',
                    subtitle: 'Increase border opacity for better visibility',
                    trailing: _buildToggle(_highContrast),
                    onTap: () => setState(() => _highContrast = !_highContrast),
                  ),

                  const SizedBox(height: 40),

                  _buildSectionHeader('Hardware Integration'),
                  const SizedBox(height: 16),
                  _SettingsTile(
                    icon: Icons.bluetooth_connected_rounded,
                    title: 'BLE Scoreboard Sync',
                    subtitle: 'Automatically connect to paired peripheral devices',
                    trailing: _buildToggle(_autoConnectBLE),
                    onTap: () => setState(() => _autoConnectBLE = !_autoConnectBLE),
                  ),
                  _SettingsTile(
                    icon: Icons.memory_rounded,
                    title: 'Manage External Sensors',
                    subtitle: 'Configure UUIDs and characteristics for hardware',
                    trailing: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.4)),
                    onTap: () {
                      // Navigate to deep hardware config
                    },
                  ),

                  const SizedBox(height: 40),

                  _buildSectionHeader('Account & App'),
                  const SizedBox(height: 16),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About CRICTRAX TV',
                    subtitle: 'Version 1.0.4 (Build 42)',
                    trailing: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.4)),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Clear Local Cache',
                    subtitle: 'Free up space by removing cached tournament images',
                    trailing: const SizedBox.shrink(),
                    isDanger: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 40),
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SYSTEM CONFIGURATION',
              style: TextStyle(
                color: _DS.accent.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: 44,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive ? _DS.accent : Colors.white.withOpacity(0.1),
        border: Border.all(
          color: isActive ? _DS.accent : Colors.white.withOpacity(0.2),
        ),
        boxShadow: isActive
            ? [BoxShadow(color: _DS.accent.withOpacity(0.4), blurRadius: 8)]
            : [],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: isActive ? 20 : 2,
            top: 2,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settings Tile (TV D-Pad Optimized) ───────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final bool isDanger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Focus(
        child: Builder(
          builder: (ctx) {
            final focused = Focus.of(ctx).hasFocus;
            final baseColor = isDanger ? _DS.danger : _DS.accent;

            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: focused
                      ? baseColor.withOpacity(0.08)
                      : _DS.surfaceHigh.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: focused
                        ? baseColor.withOpacity(0.5)
                        : Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                  boxShadow: focused
                      ? [
                    BoxShadow(
                      color: baseColor.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 0,
                    )
                  ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: focused ? baseColor.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: focused ? baseColor : Colors.white.withOpacity(0.4),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: focused ? Colors.white : Colors.white.withOpacity(0.8),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    trailing,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Ambient Glow (Shared) ────────────────────────────────────────────────────
class _AmbientGlow extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.07),
            color.withOpacity(0.03),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}