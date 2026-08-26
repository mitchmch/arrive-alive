import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/config.dart';
import '../controllers/journey_controller.dart';
import '../controllers/scoreboard_controller.dart';
import 'access_screen.dart';
import 'journey_screen.dart';

class TravelFlowScreen extends ConsumerStatefulWidget {
  const TravelFlowScreen({super.key});

  @override
  ConsumerState<TravelFlowScreen> createState() => _TravelFlowScreenState();
}

class _TravelFlowScreenState extends ConsumerState<TravelFlowScreen> {
  int _step = 0;
  final _reg = TextEditingController();
  final _colour = TextEditingController();
  final _driverName = TextEditingController();
  final _passengers = TextEditingController(text: '1');
  String? _vehicleType;
  int? _agencyId;
  final _customDefect = TextEditingController();

  static const _modeLabels = {
    'car': {'label': 'Car', 'icon': '🚗'},
    'bus': {'label': 'Bus', 'icon': '🚌'},
    'lorry': {'label': 'Lorry', 'icon': '🚚'},
    'bike': {'label': 'Bike', 'icon': '🏍️'},
  };

  @override
  void dispose() {
    _reg.dispose();
    _colour.dispose();
    _driverName.dispose();
    _passengers.dispose();
    _customDefect.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _goBack() async {
    if (_step > 0) {
      _back();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AccessScreen()),
      (_) => false,
    );
  }

  void _finish() {
    final journey = ref.read(journeyProvider.notifier);
    final vehicleDetails = {
      'type': _vehicleType,
      'reg': _reg.text.trim(),
      'colour': _colour.text.trim(),
    };
    journey.setVehicleDetails(vehicleDetails);
    journey.setDriverName(_driverName.text.trim());
    journey.setPassengerCount(int.tryParse(_passengers.text) ?? 1);
    if (_agencyId != null) journey.setAgencyId(_agencyId!);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JourneyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Set Up Journey'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Go Back',
            onPressed: _goBack,
          ),
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_step + 1) / 4,
              minHeight: 4,
              backgroundColor: AppTheme.border,
              color: AppTheme.primary,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildStep(),
              ),
            ),
            // Navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceed() ? _next : null,
                  child: Text(_step == 3 ? 'Start Journey' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    final journey = ref.read(journeyProvider);
    switch (_step) {
      case 0:
        return journey.mode != null;
      case 1:
        return _vehicleType != null && _reg.text.isNotEmpty;
      case 2:
        return true; // Skippable
      case 3:
        return true; // Skippable
      default:
        return false;
    }
  }

  Widget _buildStep() {
    final journey = ref.watch(journeyProvider);
    switch (_step) {
      case 0:
        return _modeSelection(journey.mode);
      case 1:
        return _vehicleDetails(journey.mode);
      case 2:
        return _assets(journey.mode, journey.selectedAssets);
      case 3:
        return _defects(journey.mode, journey.selectedDefects);
      default:
        return const SizedBox();
    }
  }

  Widget _modeSelection(String? selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Mode of Travel',
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your vehicle type',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: _modeLabels.entries.map((e) {
            final isSelected = selected == e.key;
            return GestureDetector(
              onTap: () => ref.read(journeyProvider.notifier).setMode(e.key),
              child: Card(
                color: isSelected ? AppTheme.primary : AppTheme.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? BorderSide.none
                      : const BorderSide(color: AppTheme.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      e.value['icon']!,
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.value['label']!,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _vehicleDetails(String? mode) {
    if (mode == null) return const SizedBox();
    final types = AppConfig.vehicleTypes[mode] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Details',
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue: _vehicleType,
          decoration: const InputDecoration(labelText: 'Vehicle Type'),
          items: types
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _vehicleType = v),
        ),
        const SizedBox(height: 16),
        ref.watch(agenciesProvider).when(
              data: (agencies) => DropdownButtonFormField<int>(
                initialValue: _agencyId,
                decoration: const InputDecoration(
                  labelText: 'Travel Agency (optional)',
                  helperText:
                      'Leave blank for an independent or private vehicle.',
                ),
                items: agencies
                    .map(
                      (agency) => DropdownMenuItem(
                        value: agency.id,
                        child: Text(agency.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _agencyId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(
                'Agency list unavailable. Continue as an independent vehicle.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
        const SizedBox(height: 16),
        TextField(
          controller: _reg,
          decoration: const InputDecoration(
            labelText: 'Registration Number',
            hintText: 'NW 1234 AB',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _colour,
          decoration: const InputDecoration(labelText: 'Colour'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _driverName,
          decoration: const InputDecoration(labelText: 'Driver Name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passengers,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Passenger Count'),
        ),
      ],
    );
  }

  Widget _assets(String? mode, List<String> selected) {
    if (mode == null) return const SizedBox();
    final items = AppConfig.assets[mode] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Assets',
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(
          'Select all that apply. Skip if none.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isSelected = selected.contains(item);
            return FilterChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(journeyProvider.notifier).toggleAsset(item),
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _defects(String? mode, List<String> selected) {
    if (mode == null) return const SizedBox();
    final items = AppConfig.defects[mode] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Defects',
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(
          'Report any defects. Skip if none.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...items.map((item) {
              final isSelected = selected.contains(item);
              return FilterChip(
                label: Text(item),
                selected: isSelected,
                onSelected: (_) =>
                    ref.read(journeyProvider.notifier).toggleDefect(item),
                selectedColor: AppTheme.destructive,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              );
            }),
            if (_customDefect.text.isNotEmpty &&
                !selected.contains(_customDefect.text))
              FilterChip(
                label: Text(_customDefect.text),
                selected: false,
                onSelected: (_) => ref
                    .read(journeyProvider.notifier)
                    .toggleDefect(_customDefect.text),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _customDefect,
          decoration: const InputDecoration(labelText: 'Add custom defect'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              ref.read(journeyProvider.notifier).toggleDefect(v.trim());
              setState(() => _customDefect.clear());
            }
          },
        ),
      ],
    );
  }
}
