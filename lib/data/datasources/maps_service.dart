import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/profile_model.dart';
import '../models/map_models.dart';

class MapsService {
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  // ─── Location Permission & Current Position ──────────────────────────────
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    );
  }

  // ─── Reverse Geocoding (auto-fill pickup) ─────────────────────────────────
  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        '${AppConstants.geocodeBaseUrl}'
        '?latlng=$lat,$lng'
        '&key=${AppConstants.googleMapsApiKey}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = json['results'] as List?;
        if (results != null && results.isNotEmpty) {
          // Prefer short formatted address (locality level)
          for (final result in results) {
            final types = (result['types'] as List).cast<String>();
            if (types.contains('sublocality') ||
                types.contains('neighborhood') ||
                types.contains('locality')) {
              return result['formatted_address'] as String;
            }
          }
          return results.first['formatted_address'] as String;
        }
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  // ─── Places Autocomplete ──────────────────────────────────────────────────
  Future<List<PlaceSuggestion>> getPlaceSuggestions({
    required String input,
    LatLng? biasLocation,
    String components = 'country:in',
  }) async {
    if (input.trim().length < 2) return [];
    try {
      String url =
          '${AppConstants.placesBaseUrl}'
          '?input=${Uri.encodeComponent(input)}'
          '&key=${AppConstants.googleMapsApiKey}'
          '&components=$components'
          '&language=en';

      if (biasLocation != null) {
        url +=
            '&location=${biasLocation.latitude},${biasLocation.longitude}&radius=50000';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = json['predictions'] as List? ?? [];
        return predictions
            .map((p) => PlaceSuggestion.fromJson(p as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Place Details (lat/lng from placeId) ─────────────────────────────────
  Future<LatLng?> getPlaceLatLng(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=${AppConstants.googleMapsApiKey}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = json['result'] as Map<String, dynamic>?;
        final location =
            (result?['geometry'] as Map<String, dynamic>?)?['location']
                as Map<String, dynamic>?;
        if (location != null) {
          return LatLng(
            (location['lat'] as num).toDouble(),
            (location['lng'] as num).toDouble(),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── Directions API (route options) ───────────────────────────────────────
  Future<List<RouteOption>> getRouteOptions({
    required LatLng origin,
    required LatLng destination,
    int alternatives = 3,
  }) async {
    try {
      final url = Uri.parse(
        '${AppConstants.directionsBaseUrl}'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&alternatives=${alternatives > 1}'
        '&key=${AppConstants.googleMapsApiKey}'
        '&mode=driving'
        '&region=in',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = json['routes'] as List? ?? [];
        return routes
            .take(3)
            .toList() // Convert to list to use asMap
            .asMap()
            .entries
            .map((e) => RouteOption.fromDirectionsLeg(
                e.value as Map<String, dynamic>, e.key))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Distance Matrix API (ETA) ─────────────────────────────────────────
  Future<Map<String, String>> getEstimatedPickupTime({
    required LatLng driverLocation,
    required LatLng passengerPickup,
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${driverLocation.latitude},${driverLocation.longitude}'
        '&destinations=${passengerPickup.latitude},${passengerPickup.longitude}'
        '&mode=driving'
        '&key=${AppConstants.googleMapsApiKey}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final rows = json['rows'] as List?;
        if (rows != null && rows.isNotEmpty) {
          final elements = rows[0]['elements'] as List?;
          if (elements != null && elements.isNotEmpty) {
            final element = elements[0] as Map<String, dynamic>;
            if (element['status'] == 'OK') {
              return {
                'duration': element['duration']['text'] as String,
                'distance': element['distance']['text'] as String,
                'durationValue': element['duration']['value'].toString(),
                'distanceValue': element['distance']['value'].toString(),
              };
            }
          }
        }
      }
    } catch (_) {}
    return {'duration': '—', 'distance': '—'};
  }

  // ─── Decode Polyline ──────────────────────────────────────────────────────
  List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // ─── Distance Calculation ─────────────────────────────────────────────────
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  bool isWithinRadius(LatLng point, LatLng center, double radiusMeters) {
    return calculateDistance(point, center) <= radiusMeters;
  }

  // ─── 400m Corridor Check (client-side) ────────────────────────────────────
  /// Checks if a given point is within [radiusMeters] of ANY segment
  /// of the decoded polyline. This mirrors the PostGIS buffer logic on client.
  bool isPointNearPolyline({
    required LatLng point,
    required List<LatLng> polylinePoints,
    double radiusMeters = AppConstants.matchRadiusMeters,
  }) {
    for (int i = 0; i < polylinePoints.length - 1; i++) {
      final dist = _distanceToSegment(
        point,
        polylinePoints[i],
        polylinePoints[i + 1],
      );
      if (dist <= radiusMeters) return true;
    }
    return false;
  }

  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    // Convert to approximate planar coordinates (valid for small distances)
    final double lat1 = a.latitude * pi / 180;
    final double lat2 = b.latitude * pi / 180;
    final double latP = p.latitude * pi / 180;

    final double x1 = a.longitude * cos(lat1);
    final double y1 = a.latitude;
    final double x2 = b.longitude * cos(lat2);
    final double y2 = b.latitude;
    final double xP = p.longitude * cos(latP);
    final double yP = p.latitude;

    final double dx = x2 - x1;
    final double dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      return Geolocator.distanceBetween(
          p.latitude, p.longitude, a.latitude, a.longitude);
    }

    double t = ((xP - x1) * dx + (yP - y1) * dy) / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);

    final double closestLng = a.longitude + t * (b.longitude - a.longitude);
    final double closestLat = a.latitude + t * (b.latitude - a.latitude);

    return Geolocator.distanceBetween(
        p.latitude, p.longitude, closestLat, closestLng);
  }

  // ─── Map Bounds ───────────────────────────────────────────────────────────
  LatLngBounds boundsFromLatLngList(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south - 0.005, west - 0.005),
      northeast: LatLng(north + 0.005, east + 0.005),
    );
  }

  // ─── Custom Map Style (dark/light) ───────────────────────────────────────
  static const String uberMapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
    {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
    {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},
    {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},
    {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
    {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
    {"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},
    {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]}
  ]''';

  // ─── Bearing calculation ──────────────────────────────────────────────────
  double calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  // ─── Marker creation helpers ──────────────────────────────────────────────
  Marker createDriverMarker({
    required String driverId,
    required LatLng position,
    double rotation = 0,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: MarkerId('driver_$driverId'),
      position: position,
      rotation: rotation,
      anchor: const Offset(0.5, 0.5),
      infoWindow: const InfoWindow(title: 'Driver'),
      onTap: onTap,
    );
  }

  Marker createPickupMarker({
    required LatLng position,
    required String label,
  }) {
    return Marker(
      markerId: const MarkerId('pickup'),
      position: position,
      infoWindow: InfoWindow(title: label),
    );
  }

  Marker createDropoffMarker({
    required LatLng position,
    required String label,
  }) {
    return Marker(
      markerId: const MarkerId('dropoff'),
      position: position,
      infoWindow: InfoWindow(title: label),
    );
  }

  Polyline createRoutePolyline({
    required List<LatLng> points,
    Color color = Colors.black,
    double width = 5,
    String id = 'route',
  }) {
    return Polyline(
      polylineId: PolylineId(id),
      color: color,
      width: width.toInt(),
      points: points,
      patterns: [],
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
  }
}