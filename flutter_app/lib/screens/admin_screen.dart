import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/admin_controller.dart';
import '../controllers/auth_controller.dart';
import '../core/access_policy.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/agency.dart';
import '../models/incident.dart';
import '../models/violation.dart';
import '../services/sync_service.dart';

enum AdminSection { overview, users, reports, speedBoard, sync }

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  AdminSection _section = AdminSection.overview;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (!AccessPolicy.canAccessAdmin(user)) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            key: Key('admin-access-denied'),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Admin access required',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin workspace')),
      body: SafeArea(
        child: Column(
          children: [
            _SectionPicker(
              selected: _section,
              onSelected: (value) => setState(() => _section = value),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  key: Key('admin-${_section.name}'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [_content()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(statsProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(violationsProvider);
    ref.invalidate(pendingViolationsProvider);
    ref.invalidate(incidentsProvider);
    ref.invalidate(agenciesAdminProvider);
    ref.invalidate(syncHealthProvider);
  }

  Widget _content() {
    switch (_section) {
      case AdminSection.overview:
        return _Overview(value: ref.watch(statsProvider));
      case AdminSection.users:
        return _Users(value: ref.watch(adminUsersProvider));
      case AdminSection.reports:
        return _Reports(
          incidents: ref.watch(incidentsProvider),
          violations: ref.watch(violationsProvider),
        );
      case AdminSection.speedBoard:
        return _SpeedBoard(
          pending: ref.watch(pendingViolationsProvider),
          agencies: ref.watch(agenciesAdminProvider),
        );
      case AdminSection.sync:
        return _SyncHealth(value: ref.watch(syncHealthProvider));
    }
  }
}

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({required this.selected, required this.onSelected});

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      AdminSection.overview: 'Overview',
      AdminSection.users: 'Users',
      AdminSection.reports: 'Reports',
      AdminSection.speedBoard: 'Speed Board',
      AdminSection.sync: 'Sync',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final section in AdminSection.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: Key('admin-tab-${section.name}'),
                label: Text(labels[section]!),
                selected: selected == section,
                onSelected: (_) => onSelected(section),
              ),
            ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.value});
  final AsyncValue<Map<String, dynamic>> value;

  @override
  Widget build(BuildContext context) => value.when(
        loading: _loading,
        error: _error,
        data: (stats) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Heading(
              'Operations overview',
              'Live totals require a configured REST backend.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric('Journeys', stats['totalJourneys'] ?? 0),
                _Metric('Users', stats['totalUsers'] ?? 0),
                _Metric('Violations', stats['totalViolations'] ?? 0),
                _Metric('Reports', stats['totalIncidents'] ?? 0),
              ],
            ),
          ],
        ),
      );
}

class _Users extends StatelessWidget {
  const _Users({required this.value});
  final AsyncValue<List<Map<String, dynamic>>> value;

  @override
  Widget build(BuildContext context) => value.when(
        loading: _loading,
        error: _error,
        data: (users) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Heading('Users', '${users.length} accounts'),
            if (users.isEmpty) const _Empty('No users returned'),
            for (final user in users)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    (user['displayName'] ?? user['phone'] ?? 'User').toString(),
                  ),
                  subtitle: Text((user['role'] ?? 'user').toString()),
                ),
              ),
          ],
        ),
      );
}

class _Reports extends StatelessWidget {
  const _Reports({required this.incidents, required this.violations});
  final AsyncValue<List<Incident>> incidents;
  final AsyncValue<List<Violation>> violations;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading(
              'Reports & incidents', 'Moderation queue and evidence'),
          incidents.when(
            loading: _loading,
            error: _error,
            data: (items) => Column(
              children: [
                for (final item in items)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_outlined),
                      title: Text(item.type),
                      subtitle: Text(item.description ?? item.status),
                    ),
                  ),
                if (items.isEmpty) const _Empty('No incidents returned'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          violations.when(
            loading: _loading,
            error: _error,
            data: (items) => Text('${items.length} violation records'),
          ),
        ],
      );
}

class _SpeedBoard extends StatelessWidget {
  const _SpeedBoard({required this.pending, required this.agencies});
  final AsyncValue<List<Violation>> pending;
  final AsyncValue<List<Agency>> agencies;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading(
            'Speed Board & trusted agencies',
            'Review speeding evidence and agency safety performance.',
          ),
          pending.when(
            loading: _loading,
            error: _error,
            data: (items) => Text('${items.length} violations await review'),
          ),
          const SizedBox(height: 12),
          agencies.when(
            loading: _loading,
            error: _error,
            data: (items) => Column(
              children: [
                for (final agency in items)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_outlined),
                      title: Text(agency.name),
                      subtitle: Text(
                        '${agency.violationCount} violations · '
                        '${agency.totalJourneys} journeys',
                      ),
                      trailing: Text(agency.safetyScore.toStringAsFixed(0)),
                    ),
                  ),
                if (items.isEmpty) const _Empty('No agencies returned'),
              ],
            ),
          ),
        ],
      );
}

class _SyncHealth extends ConsumerWidget {
  const _SyncHealth({required this.value});
  final AsyncValue<dynamic> value;

  @override
  Widget build(BuildContext context, WidgetRef ref) => value.when(
        loading: _loading,
        error: _error,
        data: (health) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Heading(
              'Synchronization health',
              'Local writes remain queued until the backend acknowledges them.',
            ),
            Card(
              color: health.backendConfigured
                  ? null
                  : AppTheme.warning.withValues(alpha: .12),
              child: ListTile(
                leading: Icon(
                  health.backendConfigured ? Icons.cloud_done : Icons.cloud_off,
                ),
                title: Text(
                  health.backendConfigured
                      ? 'REST backend configured'
                      : 'Local-only mode',
                ),
                subtitle: Text(
                  health.backendConfigured
                      ? 'Pending ${health.pending} · Retrying '
                          '${health.retrying} · Failed ${health.failed}'
                      : 'API_BASE_URL is absent. Nothing is claimed as '
                          'uploaded or synchronized.',
                ),
              ),
            ),
            if (health.lastError != null)
              Text('Last error: ${health.lastError}'),
            if (health.failed > 0)
              FilledButton.icon(
                onPressed: () async {
                  await SyncService().retryFailed();
                  ref.invalidate(syncHealthProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry failed operations'),
              ),
            if (!AppConfig.hasBackend)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Configure with --dart-define=API_BASE_URL=https://…',
                ),
              ),
          ],
        ),
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 136,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(label),
              ],
            ),
          ),
        ),
      );
}

Widget _loading() => const Center(child: CircularProgressIndicator());
Widget _error(Object error, StackTrace _) => _Empty(
      error.toString().contains('Backend unavailable')
          ? 'Backend not configured; server data is unavailable.'
          : 'Could not load this section.',
    );

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(message, textAlign: TextAlign.center)),
      );
}
