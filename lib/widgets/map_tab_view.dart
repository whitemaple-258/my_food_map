import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_food_map/genre_manager.dart';

class MapTabView extends StatelessWidget {
  final LatLng currentPosition;
  final Set<Marker> markers;
  final Set<Marker> searchMarkers;
  final bool isLocationEnabled;
  final bool isWantToGoMode;
  final TextEditingController searchBarController;

  // コールバック
  final Function(GoogleMapController) onMapCreated;
  final Function(LatLng) onLongPress;
  final Function(String) onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onFilterTap;
  final VoidCallback onMyLocationTap;

  // フィルタ表示用
  final String filterName;
  final String? filterGenre;
  final String? filterPrefecture;
  final double? filterMinRating;
  final VoidCallback onClearFilters;
  // チップ削除用コールバック（親側でnullにする処理）
  final Function(String?) onChipDeletedGenre;
  final Function(String?) onChipDeletedPref;
  final Function(double?) onChipDeletedRating;

  const MapTabView({
    super.key,
    required this.currentPosition,
    required this.markers,
    required this.searchMarkers,
    required this.isLocationEnabled,
    required this.isWantToGoMode,
    required this.searchBarController,
    required this.onMapCreated,
    required this.onLongPress,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onFilterTap,
    required this.onMyLocationTap,

    required this.filterName,
    required this.filterGenre,
    required this.filterPrefecture,
    required this.filterMinRating,
    required this.onClearFilters,
    required this.onChipDeletedGenre,
    required this.onChipDeletedPref,
    required this.onChipDeletedRating,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = isWantToGoMode
        ? const Color(0xFF64B5F6)
        : const Color(0xFFFFB74D);
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: onMapCreated,
          initialCameraPosition: CameraPosition(
            target: currentPosition,
            zoom: 15.0,
          ),
          markers: markers.union(searchMarkers),
          myLocationEnabled: isLocationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onLongPress: onLongPress,
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: searchBarController,
                          decoration: InputDecoration(
                            hintText: 'ジャンルや店名で検索...',
                            prefixIcon: Icon(Icons.search, color: themeColor),
                            suffixIcon: searchMarkers.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: onClearSearch,
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) {
                            if (value.isNotEmpty) onSearchSubmitted(value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      mini: true,
                      heroTag: 'map_filter',
                      backgroundColor:
                          (filterGenre != null ||
                              filterPrefecture != null ||
                              filterName.isNotEmpty ||
                              filterMinRating != null)
                          ? Colors.redAccent
                          : themeColor,
                      onPressed: onFilterTap,
                      child: const Icon(Icons.filter_list, color: Colors.white),
                    ),
                  ],
                ),
              ),
              _buildFilterChips(),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            mini: true,
            heroTag: 'my_location',
            onPressed: onMyLocationTap,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    if (filterGenre == null &&
        filterPrefecture == null &&
        filterName.isEmpty &&
        filterMinRating == null) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            "絞り込み中: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 2, color: Colors.black)],
            ),
          ),
          if (filterMinRating != null)
            Chip(
              label: Text("${filterMinRating!.toStringAsFixed(0)}点以上"),
              onDeleted: () => onChipDeletedRating(null),
            ),
          if (filterPrefecture != null)
            Chip(
              label: Text(filterPrefecture!),
              onDeleted: () => onChipDeletedPref(null),
            ),
          if (filterGenre != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Chip(
                label: Text(GenreManager().getName(filterGenre!)),
                onDeleted: () => onChipDeletedGenre(null),
              ),
            ),
          if (filterName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Chip(
                label: Text("\"$filterName\""),
                onDeleted: onClearFilters,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ActionChip(
              label: const Text("クリア"),
              onPressed: onClearFilters,
            ),
          ),
        ],
      ),
    );
  }
}
