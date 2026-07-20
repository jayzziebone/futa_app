-- Migration: Add school_id to students table for multi-school isolation
-- Run this in your Supabase SQL Editor:

-- 1. Add column
ALTER TABLE public.students 
ADD COLUMN IF NOT EXISTS school_id TEXT REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 2. Populate existing student records with their school_id from contracts
UPDATE public.students s
SET school_id = c.school_id
FROM public.school_installments i
JOIN public.school_contracts c ON i.contract_id = c.id
WHERE s.id = i.student_id AND s.school_id IS NULL;
