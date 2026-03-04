import 'package:flutter/material.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';

import '../theme/app_theme.dart';

/// Central animated orb. Uses a single AnimationController for the
/// pulse — no external animation packages needed.
class ConnectivityHalo extends StatefulWidget {
  final ConnectivityStatus status;
  final double size;
  const ConnectivityHalo({super.key, required this.status, this.size = 200});

  @override
  State<ConnectivityHalo> createState() => _ConnectivityHaloState();
}

class _ConnectivityHaloState extends State<ConnectivityHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  Duration get _pulseDuration => switch (widget.status) {
        ConnectivityStatus.online => const Duration(milliseconds: 1800),
        ConnectivityStatus.slow => const Duration(milliseconds: 2800),
        ConnectivityStatus.offline => const Duration(milliseconds: 900),
        ConnectivityStatus.unknown => const Duration(milliseconds: 2200),
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(widget.status);
    final label = _label(widget.status);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value; // 0.0 → 1.0 → 0.0
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: widget.size * (0.85 + 0.15 * t),
                height: widget.size * (0.85 + 0.15 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: (0.08 + 0.07 * t)),
                ),
              ),
              // Mid ring
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: widget.size * 0.6,
                height: widget.size * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: (0.12)),
                  border: Border.all(
                      color: color.withValues(alpha: (0.25)), width: 1),
                ),
              ),
              // Core orb
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: widget.size * (0.33 + 0.03 * t),
                height: widget.size * (0.33 + 0.03 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: (0.7)),
                        blurRadius: 24 + 12 * t,
                        spreadRadius: 2),
                    BoxShadow(
                        color: color.withValues(alpha: (0.3)),
                        blurRadius: 48 + 16 * t,
                        spreadRadius: 8),
                  ],
                ),
              ),
              // Label
              Positioned(
                bottom: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: TextStyle(
                      fontFamily: AppTheme.fontMono,
                      fontSize: 11,
                      letterSpacing: 4,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(ConnectivityHalo old) {
    super.didUpdateWidget(old);
    // Adjust speed based on status
    if (old.status != widget.status) {
      _pulse.duration = _pulseDuration;
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  Color _color(ConnectivityStatus s) => switch (s) {
        ConnectivityStatus.online => AppTheme.online,
        ConnectivityStatus.slow => AppTheme.slow,
        ConnectivityStatus.offline => AppTheme.offline,
        ConnectivityStatus.unknown => AppTheme.unknown,
      };

  String _label(ConnectivityStatus s) => switch (s) {
        ConnectivityStatus.online => 'ONLINE',
        ConnectivityStatus.slow => 'SLOW',
        ConnectivityStatus.offline => 'OFFLINE',
        ConnectivityStatus.unknown => 'SCANNING',
      };
}
