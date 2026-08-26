import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme.dart';
import '../core/config.dart';
import '../controllers/navigation_controller.dart';

/// Destination search overlay — appears when user taps the navigation button
class DestinationSearchOverlay extends ConsumerStatefulWidget {
  final LatLng currentLocation;
  final VoidCallback onClose;

  const DestinationSearchOverlay({
    super.key,
    required this.currentLocation,
    required this.onClose,
  });

  @override
  ConsumerState<DestinationSearchOverlay> createState() =>
      _DestinationSearchOverlayState();
}

class _DestinationSearchOverlayState
    extends ConsumerState<DestinationSearchOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navigationControllerProvider);

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 60),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Navigate to',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search destination in Cameroon...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.textMuted,
                    ),
                    suffixIcon: nav.isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    ref
                        .read(navigationControllerProvider.notifier)
                        .searchDestination(value);
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Quick suggestions
              if (_controller.text.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Popular destinations',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConfig.cameroonCities.take(8).map((city) {
                          return ActionChip(
                            label: Text(city),
                            onPressed: () {
                              _controller.text = city;
                              ref
                                  .read(navigationControllerProvider.notifier)
                                  .searchDestination(city);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              // Search results
              if (nav.searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: nav.searchResults.length,
                    itemBuilder: (context, index) {
                      final result = nav.searchResults[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: AppTheme.primary,
                        ),
                        title: Text(
                          result.name,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${result.lat.toStringAsFixed(4)}, ${result.lng.toStringAsFixed(4)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        onTap: () {
                          ref
                              .read(navigationControllerProvider.notifier)
                              .setDestinationAndRoute(
                                result,
                                widget.currentLocation,
                              );
                          widget.onClose();
                        },
                      );
                    },
                  ),
                ),
              // Fetching route indicator
              if (nav.isFetchingRoute)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Fetching route...'),
                    ],
                  ),
                ),
              // Error
              if (nav.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    nav.errorMessage!,
                    style: GoogleFonts.dmSans(
                      color: AppTheme.destructive,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigation instruction card overlay — shows the next turn instruction
class NavigationInstructionCard extends ConsumerWidget {
  const NavigationInstructionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationControllerProvider);

    if (!nav.isNavigating || nav.route == null) return const SizedBox.shrink();

    final route = nav.route!;
    final remainingKm = nav.remainingDistanceMeters / 1000;
    final remainingMin = (nav.remainingDurationSeconds / 60).round();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Next instruction bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Maneuver icon
                  Icon(
                    _getManeuverIcon(nav.nextManeuver),
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  // Instruction text
                  Expanded(
                    child: Text(
                      nav.nextInstruction ?? 'Continue',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Distance to next turn
                  if (nav.nextStepDistance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        nav.nextStepDistance!,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Route summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          route.destinationName,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _summaryChip(
                        icon: Icons.straight,
                        label: remainingKm >= 1
                            ? '${remainingKm.toStringAsFixed(1)} km'
                            : '${nav.remainingDistanceMeters} m',
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        icon: Icons.access_time,
                        label: '$remainingMin min',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Stop navigation button
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Row(
                children: [
                  // Voice toggle
                  IconButton(
                    onPressed: () {
                      ref
                          .read(navigationControllerProvider.notifier)
                          .toggleVoice();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ref
                                    .read(navigationControllerProvider.notifier)
                                    .voiceEnabled
                                ? 'Voice guidance on'
                                : 'Voice guidance off',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: Icon(
                      ref
                              .read(navigationControllerProvider.notifier)
                              .voiceEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        ref
                            .read(navigationControllerProvider.notifier)
                            .stopNavigation();
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('End Navigation'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  IconData _getManeuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-left':
      case 'turn-slight-left':
      case 'turn-sharp-left':
        return Icons.turn_left;
      case 'turn-right':
      case 'turn-slight-right':
      case 'turn-sharp-right':
        return Icons.turn_right;
      case 'uturn':
        return Icons.u_turn_left;
      case 'roundabout-left':
      case 'roundabout-right':
      case 'roundabout':
        return Icons.roundabout_right;
      case 'merge':
        return Icons.merge;
      case 'fork-left':
        return Icons.fork_left;
      case 'fork-right':
        return Icons.fork_right;
      case 'keep-left':
        return Icons.turn_slight_left;
      case 'keep-right':
        return Icons.turn_slight_right;
      case 'ramp-left':
        return Icons.ramp_left;
      case 'ramp-right':
        return Icons.ramp_right;
      default:
        return Icons.straight;
    }
  }
}
