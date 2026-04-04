// lib/presentation/widgets/map_widget.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_theme.dart';

class MapWidget extends StatelessWidget {
  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final void Function(GoogleMapController)? onMapCreated;
  final double zoom;

  const MapWidget({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.circles = const {},
    this.onMapCreated,
    this.zoom = 15,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: zoom,
      ),
      onMapCreated: onMapCreated,
      markers: markers,
      polylines: polylines,
      circles: circles,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      style: AppTheme.mapStyle,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: false,
    );
  }
}
