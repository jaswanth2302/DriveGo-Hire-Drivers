-- ============================================================
-- DRIVO - REALTIME & CRON CONFIGURATION
-- Run this in Supabase SQL Editor
-- ============================================================

-- ==================== ENABLE REALTIME ====================
-- Enable realtime on required tables for live updates

-- 1. ride_bookings - Customer/driver status updates
ALTER PUBLICATION supabase_realtime ADD TABLE ride_bookings;

-- 2. ride_match_attempts - Driver ping notifications  
ALTER PUBLICATION supabase_realtime ADD TABLE ride_match_attempts;

-- 3. driver_location_history - Live tracking
ALTER PUBLICATION supabase_realtime ADD TABLE driver_location_history;

-- 4. ride_events - Event streaming
ALTER PUBLICATION supabase_realtime ADD TABLE ride_events;

-- 5. driver_profiles - Driver status changes
ALTER PUBLICATION supabase_realtime ADD TABLE driver_profiles;

-- ==================== STORAGE BUCKETS ====================
-- Create storage buckets for files

-- Driver documents bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver-documents',
  'driver-documents',
  false,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'application/pdf']
) ON CONFLICT (id) DO NOTHING;

-- Ride evidence bucket (trip photos, receipts)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ride-evidence',
  'ride-evidence',
  false,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png']
) ON CONFLICT (id) DO NOTHING;

-- Dispute attachments bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'dispute-attachments',
  'dispute-attachments',
  false,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'video/mp4', 'audio/mpeg']
) ON CONFLICT (id) DO NOTHING;

-- ==================== STORAGE RLS POLICIES ====================

-- Driver documents: Only owner can upload/view
CREATE POLICY "Drivers can manage own documents" ON storage.objects
  FOR ALL
  USING (
    bucket_id = 'driver-documents' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'driver-documents'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Ride evidence: Trip participants can upload/view
CREATE POLICY "Trip participants can manage evidence" ON storage.objects
  FOR ALL
  USING (
    bucket_id = 'ride-evidence'
    AND EXISTS (
      SELECT 1 FROM ride_bookings rb
      WHERE rb.id::text = (storage.foldername(name))[1]
      AND (rb.customer_id = auth.uid() OR rb.driver_id = auth.uid())
    )
  );

-- Dispute attachments: Dispute participants can manage
CREATE POLICY "Dispute participants can manage attachments" ON storage.objects
  FOR ALL
  USING (
    bucket_id = 'dispute-attachments'
    AND EXISTS (
      SELECT 1 FROM disputes d
      WHERE d.id::text = (storage.foldername(name))[1]
      AND (d.raised_by = auth.uid() OR EXISTS (
        SELECT 1 FROM ride_bookings rb
        WHERE rb.id = d.ride_booking_id
        AND (rb.customer_id = auth.uid() OR rb.driver_id = auth.uid())
      ))
    )
  );

-- ==================== CRON JOBS (pg_cron extension) ====================
-- Note: pg_cron must be enabled in Supabase Dashboard → Database → Extensions

-- 1. Scheduled rides matching - every 5 minutes
SELECT cron.schedule(
  'match-scheduled-rides',
  '*/5 * * * *',  -- Every 5 minutes
  $$
  SELECT net.http_post(
    url := 'https://kgfscfqvymnclelcqwlh.supabase.co/functions/v1/handle-scheduled-rides',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{}'::jsonb
  );
  $$
);

-- 2. Surge pricing calculation - every 5 minutes
SELECT cron.schedule(
  'calculate-surge-pricing',
  '*/5 * * * *',  -- Every 5 minutes
  $$
  SELECT net.http_post(
    url := 'https://kgfscfqvymnclelcqwlh.supabase.co/functions/v1/surge-pricing-worker',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{}'::jsonb
  );
  $$
);

-- 3. Cleanup stale sessions - every 2 minutes
SELECT cron.schedule(
  'cleanup-stale-sessions',
  '*/2 * * * *',  -- Every 2 minutes
  $$
  SELECT net.http_post(
    url := 'https://kgfscfqvymnclelcqwlh.supabase.co/functions/v1/cleanup-stale-sessions',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{}'::jsonb
  );
  $$
);

-- ==================== HELPER FUNCTION FOR DRIVER CANCELLATION TRACKING ====================

CREATE OR REPLACE FUNCTION increment_driver_cancellations(driver_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE driver_profiles
  SET 
    total_cancellations = COALESCE(total_cancellations, 0) + 1,
    cancellation_rate = CASE 
      WHEN COALESCE(total_trips, 0) + COALESCE(total_cancellations, 0) + 1 > 0 
      THEN ((COALESCE(total_cancellations, 0) + 1)::DECIMAL / 
            (COALESCE(total_trips, 0) + COALESCE(total_cancellations, 0) + 1)) * 100
      ELSE 0.00
    END,
    updated_at = NOW()
  WHERE id = driver_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== SUMMARY ====================
-- Enabled Realtime on: ride_bookings, ride_match_attempts, driver_location_history, ride_events, driver_profiles
-- Created Storage Buckets: driver-documents, ride-evidence, dispute-attachments
-- Created Cron Jobs: match-scheduled-rides, calculate-surge-pricing, cleanup-stale-sessions
-- ============================================================
