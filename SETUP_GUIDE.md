# 🚀 SathChalo — Complete Setup Guide

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Flutter | ≥ 3.13.0 | `flutter --version` |
| Dart | ≥ 3.1.0 | `dart --version` |
| Android Studio / Xcode | Latest | For device/emulator |
| Supabase Account | Free tier OK | [supabase.com](https://supabase.com) |
| Google Cloud Account | Free tier OK | For Maps API |

---

## Step 1: Supabase Setup (5 mins)

### 1a. Enable PostGIS Extension
1. Go to your Supabase project dashboard
2. Navigate to **Database → Extensions**
3. Search for **PostGIS** and click **Enable**

### 1b. Run the Schema Migration
1. Go to **SQL Editor** in your Supabase dashboard
2. Click **New Query**
3. Copy the entire contents of `supabase/migrations/001_initial_schema.sql`
4. Paste and click **Run**

You should see tables created: `profiles`, `rides`, `bookings`, `live_locations`
And functions: `find_matching_rides`, `verify_otp_and_start`, `upsert_live_location`, `check_driver_proximity`

### 1c. Verify Realtime is Enabled
1. Go to **Database → Replication**
2. Confirm `live_locations`, `bookings`, and `rides` tables appear in the publication

---

## Step 2: Google Cloud Setup (10 mins)

### 2a. Enable APIs
Go to [console.cloud.google.com](https://console.cloud.google.com) and enable:
- ✅ Maps SDK for Android
- ✅ Maps SDK for iOS  
- ✅ Directions API
- ✅ Places API (New)
- ✅ Geocoding API

### 2b. Your API Key
Already configured in the project:
```
AIzaSyDRe8FyqxNT7XKfeSDiznm7k2xNkW1advQ
```

**Restrict this key** in production:
- Android apps: restrict to your `com.sathchalo.app` package
- iOS apps: restrict to your bundle ID

---

## Step 3: Flutter Setup (3 mins)

```bash
# 1. Extract the ZIP
unzip sathchalo.zip
cd sathchalo

# 2. Get dependencies
flutter pub get

# 3. iOS only (macOS required)
cd ios && pod install && cd ..
```

---

## Step 4: Run on Device/Emulator

```bash
# Android
flutter run -d android

# iOS Simulator
flutter run -d iPhone

# Check available devices
flutter devices
```

---

## Step 5: Test the App

### As a Passenger:
1. Open app → Tap **Find a Ride**
2. Your location auto-fills as pickup
3. Type a destination (e.g., "Connaught Place")
4. Tap **Find Rides** — the 400m PostGIS query runs
5. Tap a ride card → **Request Free Seat**
6. Wait for driver to accept → OTP appears

### As a Driver:
1. Open app → Tap **Offer Ride**
2. Your location auto-fills as origin
3. Type your destination
4. Select from 2–3 Google Directions route options
5. Set seats, price (or free), departure time
6. Tap **Publish Ride 🚀**
7. See incoming passenger requests in real-time
8. Accept → tap **Verify OTP** → enter passenger's 4-digit code
9. Ride starts!

---

## Architecture Notes

### The 400m Corridor Engine
```sql
-- This is the heart of SathChalo
-- Called every time a passenger searches for rides

SELECT * FROM find_matching_rides(
  pickup_lat  => 28.6139,  -- Passenger pickup
  pickup_lng  => 77.2090,
  dropoff_lat => 28.6280,  -- Passenger destination
  dropoff_lng => 77.2177,
  corridor_meters => 400   -- The magic number
);

-- PostGIS checks:
-- 1. Is pickup within 400m of driver's route? ✓
-- 2. Is dropoff within 400m of driver's route? ✓  
-- 3. Does pickup come BEFORE dropoff on route? ✓
-- → MATCH! Driver listed in results.
```

### Real-time Flow
```
Driver GPS → upsert_live_location() → Supabase Realtime
                                            ↓
Passenger App ← live_locations channel ← WebSocket
                                            ↓
                              Car marker moves on map
```

---

## Customization

### Change the corridor radius
In `lib/core/constants/app_constants.dart`:
```dart
static const int corridorRadiusMeters = 400; // Change to 200, 600, etc.
```

### Change app colors
In `lib/core/constants/app_theme.dart`:
```dart
static const Color accentGreen = Color(0xFF1DB954); // Brand color
```

### Add push notifications
Install `firebase_messaging` and add FCM token to `profiles` table.
Call `_subscribeToFCMTopic(rideId)` when a ride is published.

---

## Common Issues

| Error | Fix |
|-------|-----|
| `PostGIS extension not found` | Enable PostGIS in Supabase Extensions tab |
| `Maps not loading` | Check API key restrictions in Google Cloud Console |
| `Location permission denied` | Allow location in device Settings → Apps → SathChalo |
| `find_matching_rides returns empty` | Check that rides have `status='scheduled'` and `departure_time > NOW()` |
| `OTP verification fails` | Ensure you're logged in as the driver who created the ride |
| `Realtime not updating` | Check Supabase Replication settings include `live_locations` table |

---

## Production Checklist

- [ ] Set up Supabase production project (separate from dev)
- [ ] Restrict Google Maps API keys by app package/bundle ID
- [ ] Enable Supabase Auth email confirmation
- [ ] Add Razorpay/Stripe for payment collection
- [ ] Add FCM push notifications for booking requests
- [ ] Set up Supabase Edge Functions for fare calculation
- [ ] Add proper error logging (Sentry/Crashlytics)
- [ ] Configure ProGuard rules for Android release builds
- [ ] Submit to Play Store / App Store

---

*Built with ❤️ — साथ चलो, Ride Together*
