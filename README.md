# KeyDiary — Private Encrypted Family Information Vault

KeyDiary is a production-grade, private, client-side encrypted family information vault designed for two trusted users: a father and his child/co-guardian.

KeyDiary replaces vulnerable physical notebooks containing sensitive records:
* **Investments**: Fixed deposits, mutual funds, shares, and maturity dates
* **Bank & Cards**: Account numbers, card limits, branch manager contacts
* **Keys & Places**: Physical locker keys, almirah secret spots, safe combinations
* **Insurance**: Life policies (LIC), health insurance, nominee allocations
* **Property**: Title deeds, mutation certificates, tax receipts
* **Important Documents**: Passports, Aadhaar, PAN, certificates
* **Emergency Medical**: Directives, blood groups, doctor contacts

---

## Technology Stack

- **Frontend**: Flutter (Dart 3, Material 3)
- **Theme**: Tactile Warm Modernism (Full Light & Dark Theme support)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Navigation**: GoRouter (`go_router`)
- **Backend**: Supabase (PostgreSQL, Row Level Security, Supabase Auth, Private Storage)
- **Cryptography**: Audited primitives via `cryptography` (AES-256-GCM, PBKDF2-HMAC-SHA256)
- **Local Security**: Android Keystore / iOS Keychain via `flutter_secure_storage`
- **Biometrics**: `local_auth` (Fingerprint / Face ID)

---

## Architecture Highlights

1. **Client-Side Zero-Knowledge Encryption**:
   Plaintext values never touch the network or database unencrypted. All records are encrypted locally before upload using an authenticated AES-256-GCM cipher with unique nonces.
2. **Shared Vault Key Management**:
   A randomly generated 256-bit Vault Encryption Key (VEK) is wrapped individually for each member, allowing multi-user family access without plaintext secrets on servers.
3. **Emergency Recovery Store**:
   An isolated `emergency_vault` database schema stores synchronized recovery records for designated family scenarios with independent RLS policies.
4. **Multi-Generational Accessibility**:
   Generous touch targets (48px+), high-contrast calm color palettes, Plus Jakarta Sans typography, and JetBrains Mono for masked numeric credentials.

---

## Database Migrations

Database setup files are located in `supabase/migrations/`:
- `001_initial_schema.sql`: Profiles, vaults, members, categories, entries, entry_fields, attachments, and the emergency schema.
- `002_rls_policies.sql`: Row Level Security policies enforcing vault isolation.
- `003_storage_and_audit.sql`: Private storage bucket policies and non-sensitive audit logging.
- `supabase/seed.sql`: Reference seed definitions.

To apply migrations to your Supabase project:
```bash
supabase db push
# Or copy/paste the migration scripts into the Supabase Dashboard SQL Editor
```

---

## Environment Setup

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Set your public credentials:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```
*(Note: If `.env` is omitted, KeyDiary automatically boots into Local Secure Hardware Enclave mode for offline development and testing.)*

---

## Running Locally

```bash
# Get dependencies
flutter pub get

# Run unit tests
flutter test

# Run application
flutter run
```

---

## Security Documentation

For detailed threat models, cryptographic wire formats, and emergency recovery specifications, refer to [docs/SECURITY.md](docs/SECURITY.md).
