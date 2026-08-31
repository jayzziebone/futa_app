-- Migration 04: School Networks & Hierarchical Aggregator Accounts
-- Supports parent network entities (e.g., RECC) overseeing constituent schools (e.g., RECC-001, RECC-002)

-- 1. Create School Networks table
CREATE TABLE IF NOT EXISTS public.school_networks (
    id TEXT PRIMARY KEY,                       -- Firebase UID of the network administrator
    network_code TEXT UNIQUE NOT NULL,         -- Unique code (e.g., 'RECC', 'ECC', 'CS-KIN')
    name TEXT NOT NULL,                        -- Name of the organization / diocese / school network
    admin_name TEXT NOT NULL,                  -- Responsible coordinator / administrator
    phone_number TEXT UNIQUE NOT NULL,         -- Phone number for OTP login
    address TEXT,                              -- Headquarters / regional office address
    logo_url TEXT,                             -- Optional logo / badge URL
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Add Row Level Security (RLS) to School Networks
ALTER TABLE public.school_networks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "School networks viewable by anyone"
    ON public.school_networks FOR SELECT
    USING (true);

CREATE POLICY "School networks manageable by owners"
    ON public.school_networks FOR ALL
    USING (id = public.firebase_uid() OR public.firebase_uid() IS NOT NULL);

-- 3. Update school_profiles table with network relation
ALTER TABLE public.school_profiles 
    ADD COLUMN IF NOT EXISTS network_id TEXT REFERENCES public.school_networks(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS network_code TEXT;

CREATE INDEX IF NOT EXISTS idx_school_profiles_network_id ON public.school_profiles(network_id);
CREATE INDEX IF NOT EXISTS idx_school_profiles_network_code ON public.school_profiles(network_code);

-- 4. Enable network administrators to view contracts, installments, and students under their jurisdiction
CREATE POLICY "Network admins can view member schools contracts"
    ON public.school_contracts FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.school_profiles
            WHERE school_profiles.id = school_contracts.school_id
            AND school_profiles.network_id = public.firebase_uid()
        )
    );

CREATE POLICY "Network admins can view member schools installments"
    ON public.school_installments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.school_contracts
            JOIN public.school_profiles ON school_profiles.id = school_contracts.school_id
            WHERE school_contracts.id = school_installments.contract_id
            AND school_profiles.network_id = public.firebase_uid()
        )
    );

CREATE POLICY "Network admins can view member schools students"
    ON public.students FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.school_profiles
            WHERE school_profiles.id = students.school_id
            AND school_profiles.network_id = public.firebase_uid()
        )
    );
