import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/access_policy.dart';
import '../core/theme.dart';
import '../controllers/auth_controller.dart';
import '../controllers/scoreboard_controller.dart';
import '../models/violation.dart';
import '../models/agency.dart';
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

    final violationsAsync = ref.watch(publishedViolationsProvider);
    final agenciesAsync = ref.watch(agenciesProvider);

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
                  ? _agenciesTab(agenciesAsync)
                  : _violationsTab(violationsAsync),
            ),
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

  Widget _agenciesTab(AsyncValue<List<Agency>> agenciesAsync) {
    return agenciesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (agencies) {
        final sorted = List<Agency>.from(agencies)
          ..sort((a, b) => a.safetyScore.compareTo(b.safetyScore));
        final needsAttention =
            sorted.where((a) => a.safetyScore < 100).toList();
        final trusted = sorted.where((a) => a.safetyScore == 100).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Trusted agencies',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Agencies with a clear published safety record.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            if (trusted.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.verified_outlined),
                  title: Text('No trusted agencies published yet'),
                ),
              )
            else
              ...trusted.asMap().entries.map(
                    (e) => _agencyCard(e.key + 1, e.value, trusted: true),
                  ),
            if (needsAttention.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Needs attention',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...needsAttention.asMap().entries.map(
                    (e) => _agencyCard(
                      trusted.length + e.key + 1,
                      e.value,
                      trusted: false,
                    ),
                  ),
            ],
          ],
        );
      },
    );
  }

  Widget _agencyCard(int rank, Agency agency, {required bool trusted}) {
    final region = agency.region?.trim();
    return Card(
      color: trusted
          ? AppTheme.primary.withValues(alpha: 0.06)
          : Theme.of(context).cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
          foregroundColor: AppTheme.primary,
          child: trusted
              ? const Icon(Icons.verified, size: 21)
              : Text(
                  '$rank',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
        ),
        title: Text(
          agency.name,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (region != null && region.isNotEmpty) region,
            trusted
                ? 'Trusted safety record'
                : '${agency.violationCount} published violations',
          ].join(' · '),
          style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.textMuted),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            trusted ? 'Trusted' : '${agency.safetyScore.toInt()}%',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _violationsTab(AsyncValue<List<Violation>> violationsAsync) {
    return violationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (violations) {
        if (violations.isEmpty) {
          return Center(
            child: Text(
              'No speeding vehicles published yet',
              style: GoogleFonts.dmSans(color: AppTheme.textMuted),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: violations.length,
          itemBuilder: (ctx, i) => _violationCard(violations[i]),
        );
      },
    );
  }

  Widget _violationCard(Violation v) {
    final overLimit = (v.speed - v.speedLimit).clamp(0, double.infinity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    v.vehicleReg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _formatDate(v.timestamp),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.destructive,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${overLimit.toStringAsFixed(0)} km/h over',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${v.speed.toStringAsFixed(0)} km/h · limit ${v.speedLimit.toStringAsFixed(0)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${v.mode} · ${v.reportCount} reports',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String ts) {
    try {
      return DateTime.parse(ts).toString().substring(0, 10);
    } catch (_) {
      return ts;
    }
  }
}
