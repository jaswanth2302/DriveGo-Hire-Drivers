-- ==========================================
-- DRIVO DATABASE MIGRATION: Users → Profiles
-- Fix Supabase Auth integration
-- ==========================================
-- 
-- ISSUE: We created public.users with auto-generated UUIDs instead of
-- linking to Supabase's auth.users table.
--
-- SOLUTION: Rename 'users' to 'profiles' and link to auth.users(id)
-- Same for 'drivers' → 'driver_profiles'
-- ==========================================

-- ⚠️ WARNING: This is a breaking change. Run this BEFORE deploying to production.
-- If you already have data, you'll need to migrate it carefully.

-- Step 1: Drop foreign key constraints referencing users
-- (Run these if you have existing constraints)

ALTER TABLE IF EXISTS bookings DROP CONSTRAINT IF EXISTS bookings_customer_id_fkey;
ALTER TABLE IF EXISTS emergency_contacts DROP CONSTRAINT IF EXISTS emergency_contacts_user_id_fkey;
ALTER TABLE IF EXISTS notifications DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;
ALTER TABLE IF EXISTS payments DROP CONSTRAINT IF EXISTS payments_user_id_fkey;
ALTER TABLE IF EXISTS promo_usage DROP CONSTRAINT IF EXISTS promo_usage_user_id_fkey;
ALTER TABLE IF EXISTS push_tokens DROP CONSTRAINT IF EXISTS push_tokens_user_id_fkey;
ALTER TABLE IF EXISTS ratings DROP CONSTRAINT IF EXISTS ratings_user_id_fkey;
ALTER TABLE IF EXISTS recent_destinations DROP CONSTRAINT IF EXISTS recent_destinations_user_id_fkey;
ALTER TABLE IF EXISTS referrals DROP CONSTRAINT IF EXISTS referrals_referrer_id_fkey;
ALTER TABLE IF EXISTS referrals DROP CONSTRAINT IF EXISTS referrals_referred_id_fkey;
ALTER TABLE IF EXISTS rental_bookings DROP CONSTRAINT IF EXISTS rental_bookings_renter_id_fkey;
ALTER TABLE IF EXISTS rental_bookings DROP CONSTRAINT IF EXISTS rental_bookings_owner_id_fkey;
ALTER TABLE IF EXISTS rental_cars DROP CONSTRAINT IF EXISTS rental_cars_owner_id_fkey;
ALTER TABLE IF EXISTS rental_reviews DROP CONSTRAINT IF EXISTS rental_reviews_reviewer_id_fkey;
ALTER TABLE IF EXISTS ride_bookings DROP CONSTRAINT IF EXISTS ride_bookings_customer_id_fkey;
ALTER TABLE IF EXISTS saved_locations DROP CONSTRAINT IF EXISTS saved_locations_user_id_fkey;
ALTER TABLE IF EXISTS saved_payment_methods DROP CONSTRAINT IF EXISTS saved_payment_methods_user_id_fkey;
ALTER TABLE IF EXISTS search_history DROP CONSTRAINT IF EXISTS search_history_user_id_fkey;
ALTER TABLE IF EXISTS support_tickets DROP CONSTRAINT IF EXISTS support_tickets_user_id_fkey;
ALTER TABLE IF EXISTS user_kyc_documents DROP CONSTRAINT IF EXISTS user_kyc_documents_user_id_fkey;
ALTER TABLE IF EXISTS user_preferences DROP CONSTRAINT IF EXISTS user_preferences_user_id_fkey;
ALTER TABLE IF EXISTS user_sessions DROP CONSTRAINT IF EXISTS user_sessions_user_id_fkey;
ALTER TABLE IF EXISTS wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_user_id_fkey;
ALTER TABLE IF EXISTS owner_earnings DROP CONSTRAINT IF EXISTS owner_earnings_owner_id_fkey;

-- Step 2: Rename users table to profiles
ALTER TABLE IF EXISTS users RENAME TO profiles;

-- Step 3: Drop the auto-generated ID default and add proper constraint
-- If starting fresh, drop and recreate. If migrating, need to handle data.
ALTER TABLE profiles 
  ALTER COLUMN id DROP DEFAULT;

-- Add reference to auth.users (only works if auth.users exists)
-- Note: Run this after users sign up via Supabase Auth
-- ALTER TABLE profiles 
--   ADD CONSTRAINT profiles_id_fkey 
--   FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 4: Re-add all foreign key constraints pointing to profiles
ALTER TABLE bookings ADD CONSTRAINT bookings_customer_id_fkey 
  FOREIGN KEY (customer_id) REFERENCES profiles(id);

ALTER TABLE emergency_contacts ADD CONSTRAINT emergency_contacts_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE notifications ADD CONSTRAINT notifications_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id);

ALTER TABLE payments ADD CONSTRAINT payments_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id);

ALTER TABLE promo_usage ADD CONSTRAINT promo_usage_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id);

ALTER TABLE push_tokens ADD CONSTRAINT push_tokens_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id);

ALTER TABLE ratings ADD CONSTRAINT ratings_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id);

ALTER TABLE recent_destinations ADD CONSTRAINT recent_destinations_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE referrals ADD CONSTRAINT referrals_referrer_id_fkey 
  FOREIGN KEY (referrer_id) REFERENCES profiles(id);

ALTER TABLE referrals ADD CONSTRAINT referrals_referred_id_fkey 
  FOREIGN KEY (referred_id) REFERENCES profiles(id);

ALTER TABLE rental_bookings ADD CONSTRAINT rental_bookings_renter_id_fkey 
  FOREIGN KEY (renter_id) REFERENCES profiles(id);

ALTER TABLE rental_bookings ADD CONSTRAINT rental_bookings_owner_id_fkey 
  FOREIGN KEY (owner_id) REFERENCES profiles(id);

ALTER TABLE rental_cars ADD CONSTRAINT rental_cars_owner_id_fkey 
  FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE rental_reviews ADD CONSTRAINT rental_reviews_reviewer_id_fkey 
  FOREIGN KEY (reviewer_id) REFERENCES profiles(id);

ALTER TABLE ride_bookings ADD CONSTRAINT ride_bookings_customer_id_fkey 
  FOREIGN KEY (customer_id) REFERENCES profiles(id);

ALTER TABLE saved_locations ADD CONSTRAINT saved_locations_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE saved_payment_methods ADD CONSTRAINT saved_payment_methods_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE search_history ADD CONSTRAINT search_history_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE support_tickets ADD CONSTRAINT support_tickets_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id);

ALTER TABLE user_kyc_documents ADD CONSTRAINT user_kyc_documents_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE user_preferences ADD CONSTRAINT user_preferences_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE user_sessions ADD CONSTRAINT user_sessions_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE wallet_transactions ADD CONSTRAINT wallet_transactions_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES profiles(id);

ALTER TABLE owner_earnings ADD CONSTRAINT owner_earnings_owner_id_fkey 
  FOREIGN KEY (owner_id) REFERENCES profiles(id);

-- ==========================================
-- DRIVERS TABLE - Same treatment
-- ==========================================

-- Drop driver foreign key constraints
ALTER TABLE IF EXISTS bookings DROP CONSTRAINT IF EXISTS bookings_driver_id_fkey;
ALTER TABLE IF EXISTS driver_availability DROP CONSTRAINT IF EXISTS driver_availability_driver_id_fkey;
ALTER TABLE IF EXISTS driver_bonuses DROP CONSTRAINT IF EXISTS driver_bonuses_driver_id_fkey;
ALTER TABLE IF EXISTS driver_earnings DROP CONSTRAINT IF EXISTS driver_earnings_driver_id_fkey;
ALTER TABLE IF EXISTS driver_kyc_documents DROP CONSTRAINT IF EXISTS driver_kyc_documents_driver_id_fkey;
ALTER TABLE IF EXISTS driver_location_history DROP CONSTRAINT IF EXISTS driver_location_history_driver_id_fkey;
ALTER TABLE IF EXISTS driver_time_off DROP CONSTRAINT IF EXISTS driver_time_off_driver_id_fkey;
ALTER TABLE IF EXISTS driver_vehicles DROP CONSTRAINT IF EXISTS driver_vehicles_driver_id_fkey;
ALTER TABLE IF EXISTS notifications DROP CONSTRAINT IF EXISTS notifications_driver_id_fkey;
ALTER TABLE IF EXISTS push_tokens DROP CONSTRAINT IF EXISTS push_tokens_driver_id_fkey;
ALTER TABLE IF EXISTS ratings DROP CONSTRAINT IF EXISTS ratings_driver_id_fkey;
ALTER TABLE IF EXISTS return_tasks DROP CONSTRAINT IF EXISTS return_tasks_driver_id_fkey;
ALTER TABLE IF EXISTS ride_bookings DROP CONSTRAINT IF EXISTS ride_bookings_driver_id_fkey;
ALTER TABLE IF EXISTS safety_alerts DROP CONSTRAINT IF EXISTS safety_alerts_driver_id_fkey;
ALTER TABLE IF EXISTS support_tickets DROP CONSTRAINT IF EXISTS support_tickets_driver_id_fkey;
ALTER TABLE IF EXISTS user_sessions DROP CONSTRAINT IF EXISTS user_sessions_driver_id_fkey;

-- Rename drivers to driver_profiles
ALTER TABLE IF EXISTS drivers RENAME TO driver_profiles;

-- Remove auto-generated ID default
ALTER TABLE driver_profiles 
  ALTER COLUMN id DROP DEFAULT;

-- Re-add foreign key constraints for driver_profiles
ALTER TABLE bookings ADD CONSTRAINT bookings_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id);

ALTER TABLE driver_availability ADD CONSTRAINT driver_availability_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id) ON DELETE CASCADE;

ALTER TABLE driver_bonuses ADD CONSTRAINT driver_bonuses_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id) ON DELETE CASCADE;

ALTER TABLE driver_earnings ADD CONSTRAINT driver_earnings_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id) ON DELETE CASCADE;

ALTER TABLE driver_kyc_documents ADD CONSTRAINT driver_kyc_documents_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id) ON DELETE CASCADE;

ALTER TABLE driver_location_history ADD CONSTRAINT driver_location_history_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id) ON DELETE CASCADE;

ALTER TABLE driver_time_off ADD CONSTRAINT driver_time_off_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id) ON DELETE CASCADE;

ALTER TABLE driver_vehicles ADD CONSTRAINT driver_vehicles_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id) ON DELETE CASCADE;

ALTER TABLE notifications ADD CONSTRAINT notifications_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id);

ALTER TABLE push_tokens ADD CONSTRAINT push_tokens_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id);

ALTER TABLE ratings ADD CONSTRAINT ratings_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id);

ALTER TABLE return_tasks ADD CONSTRAINT return_tasks_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id);

ALTER TABLE ride_bookings ADD CONSTRAINT ride_bookings_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id);

ALTER TABLE safety_alerts ADD CONSTRAINT safety_alerts_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id);

ALTER TABLE support_tickets ADD CONSTRAINT support_tickets_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id);

ALTER TABLE user_sessions ADD CONSTRAINT user_sessions_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES driver_profiles(id) ON DELETE CASCADE;

-- ==========================================
-- UPDATE RLS POLICIES
-- ==========================================

-- Profiles RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Driver Profiles RLS
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Drivers can view own profile"
  ON driver_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Drivers can update own profile"
  ON driver_profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Drivers can insert own profile"
  ON driver_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Allow viewing driver profiles for booking
CREATE POLICY "Anyone can view basic driver info"
  ON driver_profiles FOR SELECT
  USING (TRUE);

-- ==========================================
-- AUTO-CREATE PROFILE ON SIGNUP (TRIGGER)
-- ==========================================

-- This function creates a profile when a user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, name, email, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.phone,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    NEW.email,
    NOW(),
    NOW()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users insert
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- VERIFICATION
-- ==========================================
DO $$
BEGIN
  RAISE NOTICE '✅ Migration complete!';
  RAISE NOTICE 'Tables renamed: users → profiles, drivers → driver_profiles';
  RAISE NOTICE 'RLS policies updated to use auth.uid()';
  RAISE NOTICE 'Trigger added to auto-create profile on signup';
END $$;
