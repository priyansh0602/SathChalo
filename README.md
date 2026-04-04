# 🚗 SathChalo — Peer-to-Peer Ride Sharing App

> **साथ चलो** — *Ride Together*

A production-ready Flutter ride-sharing app with a real-time **400m corridor matching engine** powered by Supabase + PostGIS.

---

## 🏗️ Architecture

```
lib/
├── core/
│   └── constants/          # AppConstants, AppTheme
├── data/
│   ├── datasources/        # SupabaseDataSource, MapsService, LocationService
│   ├── models/             # ProfileModel, RideModel, BookingModel, LiveLocationModel
│   └── repositories/       # RideRepository, BookingRepository
├── domain/
│   └── entities/           # UserProfile, Ride, Booking, LiveLocation, RouteOption
└── presentation/
    ├── providers/           # Riverpod: MapProvider, RideSearchProvider, DriverProvider
    ├── screens/
    │   ├── auth/            # LoginScreen
    │   ├── home/            # HomeScreen
    │   ├── passenger/       # PassengerSearchScreen
    │   └── driver/          # OfferRideScreen, ActiveRideScreen
    └── widgets/             # MapWidget, RideCard, RouteOptionCard, OtpDisplayWidget, ...
```

---

## ⚙️ Setup Guide

### 1. Clone & Install

```bash
git clone <repo>
cd sathchalo
flutter pub get
```

### 2. Environment Configuration

This project uses `flutter_dotenv` to manage sensitive API keys. You MUST create a `.env` file in the root directory before running the app.

1.  Create a file named `.env` in the root folder.
2.  Add your credentials as follows:
    ```env
    SUPABASE_URL=https://your-project-url.supabase.co
    SUPABASE_ANON_KEY=your-anon-key
    GOOGLE_MAPS_API_KEY=your-google-maps-api-key
    ```
    *(Note: `.env` is listed in `.gitignore` and will not be committed to Git.)*

### 3. Supabase Setup

1. Go to [supabase.com](https://supabase.com) → your project
2. **Database → Extensions** → Enable **PostGIS**
3. Go to **SQL Editor** → paste the full contents of:
   ```
   supabase/migrations/001_initial_schema.sql
   ```
4. Click **Run**

### 3. Google Maps Setup

#### Android
Your API key is already in `android/app/src/main/AndroidManifest.xml`.

Make sure the following APIs are enabled in Google Cloud Console:
- Maps SDK for Android
- Maps SDK for iOS
- Directions API
- Places API
- Geocoding API

#### iOS
Your API key is already in `ios/Runner/AppDelegate.swift` and `Info.plist`.

### 4. Run the App

```bash
# Android
flutter run

# iOS
cd ios && pod install && cd ..
flutter run
```

---

## 🔑 The 400m Corridor Engine

The secret sauce of SathChalo. Here's how it works:

```
Driver publishes route:
  Mumbai Central → Dadar → Bandra → Andheri

PostGIS stores it as a LINESTRING geometry.

Passenger searches:
  Pickup: Near Mahim (which is close to the route)
  Dropoff: Near Vile Parle (also near route)

PostGIS query:
  ST_DWithin(route_geom, pickup_point, 400m) = TRUE
  ST_DWithin(route_geom, dropoff_point, 400m) = TRUE
  → MATCH! ✅
```

The SQL function `find_matching_rides()` handles all of this in a single database call with spatial indexes for sub-10ms response times.

---

## 🎯 Feature Checklist

### Passenger Flow
- [x] Auto-detect current location → pre-fill pickup
- [x] Google Places Autocomplete for destinations
- [x] Real-time 400m corridor matching
- [x] Browse matching rides with driver info
- [x] One-tap booking with seat selection
- [x] Live booking status (Pending → Accepted → In Progress)
- [x] 4-digit OTP display
- [x] Real-time driver location on map

### Driver Flow
- [x] Auto-detect current location as origin
- [x] Destination search with autocomplete
- [x] Google Directions API with 2-3 route alternatives
- [x] Route corridor visualization on map (400m buffer)
- [x] Set seats, price, departure time
- [x] Publish ride to Supabase
- [x] Real-time incoming booking requests
- [x] Accept/Reject passengers
- [x] OTP verification to start ride
- [x] Live location upload every 3 seconds
- [x] End ride

---

## 🗄️ Database Schema

| Table | Purpose |
|-------|---------|
| `profiles` | User info, vehicle details, rating |
| `rides` | Route as PostGIS LineString, seats, price, time |
| `bookings` | Passenger requests, OTP, status |
| `live_locations` | Real-time driver GPS heartbeats |

### Key RPC Functions
| Function | Purpose |
|----------|---------|
| `find_matching_rides()` | 400m corridor spatial query |
| `verify_otp_and_start()` | Atomically verify OTP + start ride |
| `upsert_live_location()` | Driver GPS heartbeat upsert |
| `check_driver_proximity()` | Check if driver is within 400m of pickup |

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `supabase_flutter` | Backend, Auth, Realtime |
| `flutter_riverpod` | State management |
| `google_maps_flutter` | Map rendering |
| `geolocator` | GPS location |
| `flutter_polyline_points` | Decode polylines |
| `pin_code_fields` | OTP input UI |

---

## 🔐 Security

- **RLS (Row Level Security)** enabled on all tables
- Users can only read/write their own data
- Driver authentication verified in all RPC calls
- OTP is single-use (marked `otp_verified = true` after use)

---

## 🚀 Production Checklist

- [ ] Add push notifications (FCM) for booking alerts
- [ ] Add payment gateway (Razorpay)
- [ ] Add in-app chat between driver and passenger
- [ ] Add ride history screen
- [ ] Add profile editing screen
- [ ] Add rating system post-ride
- [ ] Add SOS/safety button
- [ ] Enable Supabase Edge Functions for complex business logic
- [ ] Add deep links for sharing rides

---

## 📞 Support

Built with ❤️ in India. For questions, open an issue.
