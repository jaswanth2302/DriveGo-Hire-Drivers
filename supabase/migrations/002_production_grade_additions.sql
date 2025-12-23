-- ============================================================
-- DRIVO - PRODUCTION-GRADE SCHEMA ADDITIONS
-- Migration: 002_production_grade_additions.sql
-- 
-- This is an ADDITIVE migration that adds missing tables for:
-- 1. Ride Matching Logic (ride_match_attempts)
-- 2. Driver Online Sessions (driver_sessions)
-- 3. Ride Lifecycle Events (event sourcing)
-- 4. Driver Acceptance Metrics (columns + daily metrics)
-- 5. Scheduled Ride Worker Support
-- 6. Disputes System
--
-- NOTE: Does NOT recreate existing tables from schema_fresh.sql
-- ============================================================

-- ==================== NEW ENUM TYPES ====================

-- Match Response Status
DO $$ BEGIN
    CREATE TYPE match_response AS ENUM (
        'pending',
        'accepted',
        'rejected',
        'timeout',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Ride Event Types (Event Sourcing)
DO $$ BEGIN
    CREATE TYPE ride_event_type AS ENUM (
        'booking_created',
        'driver_search_started',
        'driver_pinged',
        'driver_accepted',
        'driver_rejected',
        'driver_timeout',
        'driver_assigned',
        'driver_en_route',
        'driver_arrived',
        'otp_verified',
        'trip_started',
        'stop_reached',
        'destination_reached',
        'return_started',
        'return_completed',
        'trip_completed',
        'trip_cancelled',
        'payment_initiated',
        'payment_completed',
        'rating_submitted',
        'dispute_raised',
        'dispute_resolved'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Session End Reason
DO $$ BEGIN
    CREATE TYPE session_end_reason AS ENUM (
        'manual_offline',
        'app_killed',
        'battery_low',
        'inactivity_timeout',
        'shift_ended',
        'admin_force_offline',
        'trip_assigned'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Dispute Status
DO $$ BEGIN
    CREATE TYPE dispute_status AS ENUM (
        'raised',
        'under_review',
        'awaiting_evidence',
        'resolved_for_customer',
        'resolved_for_driver',
        'resolved_split',
        'closed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ==================== ALTER driver_profiles: Add Acceptance Metrics ====================

-- Add acceptance metric columns to existing driver_profiles table
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS acceptance_rate DECIMAL(5, 2) DEFAULT 100.00;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS cancellation_rate DECIMAL(5, 2) DEFAULT 0.00;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS timeout_rate DECIMAL(5, 2) DEFAULT 0.00;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS total_offers_received INTEGER DEFAULT 0;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS total_offers_accepted INTEGER DEFAULT 0;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS total_offers_rejected INTEGER DEFAULT 0;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS total_offers_timeout INTEGER DEFAULT 0;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS total_cancellations INTEGER DEFAULT 0;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS matching_priority_score DECIMAL(5, 2) DEFAULT 50.00;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- Add index for matching priority
CREATE INDEX IF NOT EXISTS idx_driver_profiles_priority ON driver_profiles(matching_priority_score DESC);

-- ==================== ALTER ride_bookings: Add Matching Metadata ====================

ALTER TABLE ride_bookings ADD COLUMN IF NOT EXISTS search_radius_km DECIMAL(4, 2) DEFAULT 3.00;
ALTER TABLE ride_bookings ADD COLUMN IF NOT EXISTS max_match_attempts INTEGER DEFAULT 10;
ALTER TABLE ride_bookings ADD COLUMN IF NOT EXISTS current_match_attempt INTEGER DEFAULT 0;
ALTER TABLE ride_bookings ADD COLUMN IF NOT EXISTS scheduled_match_attempted_at TIMESTAMPTZ;
ALTER TABLE ride_bookings ADD COLUMN IF NOT EXISTS scheduled_match_retry_count INTEGER DEFAULT 0;
ALTER TABLE ride_bookings ADD COLUMN IF NOT EXISTS matching_lock_until TIMESTAMPTZ;
ALTER TABLE ride_bookings ADD COLUMN IF NOT EXISTS matching_locked_by VARCHAR(100);
ALTER TABLE ride_bookings ADD COLUMN IF NOT EXISTS cancelled_by UUID;

-- ==================== TABLE 1: Ride Match Attempts ====================

CREATE TABLE IF NOT EXISTS ride_match_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_booking_id UUID NOT NULL REFERENCES ride_bookings(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES driver_profiles(id),
    
    -- Attempt ordering
    attempt_order INTEGER NOT NULL,
    
    -- Distance and ETA at time of ping
    distance_km DECIMAL(6, 2),
    estimated_eta_minutes INTEGER,
    
    -- Timing
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    responded_at TIMESTAMPTZ,
    
    -- Response
    response match_response DEFAULT 'pending',
    rejection_reason TEXT,
    
    -- Was this driver ultimately assigned?
    was_assigned BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for ride match attempts
CREATE INDEX IF NOT EXISTS idx_match_attempts_booking ON ride_match_attempts(ride_booking_id);
CREATE INDEX IF NOT EXISTS idx_match_attempts_driver ON ride_match_attempts(driver_id);
CREATE INDEX IF NOT EXISTS idx_match_attempts_pending ON ride_match_attempts(response) WHERE response = 'pending';
CREATE INDEX IF NOT EXISTS idx_match_attempts_sent_at ON ride_match_attempts(sent_at DESC);

COMMENT ON TABLE ride_match_attempts IS 'Tracks every driver ping during matching. Essential for debugging "no drivers found" and analytics.';

-- ==================== TABLE 2: Driver Sessions ====================

CREATE TABLE IF NOT EXISTS driver_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    
    -- Session timing
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    
    -- Heartbeat tracking
    last_heartbeat TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    heartbeat_interval_seconds INTEGER DEFAULT 30,
    missed_heartbeats INTEGER DEFAULT 0,
    
    -- Location at session events
    start_lat DECIMAL(10, 7),
    start_lng DECIMAL(10, 7),
    end_lat DECIMAL(10, 7),
    end_lng DECIMAL(10, 7),
    
    -- Session metadata
    city_code VARCHAR(10) NOT NULL DEFAULT 'BLR',
    app_version VARCHAR(20),
    device_info JSONB,
    
    -- Computed metrics (updated periodically)
    total_online_minutes INTEGER DEFAULT 0,
    total_idle_minutes INTEGER DEFAULT 0,
    total_trip_minutes INTEGER DEFAULT 0,
    trips_completed INTEGER DEFAULT 0,
    
    -- Session end
    end_reason session_end_reason,
    
    -- Battery tracking (for app-killed detection)
    last_battery_level INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for driver sessions
CREATE INDEX IF NOT EXISTS idx_driver_sessions_driver ON driver_sessions(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_sessions_active ON driver_sessions(driver_id, ended_at) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_driver_sessions_heartbeat ON driver_sessions(last_heartbeat) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_driver_sessions_city ON driver_sessions(city_code);
CREATE INDEX IF NOT EXISTS idx_driver_sessions_started ON driver_sessions(started_at DESC);

COMMENT ON TABLE driver_sessions IS 'Tracks when drivers are online. Used for surge pricing, ETA, and idle pay calculations.';

-- ==================== TABLE 3: Ride Events (Event Sourcing) ====================

CREATE TABLE IF NOT EXISTS ride_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_booking_id UUID NOT NULL REFERENCES ride_bookings(id) ON DELETE CASCADE,
    
    -- Event details
    event_type ride_event_type NOT NULL,
    
    -- Who triggered this event
    triggered_by UUID,
    triggered_by_type VARCHAR(20), -- 'customer', 'driver', 'system', 'admin'
    
    -- Event payload (flexible JSON for event-specific data)
    payload JSONB DEFAULT '{}',
    
    -- Location at event time (if applicable)
    lat DECIMAL(10, 7),
    lng DECIMAL(10, 7),
    
    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for ride events
CREATE INDEX IF NOT EXISTS idx_ride_events_booking ON ride_events(ride_booking_id);
CREATE INDEX IF NOT EXISTS idx_ride_events_type ON ride_events(event_type);
CREATE INDEX IF NOT EXISTS idx_ride_events_time ON ride_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ride_events_booking_time ON ride_events(ride_booking_id, created_at);

COMMENT ON TABLE ride_events IS 'Event sourcing log for all ride state changes. Used for dispute resolution, replay, and analytics.';

-- ==================== TABLE 4: Driver Daily Metrics ====================

CREATE TABLE IF NOT EXISTS driver_daily_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    
    -- Session metrics
    total_online_minutes INTEGER DEFAULT 0,
    total_idle_minutes INTEGER DEFAULT 0,
    total_trip_minutes INTEGER DEFAULT 0,
    session_count INTEGER DEFAULT 0,
    
    -- Offer metrics
    offers_received INTEGER DEFAULT 0,
    offers_accepted INTEGER DEFAULT 0,
    offers_rejected INTEGER DEFAULT 0,
    offers_timeout INTEGER DEFAULT 0,
    
    -- Trip metrics
    trips_completed INTEGER DEFAULT 0,
    trips_cancelled_by_driver INTEGER DEFAULT 0,
    trips_cancelled_by_customer INTEGER DEFAULT 0,
    
    -- Earnings
    trip_earnings DECIMAL(10, 2) DEFAULT 0,
    bonus_earnings DECIMAL(10, 2) DEFAULT 0,
    incentive_earnings DECIMAL(10, 2) DEFAULT 0,
    total_earnings DECIMAL(10, 2) DEFAULT 0,
    
    -- Distance
    total_km_driven DECIMAL(8, 2) DEFAULT 0,
    
    -- Ratings received today
    ratings_count INTEGER DEFAULT 0,
    ratings_sum INTEGER DEFAULT 0,
    average_rating DECIMAL(2, 1),
    
    -- Calculated rates
    acceptance_rate DECIMAL(5, 2),
    cancellation_rate DECIMAL(5, 2),
    completion_rate DECIMAL(5, 2),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(driver_id, date)
);

CREATE INDEX IF NOT EXISTS idx_driver_metrics_driver_date ON driver_daily_metrics(driver_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_driver_metrics_date ON driver_daily_metrics(date);

COMMENT ON TABLE driver_daily_metrics IS 'Aggregated daily metrics for each driver. Used for incentives and performance tracking.';

-- ==================== TABLE 5: Disputes ====================

CREATE TABLE IF NOT EXISTS disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_booking_id UUID NOT NULL REFERENCES ride_bookings(id),
    
    -- Who raised the dispute
    raised_by UUID NOT NULL,
    raised_by_type VARCHAR(20) NOT NULL, -- 'customer', 'driver'
    
    -- Dispute details
    category VARCHAR(50) NOT NULL, -- 'fare', 'route', 'behaviour', 'damage', 'safety', 'other'
    description TEXT NOT NULL,
    
    -- Status
    status dispute_status DEFAULT 'raised',
    
    -- Resolution
    assigned_to UUID,
    resolution_notes TEXT,
    refund_amount DECIMAL(10, 2),
    penalty_amount DECIMAL(10, 2),
    
    -- Evidence
    evidence_urls TEXT[],
    
    -- Timestamps
    raised_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disputes_booking ON disputes(ride_booking_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_raised_by ON disputes(raised_by);

COMMENT ON TABLE disputes IS 'Customer and driver disputes with resolution tracking.';

-- ==================== TABLE 6: Surge Zones (Real-time) ====================

CREATE TABLE IF NOT EXISTS surge_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city_code VARCHAR(10) NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    
    -- Surge multiplier (1.0 = no surge, 2.0 = 2x pricing)
    surge_multiplier DECIMAL(3, 2) DEFAULT 1.00,
    
    -- Demand metrics
    active_requests INTEGER DEFAULT 0,
    available_drivers INTEGER DEFAULT 0,
    demand_supply_ratio DECIMAL(5, 2),
    
    -- Validity
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ NOT NULL,
    
    -- Boundary (GeoJSON polygon)
    boundary JSONB,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_surge_zones_city ON surge_zones(city_code);
CREATE INDEX IF NOT EXISTS idx_surge_zones_active ON surge_zones(valid_until);

COMMENT ON TABLE surge_zones IS 'Real-time surge pricing zones. Calculated by Edge Function every 5 minutes.';

-- ==================== FUNCTIONS ====================

-- Function to update driver matching priority based on metrics
CREATE OR REPLACE FUNCTION update_driver_matching_priority()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate matching priority score (0-100)
    -- Higher is better
    -- Formula: 40% acceptance rate + 30% rating + 20% (100 - cancellation rate) + 10% (100 - timeout rate)
    NEW.matching_priority_score := 
        (COALESCE(NEW.acceptance_rate, 100) * 0.40) +
        (COALESCE(NEW.rating, 4.5) / 5.0 * 100 * 0.30) +
        ((100 - COALESCE(NEW.cancellation_rate, 0)) * 0.20) +
        ((100 - COALESCE(NEW.timeout_rate, 0)) * 0.10);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for matching priority update (drop if exists, then create)
DROP TRIGGER IF EXISTS trigger_update_matching_priority ON driver_profiles;
CREATE TRIGGER trigger_update_matching_priority
    BEFORE UPDATE OF acceptance_rate, cancellation_rate, timeout_rate, rating
    ON driver_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_driver_matching_priority();

-- Function to update driver metrics on match attempt response
CREATE OR REPLACE FUNCTION update_driver_metrics_on_match()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.response = 'pending' AND NEW.response != 'pending' THEN
        UPDATE driver_profiles
        SET 
            total_offers_received = COALESCE(total_offers_received, 0) + 1,
            total_offers_accepted = COALESCE(total_offers_accepted, 0) + CASE WHEN NEW.response = 'accepted' THEN 1 ELSE 0 END,
            total_offers_rejected = COALESCE(total_offers_rejected, 0) + CASE WHEN NEW.response = 'rejected' THEN 1 ELSE 0 END,
            total_offers_timeout = COALESCE(total_offers_timeout, 0) + CASE WHEN NEW.response = 'timeout' THEN 1 ELSE 0 END,
            acceptance_rate = CASE 
                WHEN COALESCE(total_offers_received, 0) + 1 > 0 
                THEN ((COALESCE(total_offers_accepted, 0) + CASE WHEN NEW.response = 'accepted' THEN 1 ELSE 0 END)::DECIMAL / (COALESCE(total_offers_received, 0) + 1)) * 100
                ELSE 100.00
            END,
            timeout_rate = CASE 
                WHEN COALESCE(total_offers_received, 0) + 1 > 0 
                THEN ((COALESCE(total_offers_timeout, 0) + CASE WHEN NEW.response = 'timeout' THEN 1 ELSE 0 END)::DECIMAL / (COALESCE(total_offers_received, 0) + 1)) * 100
                ELSE 0.00
            END,
            updated_at = NOW()
        WHERE id = NEW.driver_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for driver metrics update
DROP TRIGGER IF EXISTS trigger_update_driver_metrics ON ride_match_attempts;
CREATE TRIGGER trigger_update_driver_metrics
    AFTER UPDATE OF response ON ride_match_attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_driver_metrics_on_match();

-- Function to end stale driver sessions (for cron job)
CREATE OR REPLACE FUNCTION end_stale_driver_sessions(timeout_minutes INTEGER DEFAULT 5)
RETURNS INTEGER AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    UPDATE driver_sessions
    SET 
        ended_at = NOW(),
        end_reason = 'inactivity_timeout',
        updated_at = NOW()
    WHERE 
        ended_at IS NULL
        AND last_heartbeat < NOW() - (timeout_minutes || ' minutes')::INTERVAL;
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    
    -- Also set drivers offline
    UPDATE driver_profiles dp
    SET 
        status = 'offline',
        updated_at = NOW()
    FROM driver_sessions ds
    WHERE 
        dp.id = ds.driver_id
        AND ds.ended_at IS NOT NULL
        AND ds.last_heartbeat < NOW() - (timeout_minutes || ' minutes')::INTERVAL
        AND dp.status != 'offline';
    
    RETURN affected_count;
END;
$$ LANGUAGE plpgsql;

-- Function to log ride event
CREATE OR REPLACE FUNCTION log_ride_event(
    p_ride_id UUID,
    p_event_type ride_event_type,
    p_triggered_by UUID DEFAULT NULL,
    p_triggered_by_type VARCHAR DEFAULT 'system',
    p_payload JSONB DEFAULT '{}',
    p_lat DECIMAL DEFAULT NULL,
    p_lng DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
BEGIN
    INSERT INTO ride_events (
        ride_booking_id, event_type, triggered_by, triggered_by_type, payload, lat, lng
    ) VALUES (
        p_ride_id, p_event_type, p_triggered_by, p_triggered_by_type, p_payload, p_lat, p_lng
    ) RETURNING id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- ==================== ROW LEVEL SECURITY ====================

-- Enable RLS on new tables
ALTER TABLE ride_match_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_daily_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE surge_zones ENABLE ROW LEVEL SECURITY;

-- Match Attempts: Drivers can see attempts sent to them
DROP POLICY IF EXISTS match_attempts_driver_access ON ride_match_attempts;
CREATE POLICY match_attempts_driver_access ON ride_match_attempts
    FOR SELECT USING (driver_id = auth.uid());

DROP POLICY IF EXISTS match_attempts_driver_update ON ride_match_attempts;
CREATE POLICY match_attempts_driver_update ON ride_match_attempts
    FOR UPDATE USING (driver_id = auth.uid()) WITH CHECK (driver_id = auth.uid());

-- Driver Sessions: Drivers can access their own sessions
DROP POLICY IF EXISTS driver_sessions_self_access ON driver_sessions;
CREATE POLICY driver_sessions_self_access ON driver_sessions
    FOR ALL USING (driver_id = auth.uid()) WITH CHECK (driver_id = auth.uid());

-- Ride Events: Accessible by booking participants
DROP POLICY IF EXISTS ride_events_participant_access ON ride_events;
CREATE POLICY ride_events_participant_access ON ride_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM ride_bookings rb
            WHERE rb.id = ride_events.ride_booking_id
            AND (rb.customer_id = auth.uid() OR rb.driver_id = auth.uid())
        )
    );

-- Driver Daily Metrics: Drivers can read their own metrics
DROP POLICY IF EXISTS driver_metrics_self_access ON driver_daily_metrics;
CREATE POLICY driver_metrics_self_access ON driver_daily_metrics
    FOR SELECT USING (driver_id = auth.uid());

-- Disputes: Accessible by dispute participants
DROP POLICY IF EXISTS disputes_participant_access ON disputes;
CREATE POLICY disputes_participant_access ON disputes
    FOR SELECT USING (
        raised_by = auth.uid()
        OR EXISTS (
            SELECT 1 FROM ride_bookings rb
            WHERE rb.id = disputes.ride_booking_id
            AND (rb.customer_id = auth.uid() OR rb.driver_id = auth.uid())
        )
    );

-- Surge Zones: Public read for all authenticated users
DROP POLICY IF EXISTS surge_zones_read ON surge_zones;
CREATE POLICY surge_zones_read ON surge_zones
    FOR SELECT USING (auth.role() = 'authenticated');

-- ==================== APP CONFIG FOR MATCHING ====================

INSERT INTO app_config (key, value, description) VALUES
    ('matching_timeout_seconds', '30', 'Seconds before match offer times out'),
    ('max_match_attempts', '10', 'Maximum drivers to ping before giving up'),
    ('search_radius_km', '5', 'Initial search radius for drivers'),
    ('heartbeat_interval_seconds', '30', 'Expected heartbeat interval from drivers'),
    ('stale_session_timeout_minutes', '5', 'Minutes without heartbeat before session ends'),
    ('surge_calculation_interval_minutes', '5', 'How often to recalculate surge pricing')
ON CONFLICT (key) DO NOTHING;

-- ==================== SUMMARY ====================
-- Added Tables:
--   1. ride_match_attempts - Track driver pings during matching
--   2. driver_sessions - Track online sessions for surge/ETA
--   3. ride_events - Event sourcing for ride lifecycle
--   4. driver_daily_metrics - Daily aggregated metrics
--   5. disputes - Dispute resolution system
--   6. surge_zones - Real-time surge pricing
--
-- Added Columns to driver_profiles:
--   - acceptance_rate, cancellation_rate, timeout_rate
--   - total_offers_received/accepted/rejected/timeout
--   - matching_priority_score, is_verified, verified_at
--
-- Added Columns to ride_bookings:
--   - search_radius_km, max_match_attempts, current_match_attempt
--   - scheduled_match_attempted_at, scheduled_match_retry_count
--   - matching_lock_until, matching_locked_by, cancelled_by
--
-- Added Functions:
--   - update_driver_matching_priority() - Auto-calculates priority
--   - update_driver_metrics_on_match() - Updates metrics on response
--   - end_stale_driver_sessions() - Cleanup stale sessions
--   - log_ride_event() - Helper to log events
-- ============================================================
