import 'package:flutter/material.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:universal_platform/universal_platform.dart';

import '../theme/app_theme.dart';

class TelemetryCard extends StatelessWidget {
  static const _labelStyle = TextStyle(
    fontFamily: AppTheme.fontMono,
    fontSize: 9,
    letterSpacing: 3,
    color: AppTheme.textSecondary,
  );

  final ConnectivityStatus status;
  final int? latencyMs;
  final DateTime? lastEventTime;

  const TelemetryCard({
    super.key,
    required this.status,
    required this.latencyMs,
    required this.lastEventTime,
  });

  String get _latencyLabel => switch (latencyMs) {
        null => '—  (tap test below)',
        -1 => 'TIMEOUT / UNREACHABLE',
        _ => '$latencyMs ms',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Text('NETWORK TELEMETRY', style: _labelStyle),
            const Spacer(),
            _LiveDot(active: status != ConnectivityStatus.unknown),
          ]),
          const SizedBox(height: 20),

          // Platform badge
          _PlatformBadge(),
          const SizedBox(height: 20),

          const Divider(color: AppTheme.glassBorder, height: 1),
          const SizedBox(height: 16),

          _Row('STATUS', status.name.toUpperCase(), _statusColor(status)),
          const SizedBox(height: 12),
          _Row('VALIDATOR', 'google.com/generate_204'),
          const SizedBox(height: 12),
          _Row('LATENCY', _latencyLabel, _latencyColor(latencyMs)),
          const SizedBox(height: 12),
          _Row(
              'LAST EVENT', lastEventTime != null ? _fmt(lastEventTime!) : '—'),
          const SizedBox(height: 12),
          _Row(
              'CHANNEL',
              UniversalPlatform.isWindows
                  ? 'NLM  (INetworkListManagerEvents)'
                  : 'connectivity (native)'),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  static Color? _latencyColor(int? ms) {
    if (ms == null) return null;
    if (ms < 0) return AppTheme.offline;
    if (ms < 150) return AppTheme.online;
    if (ms < 500) return AppTheme.slow;
    return AppTheme.offline;
  }

  static Color? _statusColor(ConnectivityStatus s) => switch (s) {
        ConnectivityStatus.online => AppTheme.online,
        ConnectivityStatus.slow => AppTheme.slow,
        ConnectivityStatus.offline => AppTheme.offline,
        ConnectivityStatus.unknown => null,
      };
}

class _LiveDot extends StatefulWidget {
  final bool active;
  const _LiveDot({required this.active});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppTheme.online : AppTheme.unknown;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('LIVE',
          style: TextStyle(
            fontFamily: AppTheme.fontMono,
            fontSize: 9,
            letterSpacing: 2,
            color: widget.active ? AppTheme.online : AppTheme.textSecondary,
          )),
      const SizedBox(width: 5),
      AnimatedBuilder(
        animation: _blink,
        builder: (_, __) => Opacity(
          opacity: 0.3 + 0.7 * _blink.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: widget.active
                  ? [BoxShadow(color: AppTheme.onlineGlow, blurRadius: 6)]
                  : null,
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }
}

class _PlatformBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (true) {
      _ when UniversalPlatform.isWindows => (
          'WINDOWS  ·  COM / NLM',
          Icons.computer,
          AppTheme.textMono
        ),
      _ when UniversalPlatform.isAndroid => (
          'ANDROID  ·  NATIVE',
          Icons.phone_android,
          const Color(0xFF78C257)
        ),
      _ when UniversalPlatform.isIOS => (
          'iOS  ·  NATIVE',
          Icons.phone_iphone,
          const Color(0xFF8EBBFF)
        ),
      _ when UniversalPlatform.isMacOS => (
          'macOS  ·  NATIVE',
          Icons.laptop_mac,
          const Color(0xFFB0C4DE)
        ),
      _ => ('WEB / LINUX  ·  NATIVE', Icons.language, AppTheme.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
              fontFamily: AppTheme.fontMono,
              fontSize: 10,
              letterSpacing: 1.8,
              color: color,
              fontWeight: FontWeight.w700,
            )),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? highlight;
  const _Row(this.label, this.value, [this.highlight]);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 9,
                  letterSpacing: 2,
                  color: AppTheme.textSecondary,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(value,
                  key: ValueKey(value),
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 12,
                    color: highlight ?? AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
        ],
      );
}
