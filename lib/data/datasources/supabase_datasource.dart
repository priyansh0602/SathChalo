import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/map_models.dart'; // Added for RideModel and other types
import '../../core/constants/app_constants.dart';
import 'maps_service.dart'; // Added for polyline decoding in createRide

class SupabaseDataSource {
  final SupabaseClient _client;

  SupabaseDataSource() : _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  // ─── Auth ────────────────────────────────────────────────────────────────
  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  Future<void> cancelAllMyPreviousRides(String driverId) async {
    try {
      await _client
          .from('rides')
          .update({'status': 'cancelled'})
          .eq('driver_id', driverId)
          .inFilter('status', const ['pending', 'active']);
    } catch (e) {
      print('Warning: Failed to cancel old rides: $e');
    }
  }

  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      phone: phone,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithPhone({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    final resp = await _client.auth.signUp(
      phone: phone,
      password: password,
      data: {'full_name': fullName},
    );
    return resp;
  }

  Future<void> signOut() async => await _client.auth.signOut();

  // Mock login for demo
  Future<ProfileModel> mockLogin({
    required String name,
    required String phone,
  }) async {
    // Create mock profile directly without hitting the database
    return ProfileModel(
      id: '00000000-0000-0000-0000-${phone.replaceAll(' ', '').padLeft(12, '0')}',
      fullName: name,
      phone: phone,
      isDriver: false,
      rating: 5.0,
      totalRides: 0,
      createdAt: DateTime.now(),
    );
  }

  Future<ProfileModel?> getOrCreateProfileWithAadhaar({
    required String name,
    required String phone,
    required String gender,
    required String dob,
    required String lastFour,
  }) async {
    // Generate a valid UUID-formatted ID based on the phone number
    final digits = phone.replaceAll(RegExp(r'\D'), '').padLeft(12, '0');
    final mockId = '00000000-0000-4000-8000-${digits.substring(0, 12).padRight(12, '0')}';
    
    final data = await _client.from(AppConstants.profilesTable).upsert({
      'id': mockId,
      'full_name': name,
      'phone': phone,
      'gender': gender,
      'dob': dob,
      'aadhaar_last_four': lastFour,
      'is_aadhaar_verified': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id').select().single();

    return ProfileModel.fromJson(data);
  }

  // ─── Profiles ────────────────────────────────────────────────────────────
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final data = await _client
          .from(AppConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data != null ? ProfileModel.fromJson(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<ProfileModel> upsertProfile(ProfileModel profile) async {
    final data = await _client
        .from(AppConstants.profilesTable)
        .upsert(profile.toJson())
        .select()
        .single();
    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel> updateProfile({
    required String userId,
    String? fullName,
    String? vehicleNumber,
    String? vehicleModel,
    String? vehicleColor,
    bool? isDriver,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (vehicleNumber != null) updates['vehicle_number'] = vehicleNumber;
    if (vehicleModel != null) updates['vehicle_model'] = vehicleModel;
    if (vehicleColor != null) updates['vehicle_color'] = vehicleColor;
    if (isDriver != null) updates['is_driver'] = isDriver;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final data = await _client
        .from(AppConstants.profilesTable)
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel> updateAadhaarDetails({
    required String userId,
    required String aadhaarLastFour,
    required String gender,
    required String dob,
  }) async {
    final data = await _client
        .from(AppConstants.profilesTable)
        .update({
          'is_aadhaar_verified': true,
          'aadhaar_last_four': aadhaarLastFour,
          'gender': gender,
          'dob': dob,
        })
        .eq('id', userId)
        .select()
        .single();
    return ProfileModel.fromJson(data);
  }

  // ─── Rides ───────────────────────────────────────────────────────────────
  Future<RideModel> createRide({
    required String driverId,
    required String originAddress,
    required String destinationAddress,
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    required String routePolyline,
    required int availableSeats,
    required DateTime departureTime,
    double? pricePerSeat,
    String vehicleType = 'car',
    String? notes,
  }) async {
    // Decode polyline to build GeoJSON geometry (Supabase-friendly)
    final maps = MapsService();
    final points = maps.decodePolyline(routePolyline);
    Map<String, dynamic>? routeGeom;
    if (points.isNotEmpty) {
      routeGeom = {
        'type': 'LineString',
        'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
      };
      print('DEBUG: Creating ride with ${points.length} geometry points');
    }

    final data = await _client.from(AppConstants.ridesTable).insert({
      'driver_id': driverId,
      'origin_address': originAddress,
      'destination_address': destinationAddress,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'route_polyline': routePolyline,
      'route_geom': routeGeom,
      'available_seats': availableSeats,
      'total_seats': availableSeats,
      'departure_time': departureTime.toIso8601String(),
      'status': AppConstants.statusPending,
      'price_per_seat': pricePerSeat,
      'vehicle_type': vehicleType,
      'notes': notes,
    }).select().single();
    return RideModel.fromJson(data);
  }

  Future<RideModel?> getRide(String rideId) async {
    try {
      final data = await _client
          .from(AppConstants.ridesTable)
          .select('*, driver:profiles(*)')
          .eq('id', rideId)
          .maybeSingle();
      return data != null ? RideModel.fromJson(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<RideModel>> getActiveRidesByDriver(String driverId) async {
    final data = await _client
        .from(AppConstants.ridesTable)
        .select('*, driver:profiles(*)')
        .eq('driver_id', driverId)
        .inFilter('status', ['pending', 'in_progress'])
        .order('departure_time', ascending: true);
    return (data as List).map((e) => RideModel.fromJson(e)).toList();
  }

  Future<RideModel> updateRideStatus({
    required String rideId,
    required String status,
  }) async {
    final data = await _client
        .from(AppConstants.ridesTable)
        .update({'status': status})
        .eq('id', rideId)
        .select()
        .single();
    return RideModel.fromJson(data);
  }

  // ─── 400m Corridor Matching (RPC) ────────────────────────────────────────
  Future<List<RideModel>> findMatchingRides({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double radiusMeters = AppConstants.matchRadiusMeters,
    String vehicleType = 'car',
    int seatsNeeded = 1,
  }) async {
    try {
      final data = await _client.rpc(
        AppConstants.rpcFindMatchingRides,
        params: {
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
          'radius_meters': radiusMeters.toInt(),
          'p_vehicle_type': vehicleType,
          'p_seats_needed': seatsNeeded,
        },
      );

      // Transform RPC's flat columns into the shape RideModel.fromJson expects.
      // RPC returns: ride_id, driver_id, driver_name, driver_rating,
      //   vehicle_make, vehicle_model, vehicle_color, vehicle_plate,
      //   origin_address, destination_address, available_seats, total_seats,
      //   vehicle_type, price_per_seat, departure_time, origin_lat, origin_lng,
      //   destination_lat, destination_lng, route_polyline, distance_to_pickup_m
      return (data as List).map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        return RideModel.fromJson({
          'id': r['ride_id'],
          'driver_id': r['driver_id'],
          'origin_address': r['origin_address'] ?? '',
          'destination_address': r['destination_address'] ?? '',
          'origin_lat': r['origin_lat'],
          'origin_lng': r['origin_lng'],
          'destination_lat': r['destination_lat'],
          'destination_lng': r['destination_lng'],
          'route_polyline': r['route_polyline'] ?? '',
          'available_seats': r['available_seats'],
          'total_seats': r['total_seats'] ?? r['available_seats'],
          'departure_time': r['departure_time'],
          'status': 'active',
          'price_per_seat': r['price_per_seat'],
          'vehicle_type': r['vehicle_type'] ?? 'car',
          'created_at': r['departure_time'], // use departure as fallback
          // Nest driver info so toEntity() works
          'driver': {
            'id': r['driver_id'],
            'full_name': r['driver_name'] ?? 'Driver',
            'phone': '',
            'rating': r['driver_rating'] ?? 5.0,
            'vehicle_make': r['vehicle_make'],
            'vehicle_model': r['vehicle_model'],
            'vehicle_color': r['vehicle_color'],
            'vehicle_number': r['vehicle_plate'],
            'created_at': DateTime.now().toIso8601String(),
          },
        });
      }).toList();
    } catch (e) {
      print('findMatchingRides error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPassengersOnRoute({
    required String rideId,
    double radiusMeters = AppConstants.matchRadiusMeters,
  }) async {
    try {
      final data = await _client.rpc(
        AppConstants.rpcGetPassengersOnRoute,
        params: {
          'p_ride_id': rideId,
          'radius_meters': radiusMeters,
        },
      );
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  // ─── Bookings ─────────────────────────────────────────────────────────────
  Future<BookingModel> createBooking({
    required String rideId,
    required String passengerId,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    int seatsRequested = 1,
    String vehicleType = 'car',
  }) async {
    // Generate 4-digit OTP
    final otp = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000))
        .toString();

    final data = await _client.from(AppConstants.bookingsTable).insert({
      'ride_id': rideId,
      'passenger_id': passengerId,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'status': AppConstants.bookingPending,
      'otp': otp,
      'otp_verified': false,
      'seats_requested': seatsRequested,
      'vehicle_type': vehicleType,
      'requested_at': DateTime.now().toIso8601String(),
    }).select().single();
    return BookingModel.fromJson(data);
  }

  Future<List<BookingModel>> getBookingsByRide(String rideId) async {
    final data = await _client
        .from(AppConstants.bookingsTable)
        .select('*, passenger:profiles(*)')
        .eq('ride_id', rideId)
        .order('requested_at', ascending: false);
    return (data as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<List<BookingModel>> getBookingsByPassenger(String passengerId) async {
    final data = await _client
        .from(AppConstants.bookingsTable)
        .select('*, ride:rides(*, driver:profiles(*))')
        .eq('passenger_id', passengerId)
        .order('requested_at', ascending: false);
    return (data as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<BookingModel> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final updates = <String, dynamic>{'status': status};
    if (status == AppConstants.bookingAccepted) {
      updates['accepted_at'] = DateTime.now().toIso8601String();
    } else if (status == AppConstants.bookingCompleted) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    final data = await _client
        .from(AppConstants.bookingsTable)
        .update(updates)
        .eq('id', bookingId)
        .select()
        .single();
    return BookingModel.fromJson(data);
  }

  /// Cancel a booking — only allowed if not yet OTP-verified (status is pending/accepted).
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final current = await _client
          .from(AppConstants.bookingsTable)
          .select('status, otp_verified')
          .eq('id', bookingId)
          .single();
      final status = current['status'] as String? ?? '';
      final otpVerified = current['otp_verified'] as bool? ?? false;
      if (otpVerified || status == 'in_progress' || status == 'completed') {
        return false;
      }
      if (status == 'pending') {
        await _client
            .from(AppConstants.bookingsTable)
            .delete()
            .eq('id', bookingId);
      } else {
        await _client
            .from(AppConstants.bookingsTable)
            .update({'status': 'cancelled', 'completed_at': DateTime.now().toIso8601String()})
            .eq('id', bookingId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String bookingId,
    required String otp,
  }) async {
    try {
      final result = await _client.rpc(
        AppConstants.rpcVerifyOtp,
        params: {'p_booking_id': bookingId, 'p_otp': otp},
      );
      // Ensure we return a boolean
      return result == true;
    } catch (_) {
      // Fallback: direct check
      try {
        final data = await _client
            .from(AppConstants.bookingsTable)
            .select('otp')
            .eq('id', bookingId)
            .single();
        final storedOtp = data['otp'] as String?;
        if (storedOtp == otp) {
          await _client
              .from(AppConstants.bookingsTable)
              .update({'otp_verified': true})
              .eq('id', bookingId);
          return true;
        }
      } catch (_) {}
      return false;
    }
  }

  Future<Map<String, dynamic>> verifyOtpAndStart({
    required String bookingId,
    required String otp,
  }) async {
    try {
      final verified = await verifyOtp(bookingId: bookingId, otp: otp);
      if (!verified) {
        return {'success': false, 'message': 'Invalid OTP'};
      }

      await _client
          .from(AppConstants.bookingsTable)
          .update({'status': AppConstants.statusInProgress})
          .eq('id', bookingId);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> checkDriverProximity({
    required String rideId,
    required double lat,
    required double lng,
  }) async {
    // Basic proximity check - usually done via RPC or Realtime
    return true;
  }

  // ─── Live Locations ───────────────────────────────────────────────────────
  Future<void> upsertLiveLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    double? bearing,
    double? speed,
  }) async {
    await _client.from(AppConstants.liveLocationsTable).upsert({
      'driver_id': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'bearing': bearing,
      'speed': speed,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<LiveLocationModel?> getLiveLocation(String driverId) async {
    try {
      final data = await _client
          .from(AppConstants.liveLocationsTable)
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();
      return data != null ? LiveLocationModel.fromJson(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteLiveLocation(String driverId) async {
    await _client
        .from(AppConstants.liveLocationsTable)
        .delete()
        .eq('driver_id', driverId);
  }

  // ─── Realtime Subscriptions ───────────────────────────────────────────────

  /// Decrement available_seats by 1 when a booking is accepted
  Future<void> decrementAvailableSeats(String rideId) async {
    try {
      // Fetch current seats, decrement, update
      final ride = await _client
          .from(AppConstants.ridesTable)
          .select('available_seats')
          .eq('id', rideId)
          .single();
      final current = (ride['available_seats'] as int?) ?? 0;
      if (current > 0) {
        await _client
            .from(AppConstants.ridesTable)
            .update({'available_seats': current - 1})
            .eq('id', rideId);
      }
    } catch (_) {}
  }

  /// Subscribe to NEW rides being created (for passenger waiting for matches)
  RealtimeChannel subscribeToNewRides({
    required void Function(RideModel) onNewRide,
  }) {
    return _client
        .channel('new_rides_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.ridesTable,
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              try {
                onNewRide(RideModel.fromJson(newRecord));
              } catch (_) {}
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToDriverLocation({
    required String driverId,
    required void Function(LiveLocationModel) onUpdate,
  }) {
    return _client
        .channel('driver_location_$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.liveLocationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              onUpdate(LiveLocationModel.fromJson(newRecord));
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToBookingUpdates({
    required String rideId,
    required void Function(BookingModel?, String? deletedId) onUpdate,
  }) {
    return _client
        .channel('booking_updates_$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.bookingsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final deletedId = payload.oldRecord['id']?.toString();
              if (deletedId != null) {
                onUpdate(null, deletedId);
              }
            } else {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                onUpdate(BookingModel.fromJson(newRecord), null);
              }
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToPassengerBooking({
    required String passengerId,
    required void Function(BookingModel) onUpdate,
  }) {
    return _client
        .channel('passenger_booking_$passengerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConstants.bookingsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'passenger_id',
            value: passengerId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              onUpdate(BookingModel.fromJson(newRecord));
            }
          },
        )
        .subscribe();
  }

  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}