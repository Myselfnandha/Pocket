-- ==============================================================================
-- Pocket Transaction Tracker: Supabase PostgreSQL Cloud Schema & RLS Policies
-- Migration: 20260830134500_create_pocket_backups.sql
-- ==============================================================================

-- 1. Create pocket_backups table
CREATE TABLE IF NOT EXISTS public.pocket_backups (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    backup_data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Performance index on user_id
CREATE INDEX IF NOT EXISTS idx_pocket_backups_user_id ON public.pocket_backups(user_id);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.pocket_backups ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policy: Authenticated users can only read their own backup data
CREATE POLICY "Users can read own backups"
    ON public.pocket_backups
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 5. RLS Policy: Authenticated users can insert their own backup data
-- Server enforces identity via auth.uid() check
CREATE POLICY "Users can insert own backups"
    ON public.pocket_backups
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- 6. RLS Policy: Authenticated users can update their own backup data
CREATE POLICY "Users can update own backups"
    ON public.pocket_backups
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 7. RLS Policy: Authenticated users can delete their own backup data
CREATE POLICY "Users can delete own backups"
    ON public.pocket_backups
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);
