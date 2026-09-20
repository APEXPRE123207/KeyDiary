-- ==============================================================================
-- Migration: 001_initial_schema.sql
-- KeyDiary Private Encrypted Vault & Emergency Access Store
-- ==============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 1. Profiles Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);

-- ------------------------------------------------------------------------------
-- 2. Vaults Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vaults (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vaults_created_by ON public.vaults(created_by);

-- ------------------------------------------------------------------------------
-- 3. Vault Members Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vault_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vault_id UUID NOT NULL REFERENCES public.vaults(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('OWNER', 'MEMBER')),
    encrypted_vault_key TEXT NOT NULL,
    key_wrap_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(vault_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_vault_members_user ON public.vault_members(user_id);
CREATE INDEX IF NOT EXISTS idx_vault_members_vault ON public.vault_members(vault_id);

-- ------------------------------------------------------------------------------
-- 4. Vault Invitations Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vault_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vault_id UUID NOT NULL REFERENCES public.vaults(id) ON DELETE CASCADE,
    invited_email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('OWNER', 'MEMBER')),
    invited_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'REVOKED', 'EXPIRED')),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invitations_email ON public.vault_invitations(invited_email);
CREATE INDEX IF NOT EXISTS idx_invitations_vault ON public.vault_invitations(vault_id);

-- ------------------------------------------------------------------------------
-- 5. Categories Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vault_id UUID NOT NULL REFERENCES public.vaults(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT NOT NULL DEFAULT 'folder',
    color TEXT DEFAULT '#1D5D5B',
    position INT NOT NULL DEFAULT 0,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_categories_vault ON public.categories(vault_id);
CREATE INDEX IF NOT EXISTS idx_categories_position ON public.categories(vault_id, position);

-- ------------------------------------------------------------------------------
-- 6. Entries Table (Encrypted Vault Data)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    vault_id UUID NOT NULL REFERENCES public.vaults(id) ON DELETE CASCADE,
    title_encrypted TEXT NOT NULL,
    notes_encrypted TEXT,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_entries_category ON public.entries(category_id);
CREATE INDEX IF NOT EXISTS idx_entries_vault ON public.entries(vault_id);

-- ------------------------------------------------------------------------------
-- 7. Entry Fields Table (Dynamic Custom Fields, Encrypted)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.entry_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES public.entries(id) ON DELETE CASCADE,
    field_name_encrypted TEXT NOT NULL,
    field_type TEXT NOT NULL CHECK (field_type IN (
        'TEXT', 'LONG_TEXT', 'NUMBER', 'CURRENCY', 'DATE',
        'PHONE', 'EMAIL', 'URL', 'SECRET', 'BOOLEAN',
        'IMAGE', 'DOCUMENT', 'LOCATION_DESCRIPTION'
    )),
    field_value_encrypted TEXT NOT NULL,
    position INT NOT NULL DEFAULT 0,
    is_sensitive BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_entry_fields_entry ON public.entry_fields(entry_id);
CREATE INDEX IF NOT EXISTS idx_entry_fields_position ON public.entry_fields(entry_id, position);

-- ------------------------------------------------------------------------------
-- 8. Attachments Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES public.entries(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    file_name_encrypted TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_attachments_entry ON public.attachments(entry_id);

-- ==============================================================================
-- Dedicated Emergency Access Store Schema
-- (User explicit requirement: isolated database/schema for emergency plaintext values)
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS emergency_vault;

CREATE TABLE IF NOT EXISTS emergency_vault.entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_entry_id UUID NOT NULL,
    vault_id UUID NOT NULL REFERENCES public.vaults(id) ON DELETE CASCADE,
    category_name TEXT NOT NULL,
    title_plaintext TEXT NOT NULL,
    notes_plaintext TEXT,
    synced_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_emergency_entries_vault ON emergency_vault.entries(vault_id);
CREATE INDEX IF NOT EXISTS idx_emergency_entries_orig ON emergency_vault.entries(original_entry_id);

CREATE TABLE IF NOT EXISTS emergency_vault.entry_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    emergency_entry_id UUID NOT NULL REFERENCES emergency_vault.entries(id) ON DELETE CASCADE,
    field_name TEXT NOT NULL,
    field_type TEXT NOT NULL,
    field_value TEXT NOT NULL,
    is_sensitive BOOLEAN NOT NULL DEFAULT FALSE,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_emergency_fields_entry ON emergency_vault.entry_fields(emergency_entry_id);
