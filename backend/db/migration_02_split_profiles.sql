-- Migration: Split Profiles table and update references
-- Copy and run this in your Supabase SQL Editor:

-- 1. Drop existing policies, constraints, and tables
DROP POLICY IF EXISTS "Profiles can be viewed by owners or admins" ON public.profiles;
DROP POLICY IF EXISTS "Profiles can be updated by owners" ON public.profiles;
DROP POLICY IF EXISTS "Profiles can be inserted by anyone during registration" ON public.profiles;
DROP POLICY IF EXISTS "Profiles can be viewed by owners or active schools" ON public.profiles;

ALTER TABLE public.students DROP CONSTRAINT IF EXISTS students_parent_id_fkey;
ALTER TABLE public.students DROP CONSTRAINT IF EXISTS students_school_id_fkey;
ALTER TABLE public.school_contracts DROP CONSTRAINT IF EXISTS school_contracts_parent_id_fkey;
ALTER TABLE public.school_contracts DROP CONSTRAINT IF EXISTS school_contracts_school_id_fkey;

DROP TABLE IF EXISTS public.school_profiles CASCADE;
DROP TABLE IF EXISTS public.merchant_profiles CASCADE;

-- 2. Modify Profiles table to be Parent/Client only
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_sub_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('client'));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_sub_role_check CHECK (sub_role IN ('parent'));

-- 3. Create School Profiles table
CREATE TABLE IF NOT EXISTS public.school_profiles (
    id TEXT PRIMARY KEY,
    school_name TEXT NOT NULL,
    admin_name TEXT,
    phone_number TEXT UNIQUE NOT NULL,
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on School Profiles
ALTER TABLE public.school_profiles ENABLE ROW LEVEL SECURITY;

-- 4. Create Merchant Profiles table
CREATE TABLE IF NOT EXISTS public.merchant_profiles (
    id TEXT PRIMARY KEY,
    business_name TEXT NOT NULL,
    owner_name TEXT,
    phone_number TEXT UNIQUE NOT NULL,
    address TEXT,
    photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on Merchant Profiles
ALTER TABLE public.merchant_profiles ENABLE ROW LEVEL SECURITY;

-- 5. Recreate foreign key constraints referencing new tables
ALTER TABLE public.students 
    ADD CONSTRAINT students_parent_id_fkey 
    FOREIGN KEY (parent_id) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;

ALTER TABLE public.students 
    ADD CONSTRAINT students_school_id_fkey 
    FOREIGN KEY (school_id) 
    REFERENCES public.school_profiles(id) 
    ON DELETE CASCADE;

ALTER TABLE public.school_contracts 
    ADD CONSTRAINT school_contracts_parent_id_fkey 
    FOREIGN KEY (parent_id) 
    REFERENCES public.profiles(id) 
    ON DELETE RESTRICT;

ALTER TABLE public.school_contracts 
    ADD CONSTRAINT school_contracts_school_id_fkey 
    FOREIGN KEY (school_id) 
    REFERENCES public.school_profiles(id) 
    ON DELETE RESTRICT;

-- 6. Add new RLS policies for Profiles (Parents)
CREATE POLICY "Profiles can be viewed by owners or active schools"
    ON public.profiles FOR SELECT
    USING (
        id = public.firebase_uid() 
        OR EXISTS (
            SELECT 1 FROM public.school_contracts 
            WHERE parent_id = public.profiles.id AND school_id = public.firebase_uid()
        )
    );

CREATE POLICY "Profiles can be updated by owners"
    ON public.profiles FOR UPDATE
    USING (id = public.firebase_uid());

CREATE POLICY "Profiles can be inserted by anyone during registration"
    ON public.profiles FOR INSERT
    WITH CHECK (id = public.firebase_uid() OR public.firebase_uid() IS NOT NULL);

-- 7. Add RLS policies for School Profiles
CREATE POLICY "School profiles viewable by anyone"
    ON public.school_profiles FOR SELECT
    USING (true);

CREATE POLICY "School profiles manageable by owners"
    ON public.school_profiles FOR ALL
    USING (id = public.firebase_uid());

-- 8. Add RLS policies for Merchant Profiles
CREATE POLICY "Merchant profiles viewable by owners or their clients"
    ON public.merchant_profiles FOR SELECT
    USING (
        id = public.firebase_uid()
        OR EXISTS (
            SELECT 1 FROM public.contracts
            WHERE merchant_user_id IN (SELECT id FROM public.users WHERE firebase_uid = public.firebase_uid())
            AND client_phone = public.merchant_profiles.phone_number
        )
    );

CREATE POLICY "Merchant profiles manageable by owners"
    ON public.merchant_profiles FOR ALL
    USING (id = public.firebase_uid());
