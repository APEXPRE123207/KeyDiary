-- ==============================================================================
-- Migration: 002_rls_policies.sql
-- Row Level Security (RLS) Policies for KeyDiary
-- ==============================================================================

-- Enable RLS on all public tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vault_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vault_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

-- Enable RLS on emergency_vault tables
ALTER TABLE emergency_vault.entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_vault.entry_fields ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- Helper Function: Check if user is a member of a vault
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_vault_member(v_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.vault_members
        WHERE vault_id = v_id AND user_id = auth.uid()
    );
$$;

-- ------------------------------------------------------------------------------
-- Helper Function: Check if user is an OWNER of a vault
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_vault_owner(v_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.vault_members
        WHERE vault_id = v_id AND user_id = auth.uid() AND role = 'OWNER'
    );
$$;

-- ------------------------------------------------------------------------------
-- 1. Profiles Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Users can read own profile and profiles of co-members"
ON public.profiles FOR SELECT
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.vault_members vm1
        JOIN public.vault_members vm2 ON vm1.vault_id = vm2.vault_id
        WHERE vm1.user_id = auth.uid() AND vm2.user_id = profiles.user_id
    )
);

CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 2. Vaults Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Members can view their vaults"
ON public.vaults FOR SELECT
USING (public.is_vault_member(id));

CREATE POLICY "Authenticated users can create vaults"
ON public.vaults FOR INSERT
WITH CHECK (created_by = auth.uid());

CREATE POLICY "Owners can update their vaults"
ON public.vaults FOR UPDATE
USING (public.is_vault_owner(id))
WITH CHECK (public.is_vault_owner(id));

CREATE POLICY "Owners can delete their vaults"
ON public.vaults FOR DELETE
USING (public.is_vault_owner(id));

-- ------------------------------------------------------------------------------
-- 3. Vault Members Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Members can view member list of their vaults"
ON public.vault_members FOR SELECT
USING (public.is_vault_member(vault_id));

CREATE POLICY "Vault creators can add initial owner member"
ON public.vault_members FOR INSERT
WITH CHECK (
    user_id = auth.uid()
    OR public.is_vault_owner(vault_id)
);

CREATE POLICY "Owners can update member roles or keys"
ON public.vault_members FOR UPDATE
USING (public.is_vault_owner(vault_id) OR user_id = auth.uid());

CREATE POLICY "Owners can remove members or members can leave"
ON public.vault_members FOR DELETE
USING (public.is_vault_owner(vault_id) OR user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 4. Vault Invitations Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Members can view invitations for their vault or own email"
ON public.vault_invitations FOR SELECT
USING (
    public.is_vault_member(vault_id)
    OR invited_email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

CREATE POLICY "Owners can create invitations"
ON public.vault_invitations FOR INSERT
WITH CHECK (public.is_vault_owner(vault_id) AND invited_by = auth.uid());

CREATE POLICY "Owners and invitees can update invitation status"
ON public.vault_invitations FOR UPDATE
USING (
    public.is_vault_owner(vault_id)
    OR invited_email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

-- ------------------------------------------------------------------------------
-- 5. Categories Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Members can view categories in their vault"
ON public.categories FOR SELECT
USING (public.is_vault_member(vault_id));

CREATE POLICY "Members can create categories in their vault"
ON public.categories FOR INSERT
WITH CHECK (public.is_vault_member(vault_id));

CREATE POLICY "Members can update categories in their vault"
ON public.categories FOR UPDATE
USING (public.is_vault_member(vault_id))
WITH CHECK (public.is_vault_member(vault_id));

CREATE POLICY "Owners and creators can delete categories"
ON public.categories FOR DELETE
USING (public.is_vault_owner(vault_id) OR created_by = auth.uid());

-- ------------------------------------------------------------------------------
-- 6. Entries Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Members can view encrypted entries in their vault"
ON public.entries FOR SELECT
USING (public.is_vault_member(vault_id));

CREATE POLICY "Members can create entries in their vault"
ON public.entries FOR INSERT
WITH CHECK (public.is_vault_member(vault_id));

CREATE POLICY "Members can update entries in their vault"
ON public.entries FOR UPDATE
USING (public.is_vault_member(vault_id))
WITH CHECK (public.is_vault_member(vault_id));

CREATE POLICY "Members can delete entries in their vault"
ON public.entries FOR DELETE
USING (public.is_vault_member(vault_id));

-- ------------------------------------------------------------------------------
-- 7. Entry Fields Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Members can view fields of entries in their vault"
ON public.entry_fields FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.entries e
        WHERE e.id = entry_fields.entry_id AND public.is_vault_member(e.vault_id)
    )
);

CREATE POLICY "Members can create fields for entries in their vault"
ON public.entry_fields FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.entries e
        WHERE e.id = entry_fields.entry_id AND public.is_vault_member(e.vault_id)
    )
);

CREATE POLICY "Members can update fields for entries in their vault"
ON public.entry_fields FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.entries e
        WHERE e.id = entry_fields.entry_id AND public.is_vault_member(e.vault_id)
    )
);

CREATE POLICY "Members can delete fields for entries in their vault"
ON public.entry_fields FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM public.entries e
        WHERE e.id = entry_fields.entry_id AND public.is_vault_member(e.vault_id)
    )
);

-- ------------------------------------------------------------------------------
-- 8. Attachments Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Members can view attachments for entries in their vault"
ON public.attachments FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.entries e
        WHERE e.id = attachments.entry_id AND public.is_vault_member(e.vault_id)
    )
);

CREATE POLICY "Members can insert attachments for entries in their vault"
ON public.attachments FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.entries e
        WHERE e.id = attachments.entry_id AND public.is_vault_member(e.vault_id)
    )
);

CREATE POLICY "Members can delete attachments for entries in their vault"
ON public.attachments FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM public.entries e
        WHERE e.id = attachments.entry_id AND public.is_vault_member(e.vault_id)
    )
);

-- ------------------------------------------------------------------------------
-- Emergency Vault Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Authorized vault members can view emergency store"
ON emergency_vault.entries FOR SELECT
USING (public.is_vault_member(vault_id));

CREATE POLICY "Members can sync entries into emergency store"
ON emergency_vault.entries FOR INSERT
WITH CHECK (public.is_vault_member(vault_id) AND synced_by = auth.uid());

CREATE POLICY "Members can update emergency entries"
ON emergency_vault.entries FOR UPDATE
USING (public.is_vault_member(vault_id));

CREATE POLICY "Members can delete emergency entries"
ON emergency_vault.entries FOR DELETE
USING (public.is_vault_member(vault_id));

CREATE POLICY "Members can view emergency entry fields"
ON emergency_vault.entry_fields FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM emergency_vault.entries ee
        WHERE ee.id = emergency_vault.entry_fields.emergency_entry_id AND public.is_vault_member(ee.vault_id)
    )
);

CREATE POLICY "Members can insert emergency entry fields"
ON emergency_vault.entry_fields FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM emergency_vault.entries ee
        WHERE ee.id = emergency_vault.entry_fields.emergency_entry_id AND public.is_vault_member(ee.vault_id)
    )
);

CREATE POLICY "Members can delete emergency entry fields"
ON emergency_vault.entry_fields FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM emergency_vault.entries ee
        WHERE ee.id = emergency_vault.entry_fields.emergency_entry_id AND public.is_vault_member(ee.vault_id)
    )
);
