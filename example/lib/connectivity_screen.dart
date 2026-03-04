import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:rx_connectivity_checker_example/ui/theme/app_theme.dart';
import 'package:rx_connectivity_checker_example/ui/widgets/connectivity_halo.dart';
import 'package:rx_connectivity_checker_example/ui/widgets/telemetry_card.dart';

class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({super.key});

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  // Checker is created inside initState — after WidgetsFlutterBinding is ready
  // and the platform channel (including the Windows COM channel) is registered.
  // Creating it at file scope or in a field initializer risks losing the first
  // events because the platform isn't ready yet.
  late final ConnectivityChecker _checker;
  StreamSubscription<ConnectivityStatus>? _sub;

  ConnectivityStatus _status = ConnectivityStatus.unknown;
  int? _latencyMs;
  DateTime? _lastEventTime;
  bool _latencyLoading = false;

  final List<({ConnectivityStatus status, DateTime time})> _log = [];

  Color get _blobColor => switch (_status) {
        ConnectivityStatus.online => AppTheme.onlineGlow,
        ConnectivityStatus.slow => AppTheme.slowGlow,
        ConnectivityStatus.offline => AppTheme.offlineGlow,
        ConnectivityStatus.unknown => AppTheme.unknownGlow,
      };

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              width: w * 0.65,
              height: w * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _blobColor.withValues(alpha: (0.18)),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              width: w * 0.5,
              height: w * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _blobColor.withValues(alpha: (0.10)),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(28, 28, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RX-CONNECT',
                            style: TextStyle(
                              fontFamily: AppTheme.fontMono,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: 4,
                            )),
                        SizedBox(height: 4),
                        Text('NETWORK DIAGNOSTICS',
                            style: TextStyle(
                              fontFamily: AppTheme.fontMono,
                              fontSize: 10,
                              letterSpacing: 3,
                              color: AppTheme.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 44),
                    child: Center(child: ConnectivityHalo(status: _status)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: TelemetryCard(
                      status: _status,
                      latencyMs: _latencyMs,
                      lastEventTime: _lastEventTime,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10, left: 2),
                          child: Text('REACHABILITY TEST',
                              style: TextStyle(
                                fontFamily: AppTheme.fontMono,
                                fontSize: 9,
                                letterSpacing: 3,
                                color: AppTheme.textSecondary,
                              )),
                        ),
                        _LatencyButton(
                          loading: _latencyLoading,
                          onTap: _runLatencyTest,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: AppTheme.glassCard(borderRadius: 16),
                      padding: const EdgeInsets.all(20),
                      child: _EventLog(log: _log),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checker = ConnectivityChecker(
      checkFrequency: const Duration(seconds: 60),
      checkSlowConnection: true,
      timeout: const Duration(seconds: 3),
    );
    _sub = _checker.connectivityStream.listen((status) {
      setState(() {
        _status = status;
        _lastEventTime = DateTime.now();
        _log.insert(0, (status: status, time: _lastEventTime!));
        if (_log.length > 8) _log.removeLast();
      });
    });
  }

  Future<void> _runLatencyTest() async {
    setState(() => _latencyLoading = true);
    final sw = Stopwatch()..start();
    try {
      await _checker.checkConnectivity();
      sw.stop();
      setState(() => _latencyMs = sw.elapsedMilliseconds);
    } catch (_) {
      setState(() => _latencyMs = -1);
    } finally {
      setState(() => _latencyLoading = false);
    }
  }
}

class _EventLog extends StatelessWidget {
  final List<({ConnectivityStatus status, DateTime time})> log;
  const _EventLog({required this.log});

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) {
      return const Text('Waiting for first event...',
          style: TextStyle(
            fontFamily: AppTheme.fontMono,
            fontSize: 12,
            color: AppTheme.textSecondary,
          ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('EVENT LOG',
          style: TextStyle(
            fontFamily: AppTheme.fontMono,
            fontSize: 9,
            letterSpacing: 3,
            color: AppTheme.textSecondary,
          )),
      const SizedBox(height: 10),
      ...log.asMap().entries.map((e) {
        final isFirst = e.key == 0;
        final entry = e.value;
        final color = _color(entry.status);
        final t = entry.time;
        final ts = '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}:'
            '${t.second.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Text(ts,
                style: const TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1,
                )),
            const SizedBox(width: 12),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: (0.5)), blurRadius: 4)
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(entry.status.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 11,
                  letterSpacing: 2,
                  color: isFirst ? color : AppTheme.textSecondary,
                  fontWeight: isFirst ? FontWeight.w700 : FontWeight.w400,
                )),
          ]),
        );
      }),
    ]);
  }

  Color _color(ConnectivityStatus s) => switch (s) {
        ConnectivityStatus.online => AppTheme.online,
        ConnectivityStatus.slow => AppTheme.slow,
        ConnectivityStatus.offline => AppTheme.offline,
        ConnectivityStatus.unknown => AppTheme.unknown,
      };
}

class _LatencyButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LatencyButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.online.withValues(alpha: (loading ? 0.04 : 0.08)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    AppTheme.online.withValues(alpha: (loading ? 0.15 : 0.35))),
          ),
          child: Row(children: [
            SizedBox(
              width: 20,
              height: 20,
              child: loading
                  ? const CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppTheme.online)
                  : const Icon(Icons.network_ping,
                      color: AppTheme.online, size: 18),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RUN LATENCY TEST',
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 11,
                    letterSpacing: 2,
                    color: loading
                        ? AppTheme.online.withValues(alpha: (0.4))
                        : AppTheme.online,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 2),
              const Text('measures validate round-trip',
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: AppTheme.textSecondary,
                  )),
            ]),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: AppTheme.online.withValues(alpha: (0.4)), size: 16),
          ]),
        ),
      );
}
