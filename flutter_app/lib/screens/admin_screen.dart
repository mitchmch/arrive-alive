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

enum AdminSection {
  overview,
  users,
  reports,
  agencies,
  vehicles,
  speedLimits,
  syncHealth,
}

extension on AdminSection {
  String get label => switch (this) {
        AdminSection.overview => 'Overview',
        AdminSection.users => 'Users',
        AdminSection.reports => 'Reports',
        AdminSection.agencies => 'Agencies / Speed Board',
        AdminSection.vehicles => 'Vehicles',
        AdminSection.speedLimits => 'Speed limits',
        AdminSection.syncHealth => 'Sync Health',
      };

  String get description => switch (this) {
        AdminSection.overview => 'Network performance at a glance',
        AdminSection.users => 'Accounts and administrator access',
        AdminSection.reports => 'Incidents and speeding evidence',
        AdminSection.agencies => 'Agency safety and moderation',
        AdminSection.vehicles => 'Fleet activity by vehicle type',
        AdminSection.speedLimits => 'Policy thresholds by vehicle',
        AdminSection.syncHealth => 'Offline queue and backend status',
      };

  IconData get icon => switch (this) {
        AdminSection.overview => Icons.dashboard_outlined,
        AdminSection.users => Icons.group_outlined,
        AdminSection.reports => Icons.assignment_outlined,
        AdminSection.agencies => Icons.apartment_outlined,
        AdminSection.vehicles => Icons.directions_car_outlined,
        AdminSection.speedLimits => Icons.speed_outlined,
        AdminSection.syncHealth => Icons.cloud_sync_outlined,
      };
}

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: Text(wide ? 'Admin workspace' : _section.label),
            actions: [
              IconButton(
                key: const Key('admin-refresh'),
                tooltip: 'Refresh administrator data',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: wide
              ? null
              : _AdminDrawer(
                  selected: _section,
                  onSelected: (section) {
                    Navigator.of(context).pop();
                    setState(() => _section = section);
                  },
                ),
          body: SafeArea(
            top: false,
            child: Row(
              children: [
                if (wide) ...[
                  _AdminRail(
                    extended: constraints.maxWidth >= 1180,
                    selected: _section,
                    onSelected: (section) => setState(() => _section = section),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      key: Key('admin-${_section.name}'),
                      padding: EdgeInsets.fromLTRB(
                        wide ? 32 : 16,
                        24,
                        wide ? 32 : 16,
                        40,
                      ),
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: _content(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(statsProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(violationsProvider);
    ref.invalidate(pendingViolationsProvider);
    ref.invalidate(incidentsProvider);
    ref.invalidate(agenciesAdminProvider);
    ref.invalidate(speedLimitsAdminProvider);
    ref.invalidate(syncHealthProvider);
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Widget _content() {
    final heading = _SectionHeading(
      title: _section.label,
      subtitle: _section.description,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: 20),
        switch (_section) {
          AdminSection.overview => _Overview(value: ref.watch(statsProvider)),
          AdminSection.users => _Users(value: ref.watch(adminUsersProvider)),
          AdminSection.reports => _Reports(
              incidents: ref.watch(incidentsProvider),
              violations: ref.watch(violationsProvider),
            ),
          AdminSection.agencies => _Agencies(
              pending: ref.watch(pendingViolationsProvider),
              agencies: ref.watch(agenciesAdminProvider),
              violations: ref.watch(violationsProvider),
            ),
          AdminSection.vehicles => _Vehicles(
              stats: ref.watch(statsProvider),
              violations: ref.watch(violationsProvider),
            ),
          AdminSection.speedLimits =>
            _SpeedLimits(value: ref.watch(speedLimitsAdminProvider)),
          AdminSection.syncHealth =>
            _SyncHealth(value: ref.watch(syncHealthProvider)),
        },
      ],
    );
  }
}

class _AdminRail extends StatelessWidget {
  const _AdminRail({
    required this.extended,
    required this.selected,
    required this.onSelected,
  });

  final bool extended;
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      key: const Key('admin-navigation-rail'),
      extended: extended,
      minExtendedWidth: 248,
      selectedIndex: AdminSection.values.indexOf(selected),
      onDestinationSelected: (index) => onSelected(AdminSection.values[index]),
      leading: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.shield_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      destinations: [
        for (final section in AdminSection.values)
          NavigationRailDestination(
            icon: Icon(
              section.icon,
              key: Key('admin-tab-${section.name}'),
            ),
            selectedIcon: Icon(section.icon),
            label: Text(section.label),
          ),
      ],
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.selected, required this.onSelected});

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('admin-navigation-drawer'),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Administrator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final section in AdminSection.values)
                    ListTile(
                      key: Key('admin-tab-${section.name}'),
                      selected: selected == section,
                      leading: Icon(section.icon),
                      title: Text(section.label),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onTap: () => onSelected(section),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                )),
      ],
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
        data: (stats) {
          final metrics = [
            _MetricData(
              'Journeys',
              _stat(stats, ['totalJourneys', 'journeys']),
              Icons.route_outlined,
            ),
            _MetricData(
              'Users',
              _stat(stats, ['totalUsers', 'users']),
              Icons.group_outlined,
            ),
            _MetricData(
              'Reports',
              _stat(stats, ['totalIncidents', 'incidents', 'reports']),
              Icons.assignment_outlined,
            ),
            _MetricData(
              'Violations',
              _stat(stats, ['totalViolations', 'violations']),
              Icons.speed_outlined,
            ),
            _MetricData(
              'Agencies',
              _stat(stats, ['totalAgencies', 'agencies']),
              Icons.apartment_outlined,
            ),
            _MetricData(
              'Pending review',
              _stat(stats, ['pendingViolations', 'pendingReports', 'pending']),
              Icons.pending_actions_outlined,
            ),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricGrid(metrics: metrics),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.insights_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Operational snapshot',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Use Reports for evidence review, Agencies for '
                              'fleet safety, and Sync Health for delivery state.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 520
                ? 2
                : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: .7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                metric.icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${metric.value}',
                    key: Key(
                      'admin-metric-${metric.label.toLowerCase().replaceAll(' ', '-')}',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    metric.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            _CountBanner(
              icon: Icons.group_outlined,
              title: '${users.length} accounts',
              subtitle:
                  'Roles remain enforced by the server and access policy.',
            ),
            const SizedBox(height: 12),
            if (users.isEmpty) const _Empty('No users returned'),
            for (final user in users)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      _initial(
                        user['displayName'] ?? user['phone'] ?? 'User',
                      ),
                    ),
                  ),
                  title: Text(
                    (user['displayName'] ?? user['phone'] ?? 'User').toString(),
                  ),
                  subtitle: Text(
                    (user['phone'] ?? 'No phone number').toString(),
                  ),
                  trailing: _StatusBadge(
                    label: (user['role'] ?? 'user').toString(),
                    positive: user['role'] == 'admin',
                  ),
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _AsyncCount(
                value: incidents,
                icon: Icons.warning_amber_outlined,
                label: 'Incident reports',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AsyncCount(
                value: violations,
                icon: Icons.speed_outlined,
                label: 'Speed violations',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Recent incidents', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        incidents.when(
          loading: _loading,
          error: _error,
          data: (items) => Column(
            children: [
              for (final item in items)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: Text(_titleCase(item.type)),
                    subtitle: Text(item.description ?? item.status),
                    trailing: _StatusBadge(
                      label: item.status,
                      positive: item.status == 'resolved',
                    ),
                  ),
                ),
              if (items.isEmpty) const _Empty('No incidents returned'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AsyncCount<T> extends StatelessWidget {
  const _AsyncCount({
    required this.value,
    required this.icon,
    required this.label,
  });

  final AsyncValue<List<T>> value;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final count = value.valueOrNull?.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              count == null ? '—' : '$count',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Agencies extends ConsumerWidget {
  const _Agencies({
    required this.pending,
    required this.agencies,
    required this.violations,
  });

  final AsyncValue<List<Violation>> pending;
  final AsyncValue<List<Agency>> agencies;
  final AsyncValue<List<Violation>> violations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pending.when(
          loading: _loading,
          error: _error,
          data: (items) => _CountBanner(
            icon: Icons.pending_actions_outlined,
            title: '${items.length} violations await review',
            subtitle: items.isEmpty
                ? 'The moderation queue is clear.'
                : 'Validate evidence before it reaches the Speed Board.',
          ),
        ),
        const SizedBox(height: 20),
        Text('Agency performance',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Select an agency for fleet and safety details.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        agencies.when(
          loading: _loading,
          error: _error,
          data: (items) => Column(
            children: [
              for (final agency in items)
                Card(
                  child: ListTile(
                    key: Key('agency-${agency.id}'),
                    leading: CircleAvatar(
                      backgroundColor: agency.isTrusted
                          ? AppTheme.success.withValues(alpha: .12)
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        agency.isTrusted
                            ? Icons.verified_outlined
                            : Icons.apartment_outlined,
                        color: agency.isTrusted
                            ? AppTheme.success
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(agency.name),
                    subtitle: Text(
                      '${agency.totalJourneys} journeys · '
                      '${agency.violationCount} violations',
                    ),
                    trailing: _StatusBadge(
                      label: agency.isTrusted
                          ? 'Trusted'
                          : '${agency.safetyScore.toStringAsFixed(0)}%',
                      positive: agency.isTrusted,
                    ),
                    onTap: () => _showAgencyDetails(
                      context,
                      ref,
                      agency,
                      violations.valueOrNull ?? const [],
                    ),
                  ),
                ),
              if (items.isEmpty) const _Empty('No agencies returned'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAgencyDetails(
    BuildContext context,
    WidgetRef ref,
    Agency agency,
    List<Violation> allViolations,
  ) async {
    final agencyViolations =
        allViolations.where((item) => item.agencyId == agency.id).toList();
    final breakdown = <String, int>{
      'car': agency.vehicleBreakdown['car'] ?? 0,
      'bus': agency.vehicleBreakdown['bus'] ?? 0,
      'lorry': agency.vehicleBreakdown['lorry'] ?? 0,
      'motorbike': agency.vehicleBreakdown['motorbike'] ??
          agency.vehicleBreakdown['bike'] ??
          0,
    };
    for (final violation in agencyViolations) {
      final type = _normalizeVehicleType(violation.mode);
      if ((breakdown[type] ?? 0) == 0) {
        breakdown[type] = agencyViolations
            .where((item) => _normalizeVehicleType(item.mode) == type)
            .map((item) => item.vehicleReg)
            .where((reg) => reg.isNotEmpty)
            .toSet()
            .length;
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: Key('agency-detail-${agency.id}'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agency.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(agency.region ?? 'Region not supplied'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close agency details',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusBadge(
                      label: agency.isTrusted ? 'Trusted' : 'Under review',
                      positive: agency.isTrusted,
                    ),
                    _DetailPill(
                      '${agency.safetyScore.toStringAsFixed(0)}% safety score',
                    ),
                    _DetailPill('${agency.totalJourneys} journeys'),
                    _DetailPill('${agency.violationCount} violations'),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Vehicle breakdown',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final type in _vehicleTypes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(_vehicleIcon(type), size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_vehicleLabel(type))),
                        Text(
                          '${breakdown[type] ?? 0}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('share-agency-report'),
                      onPressed: () =>
                          _runReportAction(context, ref, agency, share: true),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share report'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('export-agency-pdf'),
                      onPressed: () =>
                          _runReportAction(context, ref, agency, share: false),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Export PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runReportAction(
    BuildContext context,
    WidgetRef ref,
    Agency agency, {
    required bool share,
  }) async {
    final service = ref.read(adminReportServiceProvider);
    final result = share
        ? await service.shareAgencyReport(agency)
        : await service.exportAgencyPdf(agency);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _Vehicles extends StatelessWidget {
  const _Vehicles({required this.stats, required this.violations});

  final AsyncValue<Map<String, dynamic>> stats;
  final AsyncValue<List<Violation>> violations;

  @override
  Widget build(BuildContext context) {
    if (stats.isLoading || violations.isLoading) return _loading();
    if (stats.hasError && violations.hasError) {
      return _error(stats.error!, StackTrace.empty);
    }

    final statsData = stats.valueOrNull ?? const <String, dynamic>{};
    final items = violations.valueOrNull ?? const <Violation>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 700;
        const gap = 12.0;
        final width = twoColumns
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final type in _vehicleTypes)
              SizedBox(
                key: Key('vehicle-type-$type'),
                width: width,
                child: _VehicleCard(
                  type: type,
                  count: _vehicleCount(statsData, items, type),
                  violations: items
                      .where(
                        (item) => _normalizeVehicleType(item.mode) == type,
                      )
                      .length,
                  registrations: items
                      .where(
                        (item) => _normalizeVehicleType(item.mode) == type,
                      )
                      .map((item) => item.vehicleReg)
                      .where((item) => item.isNotEmpty)
                      .toSet()
                      .take(3)
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.type,
    required this.count,
    required this.violations,
    required this.registrations,
  });

  final String type;
  final int count;
  final int violations;
  final List<String> registrations;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _vehicleIcon(type),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _vehicleLabel(type),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$violations recorded violations',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              registrations.isEmpty
                  ? 'No registrations in current evidence'
                  : registrations.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedLimits extends ConsumerWidget {
  const _SpeedLimits({required this.value});

  final AsyncValue<Map<String, double>> value;

  @override
  Widget build(BuildContext context, WidgetRef ref) => value.when(
        loading: _loading,
        error: _error,
        data: (limits) => Column(
          children: [
            const _CountBanner(
              icon: Icons.info_outline,
              title: 'Limits apply to new journey readings',
              subtitle: 'Values are in kilometres per hour.',
            ),
            const SizedBox(height: 12),
            for (final type in _vehicleTypes)
              Card(
                child: ListTile(
                  key: Key('speed-limit-$type'),
                  leading: Icon(_vehicleIcon(type)),
                  title: Text(_vehicleLabel(type)),
                  subtitle: const Text('Maximum permitted speed'),
                  trailing: Text(
                    '${_limitForType(limits, type).toStringAsFixed(0)} km/h',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _editLimit(context, ref, limits, type),
                ),
              ),
          ],
        ),
      );

  Future<void> _editLimit(
    BuildContext context,
    WidgetRef ref,
    Map<String, double> limits,
    String type,
  ) async {
    final current = _limitForType(limits, type);
    final controller = TextEditingController(
      text: current.toStringAsFixed(0),
    );
    final next = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_vehicleLabel(type)} speed limit'),
        content: TextField(
          key: Key('speed-limit-input-$type'),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'km/h'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed != null && parsed >= 10 && parsed <= 180) {
                Navigator.of(context).pop(parsed);
              }
            },
            child: const Text('Save limit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || !context.mounted) return;

    final payload = <String, int>{
      for (final entry in limits.entries) entry.key: entry.value.round(),
      type: next,
    };
    try {
      await saveSpeedLimits(payload);
      ref.invalidate(speedLimitsAdminProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speed limits updated')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update limits. Check backend access.'),
          ),
        );
      }
    }
  }
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
            Card(
              color: health.backendConfigured
                  ? null
                  : AppTheme.warning.withValues(alpha: .1),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          health.backendConfigured
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            health.backendConfigured
                                ? 'REST backend configured'
                                : 'Local-only mode',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        _StatusBadge(
                          label: health.healthy ? 'Healthy' : 'Attention',
                          positive: health.healthy,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DetailPill('${health.pending} pending'),
                        _DetailPill('${health.retrying} retrying'),
                        _DetailPill('${health.failed} failed'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      health.backendConfigured
                          ? 'Queued writes remain local until acknowledged.'
                          : 'API_BASE_URL is absent. Nothing is reported as '
                              'uploaded or synchronized.',
                    ),
                  ],
                ),
              ),
            ),
            if (health.lastError != null) ...[
              const SizedBox(height: 12),
              Text('Last error: ${health.lastError}'),
            ],
            if (health.failed > 0) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await SyncService().retryFailed();
                  ref.invalidate(syncHealthProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry failed operations'),
              ),
            ],
            if (!AppConfig.hasBackend)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Configure with --dart-define=API_BASE_URL=https://…',
                ),
              ),
          ],
        ),
      );
}

class _CountBanner extends StatelessWidget {
  const _CountBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color =
        positive ? AppTheme.success : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

const _vehicleTypes = ['car', 'bus', 'lorry', 'motorbike'];

int _stat(Map<String, dynamic> stats, List<String> keys) {
  for (final key in keys) {
    final value = stats[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse('$value');
    if (parsed != null) return parsed;
  }
  return 0;
}

int _vehicleCount(
  Map<String, dynamic> stats,
  List<Violation> violations,
  String type,
) {
  final nested = stats['vehiclesByType'] ??
      stats['vehicleBreakdown'] ??
      stats['vehicles_by_type'];
  if (nested is Map) {
    final value = nested[type] ??
        (type == 'motorbike' ? nested['bike'] ?? nested['motorcycle'] : null);
    if (value is num) return value.toInt();
    final parsed = int.tryParse('$value');
    if (parsed != null) return parsed;
  }
  return violations
      .where((item) => _normalizeVehicleType(item.mode) == type)
      .map((item) => item.vehicleReg)
      .where((item) => item.isNotEmpty)
      .toSet()
      .length;
}

double _limitForType(Map<String, double> limits, String type) {
  return limits[type] ??
      (type == 'motorbike' ? limits['bike'] ?? limits['motorcycle'] : null) ??
      AppConfig.defaultSpeedLimit;
}

String _normalizeVehicleType(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'bike' || normalized == 'motorcycle') return 'motorbike';
  return normalized;
}

String _vehicleLabel(String type) => switch (type) {
      'car' => 'Cars',
      'bus' => 'Buses',
      'lorry' => 'Lorries',
      'motorbike' => 'Motorbikes',
      _ => _titleCase(type),
    };

IconData _vehicleIcon(String type) => switch (type) {
      'car' => Icons.directions_car_outlined,
      'bus' => Icons.directions_bus_outlined,
      'lorry' => Icons.local_shipping_outlined,
      'motorbike' => Icons.two_wheeler_outlined,
      _ => Icons.commute_outlined,
    };

String _initial(Object value) {
  final text = value.toString().trim();
  return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
}

String _titleCase(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'Unknown';
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

Widget _loading() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );

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
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(message, textAlign: TextAlign.center)),
      );
}
