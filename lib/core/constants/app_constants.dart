import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Supabase
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey =>
      dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  // Google Maps
  static String get googleMapsApiKey =>
      dotenv.get('GOOGLE_MAPS_API_KEY', fallback: '');

  // App
  static const String appName = 'SathChalo';
  static const double matchRadiusMeters = 400.0;
  static const int otpLength = 4;
  static const int locationHeartbeatSeconds = 3;

  // Map defaults (Delhi)
  static const double defaultLat = 28.6139;
  static const double defaultLng = 77.2090;
  static const double defaultZoom = 14.0;

  // Supabase table names
  static const String profilesTable = 'profiles';
  static const String ridesTable = 'rides';
  static const String bookingsTable = 'bookings';
  static const String liveLocationsTable = 'live_locations';

  // Supabase RPC functions
  static const String rpcFindMatchingRides = 'find_matching_rides';
  static const String rpcVerifyOtp = 'verify_booking_otp';
  static const String rpcGetPassengersOnRoute = 'get_passengers_on_route';

  // Ride status
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  // Booking status
  static const String bookingPending = 'pending';
  static const String bookingAccepted = 'accepted';
  static const String bookingRejected = 'rejected';
  static const String bookingCompleted = 'completed';

  // Google Directions
  static const String directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const String placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String geocodeBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  // Error messages
  static const String errorLocationPermission =
      'Location permission is required to use SathChalo.';
  static const String errorNoInternet =
      'No internet connection. Please check your network.';
  static const String errorGeneric =
      'Something went wrong. Please try again.';
}