import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../controllers/auth_controller.dart';
import '../services/journey_service.dart';
import '../models/journey.dart';
import 'travel_flow_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.loadJourneys});

  final Future<List<Journey>> Function(int userId)? loadJourneys;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Journey> _journeys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  Future<void> _loadJourneys() async {
    final auth = ref.read(authProvider);
    if (auth.user == null || auth.user!.isGuest) {
      setState(() => _loading = false);
      return;
    }
    try {
      final journeys =
          await (widget.loadJourneys ?? JourneyService.getUserJourneys)(
        auth.user!.id,
      );
      if (!mounted) return;
      setState(() {
        _journeys = journeys;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isRestricted = auth.user == null || auth.user!.isGuest;

    if (isRestricted) {
      return Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in to view your journey history',
                  style: GoogleFonts.dmSans(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Summary
    final totalKm = _journeys.fold(0.0, (sum, j) => sum + j.distance);
    final totalViolations = _journeys.fold(
      0,
      (sum, j) => sum + j.violationCount,
    );
    final avgScore = _journeys.isEmpty
        ? 100
        : (_journeys.fold(0, (sum, j) => sum + j.score) / _journeys.length)
            .round();

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _journeys.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history,
                    size: 48,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No journeys yet',
                    style: GoogleFonts.dmSans(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TravelFlowScreen(),
                      ),
                    ),
                    child: const Text('Start Your First Journey'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryItem(
                          '${totalKm.toStringAsFixed(1)} km',
                          'Total',
                        ),
                        _summaryItem('$totalViolations', 'Violations'),
                        _summaryItem('$avgScore', 'Avg Score'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ..._journeys.map((j) => _journeyCard(j)),
              ],
            ),
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _journeyCard(Journey j) {
    final modeIcons = {'car': '🚗', 'bus': '🚌', 'lorry': '🚚', 'bike': '🏍️'};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              modeIcons[j.mode] ?? '🚗',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(j.startTime),
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${j.distance.toStringAsFixed(1)} km · Max ${j.maxSpeed.toStringAsFixed(0)} km/h',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (j.violationCount > 0)
                    Text(
                      '${j.violationCount} violations',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.destructive,
                      ),
                    ),
                  if (!j.isSynced)
                    Text(
                      'Saved on this device · waiting to sync',
                      key: const Key('history-pending-sync'),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.warning,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: j.score >= 80
                    ? AppTheme.success
                    : (j.score >= 50 ? AppTheme.warning : AppTheme.destructive),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${j.score}',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? 'Journey'
        : '${parsed.year.toString().padLeft(4, '0')}-'
            '${parsed.month.toString().padLeft(2, '0')}-'
            '${parsed.day.toString().padLeft(2, '0')}';
  }
}
