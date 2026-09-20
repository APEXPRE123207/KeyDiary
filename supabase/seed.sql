-- ==============================================================================
-- KeyDiary Database Automation: Default Category Provisioning Trigger
-- ==============================================================================

-- Whenever a user creates a new vault in public.vaults, this trigger automatically
-- seeds the 10 standard categories for that vault with default security settings.

CREATE OR REPLACE FUNCTION public.seed_default_vault_categories()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.categories (vault_id, name, description, icon, color, position, is_locked, created_by)
    VALUES
        (NEW.id, 'Investments', 'Mutual funds, FDs, stocks & nominee records', 'savings', '#1D5D5B', 1, true, NEW.created_by),
        (NEW.id, 'Bank Accounts', 'Savings accounts, branch IFSC & cheque books', 'account_balance', '#1D5D5B', 2, true, NEW.created_by),
        (NEW.id, 'Keys & Places', 'Physical locker keys, almirah safe spots & combinations', 'key', '#1D5D5B', 3, false, NEW.created_by),
        (NEW.id, 'Insurance Policies', 'Life policies (LIC), health cards & premium dates', 'verified_user', '#1D5D5B', 4, false, NEW.created_by),
        (NEW.id, 'Property & Assets', 'Deeds, mutation certificates, land papers & tax slips', 'home', '#565F69', 5, false, NEW.created_by),
        (NEW.id, 'Cards & Banking', 'Debit/credit cards, CVV, expiry & limits', 'credit_card', '#565F69', 6, true, NEW.created_by),
        (NEW.id, 'Important Docs', 'Passports, Aadhar, voter cards & certificates', 'description', '#1D5D5B', 7, false, NEW.created_by),
        (NEW.id, 'Loans & Debts', 'Home loans, personal borrowing & EMI dates', 'payments', '#565F69', 8, false, NEW.created_by),
        (NEW.id, 'Emergency & Medical', 'Blood groups, hospital ID, emergency contacts', 'emergency', '#BA1A1A', 9, false, NEW.created_by),
        (NEW.id, 'Other Personal Records', 'Miscellaneous family information', 'folder', '#353F3E', 10, false, NEW.created_by);
    RETURN NEW;
END;
$$;

-- Attach trigger to public.vaults
DROP TRIGGER IF EXISTS trg_seed_vault_categories ON public.vaults;
CREATE TRIGGER trg_seed_vault_categories
    AFTER INSERT ON public.vaults
    FOR EACH ROW
    EXECUTE FUNCTION public.seed_default_vault_categories();
