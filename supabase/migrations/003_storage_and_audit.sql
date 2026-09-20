-- ==============================================================================
-- Migration: 003_storage_and_audit.sql
-- Storage Buckets & Non-sensitive Audit Trail
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Private Storage Bucket Setup
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'vault_attachments',
    'vault_attachments',
    false,
    52428800, -- 50MB limit per document
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'text/plain']
)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Storage RLS Policies
CREATE POLICY "Authenticated users can read attachments for their vaults"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'vault_attachments'
    AND (
        EXISTS (
            SELECT 1 FROM public.attachments a
            JOIN public.entries e ON a.entry_id = e.id
            WHERE a.storage_path = storage.objects.name
            AND public.is_vault_member(e.vault_id)
        )
    )
);

CREATE POLICY "Authenticated vault members can upload attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'vault_attachments'
);

CREATE POLICY "Authenticated vault members can delete attachments"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'vault_attachments'
    AND (
        EXISTS (
            SELECT 1 FROM public.attachments a
            JOIN public.entries e ON a.entry_id = e.id
            WHERE a.storage_path = storage.objects.name
            AND public.is_vault_member(e.vault_id)
        )
    )
);

-- ------------------------------------------------------------------------------
-- 2. Audit Logs Table (Zero Plaintext Secrets)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vault_id UUID NOT NULL REFERENCES public.vaults(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL, -- e.g. 'ENTRY_CREATED', 'ENTRY_UPDATED', 'MEMBER_JOINED'
    entity_type TEXT NOT NULL, -- e.g. 'ENTRY', 'CATEGORY', 'VAULT', 'SECURITY'
    entity_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb, -- metadata NEVER contains secret values
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_vault ON public.audit_logs(vault_id, created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view audit logs of their vault"
ON public.audit_logs FOR SELECT
USING (public.is_vault_member(vault_id));

CREATE POLICY "Members can insert audit logs for their actions"
ON public.audit_logs FOR INSERT
WITH CHECK (public.is_vault_member(vault_id) AND user_id = auth.uid());
