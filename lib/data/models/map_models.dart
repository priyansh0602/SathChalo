import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  String get fullText => '$mainText, $secondaryText';

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'] ?? '',
      mainText: json['structured_formatting']?['main_text'] ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] ?? '',
    );
  }
}

class RouteOption {
  final int index;
  final String summary;
  final String encodedPolyline;
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final int distanceValue;
  final int durationValue;

  RouteOption({
    required this.index,
    required this.summary,
    required this.encodedPolyline,
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.distanceValue,
    required this.durationValue,
  });

  factory RouteOption.fromDirectionsLeg(Map<String, dynamic> json, int index) {
    final leg = json['legs'][0] as Map<String, dynamic>;
    final polyline = json['overview_polyline']['points'] as String;
    final summary = json['summary'] as String? ?? '';

    return RouteOption(
      index: index,
      summary: summary,
      encodedPolyline: polyline,
      polylinePoints: _decodePolyline(polyline),
      distance: leg['distance']['text'] ?? '',
      duration: leg['duration']['text'] ?? '',
      distanceValue: leg['distance']['value'] ?? 0,
      durationValue: leg['duration']['value'] ?? 0,
    );
  }

  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
