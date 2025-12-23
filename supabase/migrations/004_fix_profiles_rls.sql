-- Enable Row Level Security (RLS) on the profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- DROP existing policies first to function as a "Reset"
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- 1. Allow users to view their OWN profile
CREATE POLICY "Users can view own profile" 
ON profiles FOR SELECT 
USING (auth.uid() = id);

-- 2. Allow users to update their OWN profile
CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE 
USING (auth.uid() = id);

-- 3. Allow users to insert their OWN profile
CREATE POLICY "Users can insert own profile" 
ON profiles FOR INSERT 
WITH CHECK (auth.uid() = id);

-- 4. CRITICAL: Grant permissions to the roles
GRANT ALL ON TABLE profiles TO authenticated;
GRANT ALL ON TABLE profiles TO service_role;

-- 4. Enable RLS on other tables just in case (optional safeties)
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view driver profiles"
ON driver_profiles FOR SELECT
USING (true); -- Publicly readable for booking purposes? Or specific?

-- For now, just fix profiles
