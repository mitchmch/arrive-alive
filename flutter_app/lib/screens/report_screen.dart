import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme.dart';
import '../core/config.dart';
import '../controllers/hazard_controller.dart';
import '../models/incident.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import 'journey_screen.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final LatLng? initialLocation;

  const ReportScreen({super.key, this.initialLocation});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  int _category = 0; // 0 = incident, 1 = conduct
  String? _selectedType;
  final _vehicleReg = TextEditingController();
  final _driverName = TextEditingController();
  final _description = TextEditingController();
  bool _submitting = false;
  bool _locating = false;
  LatLng? _pinnedLocation;

  @override
  void initState() {
    super.initState();
    _pinnedLocation = widget.initialLocation;
    if (_pinnedLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _useCurrentLocation(),
      );
    }
  }

  @override
  void dispose() {
    _vehicleReg.dispose();
    _driverName.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _pinnedLocation = LatLng(pos.latitude, pos.longitude);
      }
    });
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location unavailable. Enable GPS and try again.'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a report type')));
      return;
    }
    if (_category == 0 && _pinnedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A pinned GPS location is required for road hazards.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);

    try {
      final description = _description.text.trim();
      final vehicleReg = _vehicleReg.text.trim();
      final driverName = _driverName.text.trim();
      final location = _pinnedLocation;
      final localIncident = location == null
          ? null
          : ref.read(hazardProvider.notifier).addLocalIncident(
                type: _selectedType!,
                description: description,
                lat: location.latitude,
                lng: location.longitude,
                vehicleReg: vehicleReg,
                driverName: driverName,
              );

      final response = await SyncService().createIncidentOfflineFirst(
        type: _selectedType!,
        description: description,
        lat: location?.latitude,
        lng: location?.longitude,
        vehicleReg: vehicleReg,
        driverName: driverName,
      );
      if (localIncident != null && response != null) {
        final remote = Incident.fromJson({
          ...localIncident.toJson(),
          ...response,
          'isLocal': false,
        });
        ref
            .read(hazardProvider.notifier)
            .replaceLocalIncident(localIncident.id, remote);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted — will sync when online'),
          ),
        );
        _goBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const JourneyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final types =
        _category == 0 ? AppConfig.incidentTypes : AppConfig.conductTypes;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Report'),
          leading: IconButton(
            onPressed: _goBack,
            tooltip: 'Go Back',
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.border.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _category = 0;
                          _selectedType = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _category == 0
                                ? AppTheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Road Incident',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _category == 0
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _category = 1;
                          _selectedType = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _category == 1
                                ? AppTheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Driver Conduct',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _category == 1
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
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _pinnedLocation == null
                        ? AppTheme.warning
                        : AppTheme.success.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_pin,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pinnedLocation == null
                                ? 'No GPS location pinned'
                                : 'Pinned report location',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _pinnedLocation == null
                                ? (_category == 0
                                    ? 'Required for road incidents'
                                    : 'Add a location to show this on the map')
                                : '${_pinnedLocation!.latitude.toStringAsFixed(5)}, '
                                    '${_pinnedLocation!.longitude.toStringAsFixed(5)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(
                        _pinnedLocation == null ? 'Use current' : 'Refresh',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Type grid
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
                children: types.map((t) {
                  final isSelected = _selectedType == t['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = t['id']),
                    child: Card(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : AppTheme.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? const BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              )
                            : const BorderSide(color: AppTheme.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t['icon']!,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t['label']!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _vehicleReg,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Registration (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _driverName,
                decoration: const InputDecoration(
                  labelText: 'Driver Name (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
