-- PostgreSQL database schema for FUTA (Firebase Auth & Supabase Compatible)

-- Enable UUID extension if not enabled (retained for non-auth IDs if desired)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES Table (Exclusively for parents/clients)
CREATE TABLE IF NOT EXISTS public.profiles (
    id TEXT PRIMARY KEY, 
    phone_number TEXT UNIQUE NOT NULL,
    first_name TEXT,
    last_name TEXT,
    address TEXT,
    role TEXT DEFAULT 'client' NOT NULL CHECK (role IN ('client')),
    sub_role TEXT DEFAULT 'parent' CHECK (sub_role IN ('parent')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 1b. SCHOOL_PROFILES Table (For school administrators)
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

-- 1c. MERCHANT_PROFILES Table (For merchant administrators)
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

-- 2. STUDENTS Table
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id TEXT REFERENCES public.profiles(id) ON DELETE CASCADE,
    school_id TEXT REFERENCES public.school_profiles(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    classroom TEXT,
    academic_score NUMERIC(5, 2) DEFAULT 0.0,
    attendance_rate NUMERIC(5, 2) DEFAULT 100.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on Students
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- 3. SCHOOL CONTRACTS Table
CREATE TABLE IF NOT EXISTS public.school_contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id TEXT REFERENCES public.school_profiles(id) ON DELETE RESTRICT,
    parent_id TEXT REFERENCES public.profiles(id) ON DELETE RESTRICT,
    total_tuition_due NUMERIC(12, 2) NOT NULL CHECK (total_tuition_due >= 0),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed')) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on School Contracts
ALTER TABLE public.school_contracts ENABLE ROW LEVEL SECURITY;

-- 4. SCHOOL INSTALLMENTS Table
CREATE TABLE IF NOT EXISTS public.school_installments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_id UUID REFERENCES public.school_contracts(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    amount_due NUMERIC(12, 2) NOT NULL CHECK (amount_due >= 0),
    amount_paid NUMERIC(12, 2) DEFAULT 0.0 CHECK (amount_paid >= 0),
    due_date DATE NOT NULL,
    status TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PARTIAL', 'PAID')) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT check_amount_paid CHECK (amount_paid <= amount_due)
);

-- Enable RLS on School Installments
ALTER TABLE public.school_installments ENABLE ROW LEVEL SECURITY;

-- 5. USERS Table (Merchant user mapping)
CREATE TABLE IF NOT EXISTS public.users (
    id SERIAL PRIMARY KEY,
    firebase_uid TEXT UNIQUE NOT NULL,
    phone TEXT,
    role TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on Users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 6. CONTRACTS Table (Merchant contracts)
CREATE TABLE IF NOT EXISTS public.contracts (
    id SERIAL PRIMARY KEY,
    merchant_user_id INTEGER REFERENCES public.users(id) ON DELETE RESTRICT,
    client_phone TEXT NOT NULL,
    currency TEXT DEFAULT 'FC' CHECK (currency IN ('FC', 'USD')) NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
    down_payment NUMERIC(12, 2) DEFAULT 0.0 CHECK (down_payment >= 0),
    installments_count INTEGER NOT NULL CHECK (installments_count > 0),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed')) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on Contracts
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;

-- 7. CONTRACT INSTALLMENTS Table (Merchant contract installments)
CREATE TABLE IF NOT EXISTS public.contract_installments (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER REFERENCES public.contracts(id) ON DELETE CASCADE,
    installment_number INTEGER NOT NULL,
    due_date DATE NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    paid_amount NUMERIC(12, 2) DEFAULT 0.0 CHECK (paid_amount >= 0),
    status TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PARTIAL', 'PAID')) NOT NULL,
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT check_paid_amount CHECK (paid_amount <= amount)
);

-- Enable RLS on Contract Installments
ALTER TABLE public.contract_installments ENABLE ROW LEVEL SECURITY;


-- =========================================================================
-- RLS POLICIES FOR SECURE ACCESS (Firebase UID string compatible)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.firebase_uid()
RETURNS TEXT AS $$
    SELECT COALESCE(
        nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'uid',
        nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'sub'
    );
$$ LANGUAGE sql STABLE;

-- Profiles Policies (Parents/Clients)
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

-- School Profiles Policies
CREATE POLICY "School profiles viewable by anyone"
    ON public.school_profiles FOR SELECT
    USING (true);

CREATE POLICY "School profiles manageable by owners"
    ON public.school_profiles FOR ALL
    USING (id = public.firebase_uid());

-- Merchant Profiles Policies
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

-- Students Policies
CREATE POLICY "View students related to parent or school"
    ON public.students FOR SELECT
    USING (parent_id = public.firebase_uid() OR school_id = public.firebase_uid());

CREATE POLICY "Manage students (school admin only)"
    ON public.students FOR ALL
    USING (school_id = public.firebase_uid());

-- School Contracts Policies
CREATE POLICY "View school contracts"
    ON public.school_contracts FOR SELECT
    USING (parent_id = public.firebase_uid() OR school_id = public.firebase_uid());

CREATE POLICY "Manage school contracts (school admin only)"
    ON public.school_contracts FOR ALL
    USING (school_id = public.firebase_uid());

-- School Installments Policies
CREATE POLICY "View school installments"
    ON public.school_installments FOR SELECT
    USING (contract_id IN (
        SELECT id FROM public.school_contracts 
        WHERE parent_id = public.firebase_uid() OR school_id = public.firebase_uid()
    ));

CREATE POLICY "Manage school installments (school admin only)"
    ON public.school_installments FOR ALL
    USING (contract_id IN (
        SELECT id FROM public.school_contracts 
        WHERE school_id = public.firebase_uid()
    ));

-- Users Policies (Merchant context)
CREATE POLICY "View or manage own user record"
    ON public.users FOR ALL
    USING (firebase_uid = public.firebase_uid());

-- Contracts Policies (Merchant contracts)
CREATE POLICY "View contracts (client or merchant)"
    ON public.contracts FOR SELECT
    USING (
        client_phone IN (SELECT phone_number FROM public.profiles WHERE id = public.firebase_uid())
        OR merchant_user_id IN (SELECT id FROM public.users WHERE firebase_uid = public.firebase_uid())
    );

CREATE POLICY "Manage contracts (merchant owner only)"
    ON public.contracts FOR ALL
    USING (merchant_user_id IN (SELECT id FROM public.users WHERE firebase_uid = public.firebase_uid()));

-- Contract Installments Policies (Merchant installments)
CREATE POLICY "View contract installments"
    ON public.contract_installments FOR SELECT
    USING (contract_id IN (
        SELECT id FROM public.contracts
        WHERE client_phone IN (SELECT phone_number FROM public.profiles WHERE id = public.firebase_uid())
        OR merchant_user_id IN (SELECT id FROM public.users WHERE firebase_uid = public.firebase_uid())
    ));

CREATE POLICY "Manage contract installments (merchant owner only)"
    ON public.contract_installments FOR ALL
    USING (contract_id IN (
        SELECT id FROM public.contracts
        WHERE merchant_user_id IN (SELECT id FROM public.users WHERE firebase_uid = public.firebase_uid())
    ));

