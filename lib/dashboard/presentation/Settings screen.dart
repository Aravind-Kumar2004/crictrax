import 'dart:ui';
import 'package:flutter/material.dart';

// ─── Settings Screen (Dummy) ───────────────────────────────────────────────
// Matches the CRICTRAX dashboard's dark "stadium" design language:
// same palette, same gradients, same card/nav styling. Static/dummy content
// only — no real persistence or business logic wired up yet.

class _DS {
  static const bg = Color(0xFF050A18);
  static const surface = Color(0xFF0A1628);
  static const surfaceHigh = Color(0xFF0F1E35);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live = Color(0xFFFF6B35);
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFFB300);
  static const danger = Color(0xFFFF3D3D);

  static const accentGrad = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SettingsScreen extends StatefulWidget {
  final int initialNavIndex;

  const SettingsScreen({Key? key, this.initialNavIndex = 3}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Dummy toggle state — not persisted anywhere yet.
  bool _notificationsEnabled = true;
  bool _soundEffects = true;
  bool _backgroundMusic = true;
  bool _autoUpdateScores = true;
  bool _highContrastMode = false;
  String _selectedQuality = 'Auto';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: Stack(
        children: [
          // Ambient glows to match dashboard atmosphere
          Positioned(
            top: -120,
            left: 60,
            child: _AmbientGlow(color: _DS.accent, size: 380),
          ),
          Positioned(
            bottom: -100,
            right: 80,
            child: _AmbientGlow(color: const Color(0xFF6C3AFF), size: 300),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Playback', Icons.play_circle_outline_rounded),
                          const SizedBox(height: 14),
                          _SettingsCard(
                            children: [
                              _SwitchRow(
                                icon: Icons.volume_up_rounded,
                                title: 'Sound Effects',
                                subtitle: 'UI taps, alerts, and score chimes',
                                value: _soundEffects,
                                onChanged: (v) => setState(() => _soundEffects = v),
                              ),
                              const _RowDivider(),
                              _SwitchRow(
                                icon: Icons.music_note_rounded,
                                title: 'Background Music',
                                subtitle: 'Ambient stadium soundtrack',
                                value: _backgroundMusic,
                                onChanged: (v) => setState(() => _backgroundMusic = v),
                              ),
                              const _RowDivider(),
                              _SwitchRow(
                                icon: Icons.sync_rounded,
                                title: 'Auto-Update Live Scores',
                                subtitle: 'Refresh scores automatically during matches',
                                value: _autoUpdateScores,
                                onChanged: (v) => setState(() => _autoUpdateScores = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _buildSectionHeader('Display', Icons.tv_rounded),
                          const SizedBox(height: 14),
                          _SettingsCard(
                            children: [
                              _SwitchRow(
                                icon: Icons.contrast_rounded,
                                title: 'High Contrast Mode',
                                subtitle: 'Improves visibility on some TV panels',
                                value: _highContrastMode,
                                onChanged: (v) => setState(() => _highContrastMode = v),
                              ),
                              const _RowDivider(),
                              _SelectRow(
                                icon: Icons.high_quality_rounded,
                                title: 'Video Quality',
                                subtitle: 'Applies to match highlight playback',
                                value: _selectedQuality,
                                options: const ['Auto', '1080p', '720p', '480p'],
                                onChanged: (v) => setState(() => _selectedQuality = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _buildSectionHeader('Notifications', Icons.notifications_none_rounded),
                          const SizedBox(height: 14),
                          _SettingsCard(
                            children: [
                              _SwitchRow(
                                icon: Icons.notifications_active_rounded,
                                title: 'Push Notifications',
                                subtitle: 'Get notified when your tournaments go live',
                                value: _notificationsEnabled,
                                onChanged: (v) =>
                                    setState(() => _notificationsEnabled = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _buildSectionHeader('About', Icons.info_outline_rounded),
                          const SizedBox(height: 14),
                          _SettingsCard(
                            children: [
                              _InfoRow(
                                icon: Icons.sports_cricket_rounded,
                                title: 'CRICTRAX TV',
                                subtitle: 'Version 1.0.0 (dummy build)',
                              ),
                              const _RowDivider(),
                              _InfoRow(
                                icon: Icons.description_outlined,
                                title: 'Terms & Privacy',
                                subtitle: 'View legal information',
                                showChevron: true,
                              ),
                            ],
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        _BackButton(onTap: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PREFERENCES',
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
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _DS.accent.withOpacity(0.7), size: 16),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
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
                colors: [_DS.accent.withOpacity(0.25), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Card Container ─────────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) {
    return Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60);
  }
}

// ─── Switch Row ──────────────────────────────────────────────────────────────
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            _IconBadge(icon: icon, active: value),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: _DS.accent,
              activeTrackColor: _DS.accent.withOpacity(0.25),
              inactiveThumbColor: Colors.white.withOpacity(0.6),
              inactiveTrackColor: Colors.white.withOpacity(0.08),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Select Row (simple dropdown-style dummy control) ────────────────────────
class _SelectRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _SelectRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _IconBadge(icon: icon, active: false),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            initialValue: value,
            color: _DS.surfaceHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            onSelected: onChanged,
            itemBuilder: (context) => options
                .map(
                  (o) => PopupMenuItem<String>(
                value: o,
                child: Text(
                  o,
                  style: TextStyle(
                    color: o == value ? _DS.accent : Colors.white.withOpacity(0.8),
                    fontWeight: o == value ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            )
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _DS.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _DS.accent.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: _DS.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down_rounded, color: _DS.accent, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showChevron;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _IconBadge(icon: icon, active: false),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron)
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
        ],
      ),
    );
  }
}

// ─── Icon Badge ───────────────────────────────────────────────────────────────
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _IconBadge({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? _DS.accent : Colors.white.withOpacity(0.6);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: (active ? _DS.accent : Colors.white).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (active ? _DS.accent : Colors.white).withOpacity(0.18),
        ),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// ─── Back Button ──────────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _DS.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ─── Ambient Glow ─────────────────────────────────────────────────────────────
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