import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/access_policy.dart';
import '../core/theme.dart';
import '../controllers/auth_controller.dart';
import '../controllers/scoreboard_controller.dart';
import '../models/speed_board_entry.dart';
import 'access_screen.dart';
import 'journey_screen.dart';
import 'login_screen.dart';
import 'travel_flow_screen.dart';

class ScoreboardScreen extends ConsumerStatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  ConsumerState<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends ConsumerState<ScoreboardScreen> {
  int _tab = 0; // 0 = agencies, 1 = violations

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!AccessPolicy.canAccessScoreboard(auth.user)) {
      return _signInRequired(context);
    }

    final boardAsync = ref.watch(speedBoardEntriesProvider);
    final rollupsAsync = ref.watch(agencySafetyRollupsProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Speed Board'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Go Back',
            onPressed: _goBack,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  this.context,
                  MaterialPageRoute(builder: (_) => const AccessScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Tab switcher
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.border.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _tab == 0
                                ? AppTheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Trusted agencies',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _tab == 0
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _tab == 1
                                ? AppTheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Speeding vehicles',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _tab == 1
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _rollupsTab(rollupsAsync, boardAsync)
                  : _boardViolationsTab(boardAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rollupsTab(
    AsyncValue<List<AgencySafetyRollup>> rollupsAsync,
    AsyncValue<List<SpeedBoardEntry>> boardAsync,
  ) {
    return rollupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (rollups) {
        final trusted = rollups.where((item) => item.isTrusted).toList();
        final avoid = rollups.where((item) => item.shouldAvoid).toList();
        final withinLimit = boardAsync.valueOrNull
                ?.where((item) => item.isWithinLimit)
                .toList() ??
            const <SpeedBoardEntry>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle(
              'Trusted agencies',
              'Backed by deterministic evidence thresholds.',
            ),
            if (trusted.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No trusted agencies published yet'),
                ),
              )
            else
              ...trusted.map(_rollupCard),
            const SizedBox(height: 18),
            _sectionTitle(
              'Within-limit journeys',
              'Published journeys with no sustained violation episode.',
            ),
            if (withinLimit.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No within-limit journeys published yet'),
                ),
              )
            else
              ...withinLimit.map(_withinLimitCard),
            if (avoid.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle(
                'Agencies to avoid',
                'Evidence thresholds were met for an avoid classification.',
                color: AppTheme.destructive,
              ),
              ...avoid.map(_rollupCard),
            ],
          ],
        );
      },
    );
  }

  Widget _boardViolationsTab(
    AsyncValue<List<SpeedBoardEntry>> boardAsync,
  ) {
    return boardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (entries) {
        final violations = entries.where((item) => item.isViolation).toList();
        if (violations.isEmpty) {
          return const Center(
            child: Text('No speeding vehicles published yet'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: violations.map(_boardViolationCard).toList(),
        );
      },
    );
  }

  Widget _sectionTitle(String title, String subtitle, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rollupCard(AgencySafetyRollup rollup) {
    final avoid = rollup.shouldAvoid;
    return Card(
      child: ListTile(
        leading: Icon(
          avoid ? Icons.warning_amber_rounded : Icons.verified,
          color: avoid ? AppTheme.destructive : AppTheme.primary,
        ),
        title: Text(
          rollup.agencyName,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${rollup.displaySummary}\n'
          '${rollup.journeyCount} journeys · '
          '${(rollup.confidence * 100).toStringAsFixed(0)}% confidence',
        ),
        isThreeLine: true,
        trailing: Text(avoid ? 'Avoid' : 'Trusted'),
      ),
    );
  }

  Widget _withinLimitCard(SpeedBoardEntry entry) {
    return Card(
      child: ListTile(
        leading:
            const Icon(Icons.check_circle_outline, color: AppTheme.primary),
        title: Text(entry.agencyName),
        subtitle: Text(
          '${entry.mode} · ${entry.sampleCount} accepted samples\n'
          '${entry.summary}',
        ),
        isThreeLine: true,
        trailing: const Text('Within limit'),
      ),
    );
  }

  Widget _boardViolationCard(SpeedBoardEntry entry) {
    final over = (entry.peakSpeed - entry.speedLimit).clamp(0, double.infinity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.vehicleReg.isEmpty ? entry.agencyName : entry.vehicleReg,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '+${over.toStringAsFixed(0)} km/h over',
              style: GoogleFonts.dmSans(
                color: AppTheme.destructive,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${entry.peakSpeed.toStringAsFixed(0)} km/h · '
              'limit ${entry.speedLimit.toStringAsFixed(0)} · '
              '${entry.episodeCount} episodes',
              style: GoogleFonts.dmSans(color: AppTheme.textMuted),
            ),
            if (entry.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(entry.summary),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _goBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TravelFlowScreen()));
  }

  Widget _signInRequired(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnToJourney();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Speed Board'),
          leading: IconButton(
            onPressed: _returnToJourney,
            tooltip: 'Back to journey',
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          key: const Key('scoreboard-sign-in-required'),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.leaderboard_outlined,
                          size: 32,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Registered access required',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Speed Board is available to registered users and administrators.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          height: 1.45,
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (_) => false,
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _returnToJourney,
                        child: const Text('Return to journey map'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _returnToJourney() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JourneyScreen()),
      (_) => false,
    );
  }
}
