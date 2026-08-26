import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../models/journey_evidence_summary.dart';

class JourneyEvidenceSummaryScreen extends StatelessWidget {
  final JourneyEvidenceSummary summary;
  final bool canOpenSpeedBoard;
  final VoidCallback onDone;
  final VoidCallback? onOpenSpeedBoard;

  const JourneyEvidenceSummaryScreen({
    super.key,
    required this.summary,
    required this.canOpenSpeedBoard,
    required this.onDone,
    this.onOpenSpeedBoard,
  });

  @override
  Widget build(BuildContext context) {
    final safe = summary.stayedWithinLimit;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Journey evidence'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (safe ? AppTheme.primary : AppTheme.destructive)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(
                    safe ? Icons.verified_outlined : Icons.speed_outlined,
                    color: safe ? AppTheme.primary : AppTheme.destructive,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    safe
                        ? 'No violation episodes recorded'
                        : '${summary.violationCount} violation '
                            '${summary.violationCount == 1 ? 'episode' : 'episodes'}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Based on recorded speed samples and the '
                    '${summary.speedLimit.toStringAsFixed(0)} km/h limit.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _metric('Samples recorded', '${summary.sampleCount}'),
            _metric(
              'Maximum speed',
              '${summary.maxSpeed.toStringAsFixed(0)} km/h',
            ),
            _metric(
              'Distance',
              '${(summary.distanceMeters / 1000).toStringAsFixed(1)} km',
            ),
            _metric('Duration', _duration(summary.duration)),
            _metric('Evidence score', '${summary.score}/100'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Saved on this device'),
                subtitle: Text(
                  summary.queuedForSync
                      ? 'Evidence is queued for automatic upload when signed in and online.'
                      : 'Evidence upload is complete.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (canOpenSpeedBoard)
              FilledButton.icon(
                key: const Key('open-speed-board'),
                onPressed: onOpenSpeedBoard,
                icon: const Icon(Icons.leaderboard_outlined),
                label: const Text('Open Speed Board'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('finish-summary'),
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _duration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }
}
