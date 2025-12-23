-- ==========================================
-- DRIVO COMPLETE DATABASE SCHEMA (FRESH START)
-- Properly integrated with Supabase Auth
-- ==========================================
-- 
-- This schema correctly uses:
-- - profiles (linked to auth.users) instead of users
-- - driver_profiles (linked to auth.users) instead of drivers
-- 
-- Run this in Supabase SQL Editor for a fresh database.
-- ==========================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- ENUMS
-- ==========================================

CREATE TYPE kyc_status AS ENUM ('pending', 'submitted', 'in_review', 'verified', 'rejected');
CREATE TYPE driver_status AS ENUM ('offline', 'online', 'busy', 'on_trip');
CREATE TYPE booking_status AS ENUM ('searching', 'confirmed', 'arrived', 'in_progress', 'returning', 'completed', 'cancelled');
CREATE TYPE trip_type AS ENUM ('round_trip', 'one_way', 'hourly', 'outstation');
CREATE TYPE return_model AS ENUM ('round_trip', 'platform_return', 'zone_based');
CREATE TYPE trip_phase AS ENUM (
    'searching_driver', 'driver_assigned', 'driver_en_route', 'driver_arrived',
    'trip_started', 'at_destination', 'return_journey_started', 'trip_completed', 'trip_cancelled'
);
CREATE TYPE ride_timing_mode AS ENUM ('now', 'tomorrow', 'scheduled');
CREATE TYPE payment_method_type AS ENUM ('cash', 'upi', 'card', 'wallet', 'net_banking');
CREATE TYPE payment_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'refunded');
CREATE TYPE billing_state AS ENUM ('not_started', 'driving', 'waiting', 'over_waiting', 'returning', 'completed');
CREATE TYPE transmission_type AS ENUM ('manual', 'automatic');
CREATE TYPE car_category AS ENUM ('hatchback', 'sedan', 'compact_suv', 'mid_suv', 'mpv', 'electric');
CREATE TYPE leg_type AS ENUM ('onward', 'return');
CREATE TYPE stop_type AS ENUM ('pickup', 'destination', 'waypoint');
CREATE TYPE alert_type AS ENUM ('sos', 'route_deviation', 'long_stop', 'speed_alert', 'geofence_exit');
CREATE TYPE geofence_event_type AS ENUM ('enter', 'exit', 'dwell');
CREATE TYPE return_task_status AS ENUM ('pending', 'pooling', 'cab_booked', 'in_transit', 'completed', 'cancelled');

-- Rental specific enums
CREATE TYPE rental_booking_status AS ENUM ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled');
CREATE TYPE car_listing_status AS ENUM ('draft', 'pending_approval', 'active', 'paused', 'rejected', 'deleted');
CREATE TYPE ride_booking_status AS ENUM ('idle', 'searching', 'driver_assigned', 'driver_en_route', 'driver_arrived', 'trip_in_progress', 'trip_completed', 'cancelled');
CREATE TYPE ride_vehicle_type AS ENUM ('bike', 'auto', 'mini', 'sedan', 'suv');

-- ==========================================
-- PROFILES TABLE (linked to auth.users)
-- ==========================================

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone VARCHAR(20) UNIQUE,
    email VARCHAR(255),
    name VARCHAR(100),
    photo_url TEXT,
    kyc_status kyc_status DEFAULT 'pending',
    is_first_time_user BOOLEAN DEFAULT TRUE,
    total_trips INTEGER DEFAULT 0,
    total_spent DECIMAL(12, 2) DEFAULT 0,
    rating DECIMAL(2, 1),
    wallet_balance DECIMAL(10, 2) DEFAULT 0,
    city_code VARCHAR(10) DEFAULT 'BLR',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- ==========================================
-- DRIVER PROFILES TABLE (linked to auth.users)
-- ==========================================

CREATE TABLE driver_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(255),
    name VARCHAR(100) NOT NULL,
    photo_url TEXT,
    rating DECIMAL(2, 1) DEFAULT 4.5,
    total_trips INTEGER DEFAULT 0,
    total_earnings DECIMAL(12, 2) DEFAULT 0,
    kyc_status kyc_status DEFAULT 'pending',
    status driver_status DEFAULT 'offline',
    accepts_platform_return BOOLEAN DEFAULT TRUE,
    current_lat DECIMAL(10, 7),
    current_lng DECIMAL(10, 7),
    current_heading DECIMAL(5, 2),
    last_location_update TIMESTAMPTZ,
    city_code VARCHAR(10) DEFAULT 'BLR',
    bank_account_number VARCHAR(30),
    bank_ifsc VARCHAR(20),
    bank_account_holder VARCHAR(100),
    next_payout_date DATE,
    pending_payout DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- ==========================================
-- AUTO-CREATE PROFILE TRIGGER
-- ==========================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, phone, email, name, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.phone,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', ''),
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- CAR TYPES (Configuration)
-- ==========================================

CREATE TABLE car_types (
    id VARCHAR(50) PRIMARY KEY,
    category car_category NOT NULL,
    transmission transmission_type NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    example_models TEXT[],
    price_per_hour DECIMAL(8, 2) NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    unavailable_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- SERVICE ZONES
-- ==========================================

CREATE TABLE service_zones (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city_code VARCHAR(10) NOT NULL,
    boundary JSONB NOT NULL,
    adjacent_zone_ids TEXT[],
    pooling_enabled BOOLEAN DEFAULT FALSE,
    max_idle_minutes INTEGER DEFAULT 15,
    pooling_discount DECIMAL(4, 2) DEFAULT 0.10,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- BOOKINGS (Driver Hire)
-- ==========================================

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES profiles(id),
    driver_id UUID REFERENCES driver_profiles(id),
    status booking_status DEFAULT 'searching',
    service_type VARCHAR(50) NOT NULL,
    trip_type trip_type DEFAULT 'round_trip',
    timing_mode ride_timing_mode DEFAULT 'now',
    scheduled_time TIMESTAMPTZ,
    car_type_id VARCHAR(50) REFERENCES car_types(id),
    transmission transmission_type,
    
    -- Locations
    pickup_address TEXT NOT NULL,
    pickup_lat DECIMAL(10, 7) NOT NULL,
    pickup_lng DECIMAL(10, 7) NOT NULL,
    destination_address TEXT,
    destination_lat DECIMAL(10, 7),
    destination_lng DECIMAL(10, 7),
    
    -- Route info
    estimated_distance_km DECIMAL(8, 2),
    estimated_duration_min DECIMAL(8, 2),
    route_polyline TEXT,
    
    -- Return model
    return_model return_model DEFAULT 'round_trip',
    zone_id VARCHAR(50) REFERENCES service_zones(id),
    return_car_to_pickup BOOLEAN DEFAULT FALSE,
    
    -- Pricing
    base_fare DECIMAL(10, 2),
    estimated_driving_hours DECIMAL(5, 2) DEFAULT 2,
    declared_waiting_hours DECIMAL(5, 2) DEFAULT 0,
    hourly_rate DECIMAL(8, 2) DEFAULT 199,
    estimated_total DECIMAL(10, 2),
    payment_method payment_method_type DEFAULT 'cash',
    
    -- OTP & timestamps
    otp VARCHAR(6),
    booked_at TIMESTAMPTZ DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    driver_arrived_at TIMESTAMPTZ,
    trip_started_at TIMESTAMPTZ,
    trip_ended_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- ==========================================
-- TRIP STOPS
-- ==========================================

CREATE TABLE trip_stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    leg_type leg_type NOT NULL,
    stop_type stop_type NOT NULL,
    sequence_order INTEGER NOT NULL,
    address TEXT NOT NULL,
    lat DECIMAL(10, 7) NOT NULL,
    lng DECIMAL(10, 7) NOT NULL,
    arrived_at TIMESTAMPTZ,
    departed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- TRIP RETURN INFO
-- ==========================================

CREATE TABLE trip_return_info (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
    model return_model NOT NULL,
    current_phase trip_phase DEFAULT 'trip_started',
    return_fee DECIMAL(10, 2),
    return_started_at TIMESTAMPTZ,
    return_completed_at TIMESTAMPTZ,
    return_destination_lat DECIMAL(10, 7),
    return_destination_lng DECIMAL(10, 7),
    return_task_id UUID,
    next_job_id UUID,
    is_return_complete BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- RETURN TASKS
-- ==========================================

CREATE TABLE return_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id),
    from_lat DECIMAL(10, 7) NOT NULL,
    from_lng DECIMAL(10, 7) NOT NULL,
    from_address TEXT NOT NULL,
    status return_task_status DEFAULT 'pending',
    cab_booking_id VARCHAR(100),
    reimbursement_amount DECIMAL(10, 2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- LIVE BILLING
-- ==========================================

CREATE TABLE live_billing (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
    state billing_state DEFAULT 'not_started',
    declared_waiting_minutes INTEGER DEFAULT 0,
    trip_start_time TIMESTAMPTZ,
    waiting_start_time TIMESTAMPTZ,
    over_wait_start_time TIMESTAMPTZ,
    return_start_time TIMESTAMPTZ,
    trip_end_time TIMESTAMPTZ,
    actual_driving_minutes INTEGER DEFAULT 0,
    actual_waiting_minutes INTEGER DEFAULT 0,
    over_wait_minutes INTEGER DEFAULT 0,
    return_minutes INTEGER DEFAULT 0,
    driving_charge DECIMAL(10, 2) DEFAULT 0,
    waiting_charge DECIMAL(10, 2) DEFAULT 0,
    over_wait_charge DECIMAL(10, 2) DEFAULT 0,
    return_fee DECIMAL(10, 2) DEFAULT 0,
    subtotal DECIMAL(10, 2) DEFAULT 0,
    total_fare DECIMAL(10, 2) DEFAULT 0,
    driver_driving_earnings DECIMAL(10, 2) DEFAULT 0,
    driver_waiting_earnings DECIMAL(10, 2) DEFAULT 0,
    driver_total_earnings DECIMAL(10, 2) DEFAULT 0,
    platform_margin DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- PAYMENTS
-- ==========================================

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    user_id UUID NOT NULL REFERENCES profiles(id),
    amount DECIMAL(10, 2) NOT NULL,
    method payment_method_type NOT NULL,
    status payment_status DEFAULT 'pending',
    transaction_id VARCHAR(100),
    gateway_response JSONB,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- SAVED PAYMENT METHODS
-- ==========================================

CREATE TABLE saved_payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    method_type payment_method_type NOT NULL,
    card_type VARCHAR(20),
    last_four VARCHAR(4),
    expiry_month INTEGER,
    expiry_year INTEGER,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- WALLET TRANSACTIONS
-- ==========================================

CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    booking_id UUID REFERENCES bookings(id),
    amount DECIMAL(10, 2) NOT NULL,
    transaction_type VARCHAR(30) NOT NULL,
    description TEXT,
    balance_after DECIMAL(10, 2) NOT NULL,
    payment_id UUID REFERENCES payments(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- SAVED LOCATIONS
-- ==========================================

CREATE TABLE saved_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    location_type VARCHAR(30) NOT NULL,
    label VARCHAR(50),
    address TEXT NOT NULL,
    lat DECIMAL(10, 7) NOT NULL,
    lng DECIMAL(10, 7) NOT NULL,
    icon VARCHAR(50),
    is_set BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- RECENT DESTINATIONS
-- ==========================================

CREATE TABLE recent_destinations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    address TEXT NOT NULL,
    short_name VARCHAR(100),
    lat DECIMAL(10, 7) NOT NULL,
    lng DECIMAL(10, 7) NOT NULL,
    visit_count INTEGER DEFAULT 1,
    last_visited_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, lat, lng)
);

-- ==========================================
-- SEARCH HISTORY
-- ==========================================

CREATE TABLE search_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    search_query TEXT NOT NULL,
    result_place_id VARCHAR(100),
    result_address TEXT,
    result_lat DECIMAL(10, 7),
    result_lng DECIMAL(10, 7),
    search_type VARCHAR(20) DEFAULT 'destination',
    searched_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- DRIVER LOCATION HISTORY
-- ==========================================

CREATE TABLE driver_location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    booking_id UUID REFERENCES bookings(id),
    lat DECIMAL(10, 7) NOT NULL,
    lng DECIMAL(10, 7) NOT NULL,
    heading DECIMAL(5, 2),
    speed DECIMAL(6, 2),
    accuracy DECIMAL(6, 2),
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- TRIP TRAIL
-- ==========================================

CREATE TABLE trip_trail (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    lat DECIMAL(10, 7) NOT NULL,
    lng DECIMAL(10, 7) NOT NULL,
    speed DECIMAL(6, 2),
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- SAFETY ALERTS
-- ==========================================

CREATE TABLE safety_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    driver_id UUID REFERENCES driver_profiles(id),
    alert_type alert_type NOT NULL,
    message TEXT NOT NULL,
    lat DECIMAL(10, 7) NOT NULL,
    lng DECIMAL(10, 7) NOT NULL,
    metadata JSONB,
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- EMERGENCY CONTACTS
-- ==========================================

CREATE TABLE emergency_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    relation VARCHAR(50),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- GEOFENCE EVENTS
-- ==========================================

CREATE TABLE geofence_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    geofence_id VARCHAR(50) NOT NULL,
    event_type geofence_event_type NOT NULL,
    lat DECIMAL(10, 7) NOT NULL,
    lng DECIMAL(10, 7) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- GEOFENCE CONFIGS
-- ==========================================

CREATE TABLE geofence_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    geofence_type VARCHAR(30) NOT NULL,
    boundary JSONB NOT NULL,
    center_lat DECIMAL(10, 7),
    center_lng DECIMAL(10, 7),
    radius_meters DECIMAL(10, 2),
    city_code VARCHAR(10),
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- RATINGS
-- ==========================================

CREATE TABLE ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id),
    user_id UUID NOT NULL REFERENCES profiles(id),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    feedback TEXT,
    feedback_tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- SUPPORT TICKETS
-- ==========================================

CREATE TABLE support_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id),
    driver_id UUID REFERENCES driver_profiles(id),
    booking_id UUID REFERENCES bookings(id),
    category VARCHAR(50) NOT NULL,
    subject VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'open',
    priority VARCHAR(20) DEFAULT 'normal',
    assigned_to UUID,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- NOTIFICATIONS
-- ==========================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id),
    driver_id UUID REFERENCES driver_profiles(id),
    booking_id UUID REFERENCES bookings(id),
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50),
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- PUSH TOKENS
-- ==========================================

CREATE TABLE push_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- DRIVER EARNINGS
-- ==========================================

CREATE TABLE driver_earnings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    booking_id UUID REFERENCES bookings(id),
    date DATE NOT NULL,
    trip_earnings DECIMAL(10, 2) DEFAULT 0,
    bonus_earnings DECIMAL(10, 2) DEFAULT 0,
    total_earnings DECIMAL(10, 2) DEFAULT 0,
    trip_duration_minutes INTEGER DEFAULT 0,
    online_hours DECIMAL(5, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- DRIVER BONUSES
-- ==========================================

CREATE TABLE driver_bonuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    amount DECIMAL(10, 2) NOT NULL,
    bonus_type VARCHAR(50),
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    paid_out BOOLEAN DEFAULT FALSE,
    paid_at TIMESTAMPTZ
);

-- ==========================================
-- DRIVER AVAILABILITY
-- ==========================================

CREATE TABLE driver_availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(driver_id, day_of_week)
);

-- ==========================================
-- DRIVER TIME OFF
-- ==========================================

CREATE TABLE driver_time_off (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    is_approved BOOLEAN DEFAULT FALSE,
    approved_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- DRIVER VEHICLES
-- ==========================================

CREATE TABLE driver_vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    vehicle_type ride_vehicle_type NOT NULL,
    registration_number VARCHAR(20) NOT NULL,
    brand VARCHAR(50),
    model VARCHAR(50),
    year INTEGER,
    color VARCHAR(30),
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    photo_urls TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- KYC DOCUMENTS
-- ==========================================

CREATE TABLE user_kyc_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL,
    document_number VARCHAR(50),
    document_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE driver_kyc_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL,
    document_number VARCHAR(50),
    document_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- PROMO CODES
-- ==========================================

CREATE TABLE promo_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(30) NOT NULL UNIQUE,
    description TEXT,
    discount_type VARCHAR(20) NOT NULL,
    discount_value DECIMAL(10, 2) NOT NULL,
    max_discount DECIMAL(10, 2),
    min_booking_amount DECIMAL(10, 2) DEFAULT 0,
    max_uses INTEGER,
    current_uses INTEGER DEFAULT 0,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    applicable_services TEXT[],
    applicable_cities TEXT[],
    first_time_only BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE promo_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    promo_code_id UUID NOT NULL REFERENCES promo_codes(id),
    user_id UUID NOT NULL REFERENCES profiles(id),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    discount_applied DECIMAL(10, 2) NOT NULL,
    used_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- REFERRALS
-- ==========================================

CREATE TABLE referrals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_id UUID NOT NULL REFERENCES profiles(id),
    referred_id UUID REFERENCES profiles(id),
    referral_code VARCHAR(20) NOT NULL UNIQUE,
    referrer_bonus DECIMAL(10, 2) DEFAULT 100,
    referred_bonus DECIMAL(10, 2) DEFAULT 50,
    status VARCHAR(20) DEFAULT 'pending',
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- LONG TRIP BOOKINGS
-- ==========================================

CREATE TABLE long_trip_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id),
    from_city VARCHAR(100) NOT NULL,
    to_city VARCHAR(100) NOT NULL,
    trip_days INTEGER NOT NULL DEFAULT 2,
    estimated_km INTEGER NOT NULL,
    car_type VARCHAR(50),
    transmission VARCHAR(20),
    driving_per_day DECIMAL(10, 2) DEFAULT 1800,
    accommodation_per_night DECIMAL(10, 2) DEFAULT 500,
    food_per_day DECIMAL(10, 2) DEFAULT 300,
    night_halt_per_night DECIMAL(10, 2) DEFAULT 200,
    total_driving_cost DECIMAL(10, 2),
    total_accommodation DECIMAL(10, 2),
    total_food_allowance DECIMAL(10, 2),
    total_night_halt DECIMAL(10, 2),
    grand_total DECIMAL(10, 2),
    departure_date DATE,
    return_date DATE,
    actual_return_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- USER PREFERENCES
-- ==========================================

CREATE TABLE user_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    preference_key VARCHAR(50) NOT NULL,
    preference_value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, preference_key)
);

-- ==========================================
-- P2P RENTAL CARS
-- ==========================================

CREATE TABLE rental_cars (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INTEGER,
    registration_number VARCHAR(20) UNIQUE,
    car_type VARCHAR(30) NOT NULL,
    transmission VARCHAR(20) NOT NULL,
    fuel_type VARCHAR(20),
    color VARCHAR(30),
    seats INTEGER DEFAULT 5,
    price_per_day DECIMAL(10, 2) NOT NULL,
    price_per_week DECIMAL(10, 2),
    price_per_month DECIMAL(10, 2),
    security_deposit DECIMAL(10, 2) DEFAULT 5000,
    location_lat DECIMAL(10, 7),
    location_lng DECIMAL(10, 7),
    location_address TEXT,
    city_code VARCHAR(10) DEFAULT 'BLR',
    features JSONB,
    photo_urls TEXT[],
    rating DECIMAL(2, 1) DEFAULT 0,
    total_trips INTEGER DEFAULT 0,
    total_earnings DECIMAL(12, 2) DEFAULT 0,
    status car_listing_status DEFAULT 'draft',
    is_available BOOLEAN DEFAULT TRUE,
    availability_start DATE,
    availability_end DATE,
    insurance_valid_till DATE,
    puc_valid_till DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- ==========================================
-- RENTAL BOOKINGS
-- ==========================================

CREATE TABLE rental_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rental_car_id UUID NOT NULL REFERENCES rental_cars(id),
    renter_id UUID NOT NULL REFERENCES profiles(id),
    owner_id UUID NOT NULL REFERENCES profiles(id),
    pickup_date DATE NOT NULL,
    pickup_time TIME NOT NULL,
    return_date DATE NOT NULL,
    return_time TIME NOT NULL,
    actual_return_date DATE,
    pickup_address TEXT,
    return_address TEXT,
    daily_rate DECIMAL(10, 2) NOT NULL,
    total_days INTEGER NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    security_deposit DECIMAL(10, 2) NOT NULL,
    platform_fee DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL,
    status rental_booking_status DEFAULT 'pending',
    pickup_otp VARCHAR(6),
    return_otp VARCHAR(6),
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- RIDE TYPES (Cab Service)
-- ==========================================

CREATE TABLE ride_types (
    id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    base_fare DECIMAL(8, 2) NOT NULL,
    per_km_rate DECIMAL(6, 2) NOT NULL,
    per_min_rate DECIMAL(6, 2) NOT NULL,
    min_fare DECIMAL(8, 2) NOT NULL,
    avg_eta_minutes INTEGER DEFAULT 5,
    max_seats INTEGER DEFAULT 4,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- RIDE BOOKINGS (Cab Service)
-- ==========================================

CREATE TABLE ride_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES profiles(id),
    driver_id UUID REFERENCES driver_profiles(id),
    ride_type_id VARCHAR(20) REFERENCES ride_types(id),
    status ride_booking_status DEFAULT 'idle',
    timing_mode VARCHAR(20) DEFAULT 'now',
    scheduled_time TIMESTAMPTZ,
    pickup_address TEXT NOT NULL,
    pickup_short_name VARCHAR(100),
    pickup_lat DECIMAL(10, 7) NOT NULL,
    pickup_lng DECIMAL(10, 7) NOT NULL,
    drop_address TEXT NOT NULL,
    drop_short_name VARCHAR(100),
    drop_lat DECIMAL(10, 7) NOT NULL,
    drop_lng DECIMAL(10, 7) NOT NULL,
    distance_km DECIMAL(8, 2),
    duration_minutes INTEGER,
    route_polyline TEXT,
    estimated_fare DECIMAL(10, 2),
    final_fare DECIMAL(10, 2),
    surge_multiplier DECIMAL(3, 2) DEFAULT 1.00,
    payment_method VARCHAR(20) DEFAULT 'cash',
    otp VARCHAR(4),
    driver_eta_minutes INTEGER,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    driver_assigned_at TIMESTAMPTZ,
    driver_arrived_at TIMESTAMPTZ,
    trip_started_at TIMESTAMPTZ,
    trip_completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- SURGE PRICING
-- ==========================================

CREATE TABLE surge_pricing (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id UUID REFERENCES geofence_configs(id),
    city_code VARCHAR(10),
    surge_multiplier DECIMAL(3, 2) NOT NULL DEFAULT 1.00,
    reason VARCHAR(100),
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- CITY RETURN FEES
-- ==========================================

CREATE TABLE city_return_fees (
    city_code VARCHAR(10) PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    return_fee DECIMAL(10, 2) NOT NULL,
    pooling_discount DECIMAL(4, 2) DEFAULT 0.10,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- APP CONFIG
-- ==========================================

CREATE TABLE app_config (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- FAQs
-- ==========================================

CREATE TABLE faq_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE faqs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES faq_categories(id),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    view_count INTEGER DEFAULT 0,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- AUDIT LOGS
-- ==========================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    performed_by UUID,
    performed_by_type VARCHAR(20),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- INDEXES
-- ==========================================

-- Profiles
CREATE INDEX idx_profiles_phone ON profiles(phone);
CREATE INDEX idx_profiles_city ON profiles(city_code);

-- Driver Profiles
CREATE INDEX idx_driver_profiles_phone ON driver_profiles(phone);
CREATE INDEX idx_driver_profiles_status ON driver_profiles(status);
CREATE INDEX idx_driver_profiles_location ON driver_profiles(current_lat, current_lng);

-- Bookings
CREATE INDEX idx_bookings_customer ON bookings(customer_id);
CREATE INDEX idx_bookings_driver ON bookings(driver_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_created ON bookings(created_at DESC);

-- Rental Cars
CREATE INDEX idx_rental_cars_owner ON rental_cars(owner_id);
CREATE INDEX idx_rental_cars_city ON rental_cars(city_code);
CREATE INDEX idx_rental_cars_status ON rental_cars(status) WHERE status = 'active';

-- Ride Bookings
CREATE INDEX idx_ride_bookings_customer ON ride_bookings(customer_id);
CREATE INDEX idx_ride_bookings_driver ON ride_bookings(driver_id);
CREATE INDEX idx_ride_bookings_status ON ride_bookings(status);

-- Recent Destinations
CREATE INDEX idx_recent_destinations_user ON recent_destinations(user_id);
CREATE INDEX idx_recent_destinations_visited ON recent_destinations(last_visited_at DESC);

-- Notifications
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_driver ON notifications(driver_id);
CREATE INDEX idx_notifications_unread ON notifications(is_read) WHERE is_read = FALSE;

-- ==========================================
-- ROW LEVEL SECURITY
-- ==========================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_return_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_billing ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE recent_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE rental_cars ENABLE ROW LEVEL SECURITY;
ALTER TABLE rental_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_bookings ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- RLS POLICIES
-- ==========================================

-- Profiles
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Driver Profiles
CREATE POLICY "Drivers can view own profile" ON driver_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Drivers can update own profile" ON driver_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Drivers can insert own profile" ON driver_profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Anyone can view driver info" ON driver_profiles FOR SELECT USING (TRUE);

-- Bookings
CREATE POLICY "Users can view own bookings" ON bookings FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Drivers can view assigned bookings" ON bookings FOR SELECT USING (auth.uid() = driver_id);
CREATE POLICY "Users can create bookings" ON bookings FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Saved Locations
CREATE POLICY "Users manage own saved locations" ON saved_locations FOR ALL USING (auth.uid() = user_id);

-- Recent Destinations
CREATE POLICY "Users manage own recent destinations" ON recent_destinations FOR ALL USING (auth.uid() = user_id);

-- Search History
CREATE POLICY "Users manage own search history" ON search_history FOR ALL USING (auth.uid() = user_id);

-- Notifications
CREATE POLICY "Users view own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id OR auth.uid() = driver_id);

-- Rental Cars - public view, owner manage
CREATE POLICY "Anyone can view active rental cars" ON rental_cars FOR SELECT USING (status = 'active' AND is_available = TRUE);
CREATE POLICY "Owners can manage own rental cars" ON rental_cars FOR ALL USING (auth.uid() = owner_id);

-- Rental Bookings
CREATE POLICY "Users can view own rental bookings" ON rental_bookings FOR SELECT USING (auth.uid() = renter_id OR auth.uid() = owner_id);
CREATE POLICY "Users can create rental bookings" ON rental_bookings FOR INSERT WITH CHECK (auth.uid() = renter_id);

-- Ride Bookings
CREATE POLICY "Users can view own ride bookings" ON ride_bookings FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Drivers can view assigned ride bookings" ON ride_bookings FOR SELECT USING (auth.uid() = driver_id);

-- Ride Types - public read
ALTER TABLE ride_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view ride types" ON ride_types FOR SELECT USING (is_active = TRUE);

-- Car Types - public read
ALTER TABLE car_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view car types" ON car_types FOR SELECT USING (is_available = TRUE);

-- Service role full access
CREATE POLICY "Service role full access profiles" ON profiles FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access driver_profiles" ON driver_profiles FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role full access bookings" ON bookings FOR ALL USING (auth.role() = 'service_role');

-- ==========================================
-- SEED DATA
-- ==========================================

-- Car Types
INSERT INTO car_types (id, category, transmission, display_name, example_models, price_per_hour) VALUES
('hatchback_mt', 'hatchback', 'manual', 'Hatchback Manual', ARRAY['Swift', 'i10', 'Polo'], 199),
('hatchback_at', 'hatchback', 'automatic', 'Hatchback Auto', ARRAY['Baleno AMT', 'i20 DCT'], 249),
('sedan_mt', 'sedan', 'manual', 'Sedan Manual', ARRAY['City', 'Verna', 'Ciaz'], 249),
('sedan_at', 'sedan', 'automatic', 'Sedan Auto', ARRAY['City CVT', 'Verna AT'], 299),
('compact_suv_mt', 'compact_suv', 'manual', 'Compact SUV Manual', ARRAY['Brezza', 'Venue', 'Nexon'], 299),
('compact_suv_at', 'compact_suv', 'automatic', 'Compact SUV Auto', ARRAY['Creta AT', 'Seltos AT'], 349),
('mid_suv_mt', 'mid_suv', 'manual', 'Mid SUV Manual', ARRAY['XUV500', 'Safari'], 349),
('mid_suv_at', 'mid_suv', 'automatic', 'Mid SUV Auto', ARRAY['Fortuner AT', 'Endeavour AT'], 449),
('mpv_mt', 'mpv', 'manual', 'MPV Manual', ARRAY['Innova', 'Ertiga'], 349),
('mpv_at', 'mpv', 'automatic', 'MPV Auto', ARRAY['Innova Crysta AT', 'Carnival'], 399);

-- Ride Types
INSERT INTO ride_types (id, name, description, icon, base_fare, per_km_rate, per_min_rate, min_fare, avg_eta_minutes, max_seats, display_order) VALUES
('bike', 'Bike', 'Quick & affordable', 'two_wheeler', 20, 8, 1, 30, 3, 1, 1),
('auto', 'Auto', 'Comfortable 3-wheeler', 'electric_rickshaw', 30, 12, 1.5, 40, 5, 3, 2),
('mini', 'Mini', 'Budget cab', 'directions_car', 50, 14, 2, 70, 7, 4, 3),
('sedan', 'Sedan', 'Comfortable sedan', 'directions_car', 80, 18, 2.5, 100, 10, 4, 4),
('suv', 'SUV', 'Spacious ride', 'directions_car_filled', 120, 22, 3, 150, 12, 6, 5);

-- City Return Fees
INSERT INTO city_return_fees (city_code, city_name, return_fee) VALUES
('BLR', 'Bangalore', 300),
('HYD', 'Hyderabad', 250),
('CHE', 'Chennai', 280),
('MUM', 'Mumbai', 350),
('DEL', 'Delhi NCR', 320),
('PUN', 'Pune', 250);

-- FAQ Categories
INSERT INTO faq_categories (name, description, icon, display_order) VALUES
('Driver Hire', 'Hiring a driver for your car', 'person', 1),
('Payments', 'Payment and billing', 'payment', 2),
('Safety', 'Safety features and tips', 'security', 3),
('Account', 'Account management', 'account_circle', 4);

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Fresh schema created successfully!';
    RAISE NOTICE 'Tables: profiles, driver_profiles (linked to auth.users)';
    RAISE NOTICE 'Trigger: Auto-creates profile on signup';
    RAISE NOTICE 'RLS: Enabled with policies';
    RAISE NOTICE 'Seed data: Car types, ride types, city fees, FAQs';
END $$;
