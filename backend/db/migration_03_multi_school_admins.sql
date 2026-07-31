-- Migration 03: Multi-Admin Support for Schools
-- Allows up to 4 administrators per school institution

-- 1. Add invite_code & max_admins columns to school_profiles if not present
ALTER TABLE public.school_profiles 
ADD COLUMN IF NOT EXISTS invite_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS max_admins INT DEFAULT 4;

-- 2. Create school_admins mapping table
CREATE TABLE IF NOT EXISTS public.school_admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id TEXT NOT NULL REFERENCES public.school_profiles(id) ON DELETE CASCADE,
    user_id TEXT, -- Firebase UID of the admin (null if pre-registered, set upon first SMS login)
    admin_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    role_title TEXT DEFAULT 'Administrateur',
    status TEXT DEFAULT 'ACTIVE', -- 'ACTIVE' or 'PENDING_INVITE'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on school_admins
ALTER TABLE public.school_admins ENABLE ROW LEVEL SECURITY;

-- Permissive policies for school_admins
CREATE POLICY "Allow read access for authenticated users to school_admins"
ON public.school_admins FOR SELECT USING (true);

CREATE POLICY "Allow write access for authenticated users to school_admins"
ON public.school_admins FOR ALL USING (true);

-- Index for fast lookup by user_id and phone_number
CREATE INDEX IF NOT EXISTS idx_school_admins_user_id ON public.school_admins(user_id);
CREATE INDEX IF NOT EXISTS idx_school_admins_phone_number ON public.school_admins(phone_number);
CREATE INDEX IF NOT EXISTS idx_school_admins_school_id ON public.school_admins(school_id);
