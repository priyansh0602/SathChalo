-- ============================================================
-- SathChalo: Full PostGIS Schema Migration (PROTOTYPE VERSION)
-- ============================================================

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. TEARDOWN (Clean Start)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.check_driver_proximity(UUID, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS public.upsert_live_location(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.verify_otp_and_start(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.find_matching_rides(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, TEXT, INTEGER) CASCADE;

DROP TABLE IF EXISTS public.live_locations CASCADE;
DROP TABLE IF EXISTS public.bookings CASCADE;
DROP TABLE IF EXISTS public.rides CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. PROFILES TABLE
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY, 
  full_name TEXT NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  rating NUMERIC(3,2) DEFAULT 5.0,
  is_driver BOOLEAN DEFAULT FALSE,
  vehicle_make TEXT,
  vehicle_model TEXT,
  vehicle_color TEXT,
  vehicle_plate TEXT,
  is_aadhaar_verified BOOLEAN DEFAULT FALSE,
  aadhaar_last_four TEXT,
  gender TEXT,
  dob TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. RIDES TABLE
CREATE TABLE public.rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL, 
  origin_address TEXT NOT NULL,
  destination_address TEXT NOT NULL,
  origin_lat DOUBLE PRECISION NOT NULL,
  origin_lng DOUBLE PRECISION NOT NULL,
  destination_lat DOUBLE PRECISION NOT NULL,
  destination_lng DOUBLE PRECISION NOT NULL,
  route_polyline TEXT NOT NULL,
  route_geom GEOMETRY(LINESTRING, 4326),
  available_seats INTEGER NOT NULL DEFAULT 3,
  total_seats INTEGER NOT NULL DEFAULT 4,
  vehicle_type TEXT NOT NULL DEFAULT 'car',
  price_per_seat NUMERIC(10,2) DEFAULT 0,
  notes TEXT,
  departure_time TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. BOOKINGS TABLE
CREATE TABLE public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  passenger_id UUID NOT NULL,
  pickup_address TEXT NOT NULL,
  dropoff_address TEXT NOT NULL,
  pickup_lat DOUBLE PRECISION NOT NULL,
  pickup_lng DOUBLE PRECISION NOT NULL,
  dropoff_lat DOUBLE PRECISION NOT NULL,
  dropoff_lng DOUBLE PRECISION NOT NULL,
  otp_code TEXT NOT NULL DEFAULT LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'),
  otp_verified BOOLEAN DEFAULT FALSE,
  seats_requested INTEGER NOT NULL DEFAULT 1,
  vehicle_type TEXT NOT NULL DEFAULT 'car',
  fare_amount NUMERIC(10,2) DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  requested_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. LIVE LOCATIONS TABLE
CREATE TABLE public.live_locations (
  user_id UUID PRIMARY KEY,
  ride_id UUID REFERENCES public.rides(id) ON DELETE SET NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  heading DOUBLE PRECISION DEFAULT 0,
  speed DOUBLE PRECISION DEFAULT 0,
  location GEOMETRY(POINT, 4326),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. INDEXES
CREATE INDEX IF NOT EXISTS rides_geom_idx ON public.rides USING GIST (route_geom);
CREATE INDEX IF NOT EXISTS live_locations_geom_idx ON public.live_locations USING GIST (location);

-- 7. RLS POLICIES (Relaxed for prototype)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public Profiles Access" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Public Profiles Insert" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Profiles Update" ON public.profiles FOR UPDATE USING (true);

CREATE POLICY "Public Rides Access" ON public.rides FOR SELECT USING (true);
CREATE POLICY "Public Rides Insert" ON public.rides FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Rides Update" ON public.rides FOR UPDATE USING (true);

CREATE POLICY "Public Bookings Access" ON public.bookings FOR SELECT USING (true);
CREATE POLICY "Public Bookings Insert" ON public.bookings FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Bookings Update" ON public.bookings FOR UPDATE USING (true);

CREATE POLICY "Public Locations Access" ON public.live_locations FOR SELECT USING (true);
CREATE POLICY "Public Locations Ins/Upd" ON public.live_locations FOR ALL USING (true);

-- 8. POSTGIS FUNCTIONS
CREATE OR REPLACE FUNCTION public.find_matching_rides(
  pickup_lat DOUBLE PRECISION, pickup_lng DOUBLE PRECISION,
  dropoff_lat DOUBLE PRECISION, dropoff_lng DOUBLE PRECISION,
  radius_meters INTEGER DEFAULT 400,
  p_vehicle_type TEXT DEFAULT 'car',
  p_seats_needed INTEGER DEFAULT 1
) RETURNS TABLE (
  ride_id UUID, driver_id UUID, driver_name TEXT, driver_rating NUMERIC,
  vehicle_make TEXT, vehicle_model TEXT, vehicle_color TEXT, vehicle_plate TEXT,
  origin_address TEXT, destination_address TEXT, available_seats INTEGER,
  total_seats INTEGER, vehicle_type TEXT, price_per_seat NUMERIC,
  departure_time TIMESTAMPTZ, origin_lat DOUBLE PRECISION, origin_lng DOUBLE PRECISION,
  destination_lat DOUBLE PRECISION, destination_lng DOUBLE PRECISION,
  route_polyline TEXT, distance_to_pickup_m DOUBLE PRECISION
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  pickup_point GEOMETRY := ST_SetSRID(ST_MakePoint(pickup_lng, pickup_lat), 4326);
  dropoff_point GEOMETRY := ST_SetSRID(ST_MakePoint(dropoff_lng, dropoff_lat), 4326);
BEGIN
  RETURN QUERY
  SELECT
    r.id, r.driver_id, p.full_name, p.rating,
    p.vehicle_make, p.vehicle_model, p.vehicle_color, p.vehicle_plate,
    r.origin_address, r.destination_address, r.available_seats,
    r.total_seats, r.vehicle_type, r.price_per_seat,
    r.departure_time, r.origin_lat, r.origin_lng,
    r.destination_lat, r.destination_lng, r.route_polyline,
    ST_Distance(ST_SetSRID(ST_MakePoint(r.origin_lng, r.origin_lat), 4326)::geography, pickup_point::geography)
  FROM public.rides r
  JOIN public.profiles p ON p.id = r.driver_id
  WHERE r.status IN ('pending', 'active', 'in_progress')
    AND r.available_seats >= p_seats_needed
    AND r.vehicle_type = p_vehicle_type
    AND ST_DWithin(r.route_geom::geography, pickup_point::geography, radius_meters)
    AND ST_DWithin(r.route_geom::geography, dropoff_point::geography, radius_meters)
  ORDER BY 21 ASC LIMIT 20;
END; $$;

-- 9. TRIGGERS
CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_rides_updated_at BEFORE UPDATE ON public.rides FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_bookings_updated_at BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
