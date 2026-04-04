import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/map_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../passenger/ride_results_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropoffFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    // Pre-fill pickup from current location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final searchState = ref.read(searchProvider);
      if (searchState.pickupAddress.isNotEmpty) {
        _pickupCtrl.text = searchState.pickupAddress;
      }

      // Focus dropoff after short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _dropoffFocus.requestFocus();
      });
    });

    _dropoffFocus.addListener(() {
      if (_dropoffFocus.hasFocus) {
        ref.read(searchProvider.notifier).setSearchingPickup(false);
      }
    });

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        ref.read(searchProvider.notifier).setSearchingPickup(true);
      }
    });
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    super.dispose();
  }

  void _onInputChanged(String value) {
    final bias = ref.read(currentLatLngProvider);
    ref.read(searchProvider.notifier).searchPlaces(value, biasLocation: bias);
  }

  Future<void> _onInputSubmitted() async {
    final state = ref.read(searchProvider);
    if (state.suggestions.isNotEmpty) {
      // Auto-select the top suggestion if the user just hits 'Enter' on keyboard
      await _onSuggestionSelected(state.suggestions.first);
    }
  }

  Future<void> _onSuggestionSelected(PlaceSuggestion suggestion) async {
    await ref.read(searchProvider.notifier).selectSuggestion(suggestion);
    final state = ref.read(searchProvider);

    if (state.isSearchingPickup) {
      _pickupCtrl.text = suggestion.fullText;
    } else {
      _dropoffCtrl.text = suggestion.fullText;
    }

    // If both set, proceed to search
    if (state.isComplete) {
      _proceedToResults();
    } else if (!state.isSearchingPickup) {
      // dropoff selected, focus it done; now search
    }
  }

  void _proceedToResults() {
    final state = ref.read(searchProvider);
    if (!state.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both pickup and dropoff locations')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    // Navigate to results
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RideResultsSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Plan your ride',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppTheme.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // ─── Location Inputs ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Route indicator dots
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: dot line
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 32,
                          color: Colors.grey.shade300,
                        ),
                        const Icon(Icons.location_on,
                            color: AppTheme.primary, size: 16),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Right: inputs
                    Expanded(
                      child: Column(
                        children: [
                          // Pickup
                          _LocationInput(
                            controller: _pickupCtrl,
                            focusNode: _pickupFocus,
                            hint: 'Pickup location',
                            isActive: searchState.isSearchingPickup,
                            onChanged: _onInputChanged,
                            onSubmitted: (_) => _onInputSubmitted(),
                            onClear: () {
                              _pickupCtrl.clear();
                              ref
                                  .read(searchProvider.notifier)
                                  .setSearchingPickup(true);
                            },
                          ),
                          Container(
                              height: 1,
                              color: AppTheme.divider,
                              margin: const EdgeInsets.symmetric(vertical: 4)),
                          // Dropoff
                          _LocationInput(
                            controller: _dropoffCtrl,
                            focusNode: _dropoffFocus,
                            hint: 'Where to?',
                            isActive: !searchState.isSearchingPickup,
                            onChanged: _onInputChanged,
                            onSubmitted: (_) => _onInputSubmitted(),
                            onClear: () {
                              _dropoffCtrl.clear();
                              ref
                                  .read(searchProvider.notifier)
                                  .clearDropoff();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ─── Suggestions / Recent ─────────────────────────────────────────
          Expanded(
            child: searchState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary))
                : searchState.suggestions.isNotEmpty
                    ? ListView.separated(
                        itemCount: searchState.suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 52),
                        itemBuilder: (_, i) {
                          final s = searchState.suggestions[i];
                          return _SuggestionTile(
                            suggestion: s,
                            onTap: () => _onSuggestionSelected(s),
                          );
                        },
                      )
                    : _EmptyState(
                        onProceed: searchState.isComplete
                            ? _proceedToResults
                            : null,
                        isComplete: searchState.isComplete,
                        pickupSet: searchState.pickupLatLng != null,
                        dropoffSet: searchState.dropoffLatLng != null,
                        onPopularPlaceTapped: (place) {
                          // Create a mock suggestion for popular place to trigger the flow
                          _onSuggestionSelected(PlaceSuggestion(
                            placeId: place.name, // Will fallback to text search conceptually
                            mainText: place.name,
                            secondaryText: place.area,
                          ));
                        },
                      ),
          ),

          // ─── Search Rides CTA ─────────────────────────────────────────────
          if (searchState.isComplete) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vehicle Type',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _VehicleTypeButtonSearch(
                        label: 'Car',
                        icon: Icons.directions_car_rounded,
                        isSelected: searchState.vehicleType == 'car',
                        onTap: () => ref
                            .read(searchProvider.notifier)
                            .setVehicleType('car'),
                      ),
                      const SizedBox(width: 12),
                      _VehicleTypeButtonSearch(
                        label: 'Bike',
                        icon: Icons.two_wheeler_rounded,
                        isSelected: searchState.vehicleType == 'bike',
                        onTap: () {
                          ref
                              .read(searchProvider.notifier)
                              .setVehicleType('bike');
                          ref.read(searchProvider.notifier).setSeatsNeeded(1);
                        },
                      ),
                    ],
                  ),
                  if (searchState.vehicleType == 'car') ...[
                    const SizedBox(height: 16),
                    const Text('Seats Needed',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(
                        4,
                        (i) {
                          final seats = i + 1;
                          final isSelected = searchState.seatsNeeded == seats;
                          return GestureDetector(
                            onTap: () => ref
                                .read(searchProvider.notifier)
                                .setSeatsNeeded(seats),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? null
                                    : Border.all(color: AppTheme.divider),
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.airline_seat_recline_normal_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                  ),
                                  Text(
                                    '$seats',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _proceedToResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Find Rides',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// ─── Location Input Widget ──────────────────────────────────────────────────
class _LocationInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool isActive;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;

  const _LocationInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.isActive,
    required this.onChanged,
    this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppTheme.textHint, fontSize: 15),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        suffixIcon: controller.text.isNotEmpty
            ? GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 18, color: AppTheme.textSecondary),
              )
            : null,
        filled: false,
      ),
    );
  }
}

// ─── Suggestion Tile ────────────────────────────────────────────────────────
class _SuggestionTile extends StatelessWidget {
  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionTile({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on_outlined,
                  size: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.mainText,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      suggestion.secondaryText,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback? onProceed;
  final bool isComplete;
  final bool pickupSet;
  final bool dropoffSet;
  final ValueChanged<_PopularPlace> onPopularPlaceTapped;

  const _EmptyState({
    this.onProceed,
    required this.isComplete,
    required this.pickupSet,
    required this.dropoffSet,
    required this.onPopularPlaceTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status chips
          Row(
            children: [
              _StatusChip(
                  label: 'Pickup', isSet: pickupSet),
              const SizedBox(width: 8),
              _StatusChip(
                  label: 'Dropoff', isSet: dropoffSet),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Popular Places',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 10),

          ..._popularPlaces.map((p) => _PopularPlaceTile(
            place: p,
            onTap: () => onPopularPlaceTapped(p),
          )),
        ],
      ),
    );
  }

  static const _popularPlaces = [
    _PopularPlace(
        icon: Icons.train_outlined,
        name: 'New Delhi Railway Station',
        area: 'Paharganj, Delhi'),
    _PopularPlace(
        icon: Icons.flight_outlined,
        name: 'Indira Gandhi Airport',
        area: 'Delhi Aerocity'),
    _PopularPlace(
        icon: Icons.store_outlined,
        name: 'Connaught Place',
        area: 'Central Delhi'),
    _PopularPlace(
        icon: Icons.business_outlined,
        name: 'Cyber City',
        area: 'Gurugram, Haryana'),
  ];
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isSet;

  const _StatusChip({required this.label, required this.isSet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSet
            ? AppTheme.accent.withOpacity(0.12)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isSet ? AppTheme.accent : AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: isSet ? AppTheme.accent : AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSet ? AppTheme.accent : AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _PopularPlace {
  final IconData icon;
  final String name;
  final String area;
  const _PopularPlace(
      {required this.icon, required this.name, required this.area});
}

class _PopularPlaceTile extends StatelessWidget {
  final _PopularPlace place;
  final VoidCallback onTap;
  const _PopularPlaceTile({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(place.icon,
                  size: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                Text(place.area,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vehicle Type Button ──────────────────────────────────────────────────────
class _VehicleTypeButtonSearch extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleTypeButtonSearch({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}