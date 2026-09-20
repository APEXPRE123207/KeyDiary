# KeyDiary — Private Encrypted Family Information Vault

KeyDiary is a production-grade, private, client-side encrypted family information vault mobile application designed for two trusted users: a father and his child/co-guardian.

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
- **Photo Attachments**: `image_picker` (Camera capture & Gallery selection with AES-256 encryption)
- **CI/CD**: GitHub Actions (Cloud automated APK build & artifact publishing)

---

## Architecture Highlights

1. **Client-Side Zero-Knowledge Encryption**:
   Plaintext values never touch the network or database unencrypted. All records and image attachments are encrypted locally on-device using AES-256-GCM with unique 12-byte nonces.
2. **Dedicated Emergency Recovery Store (`emergency_vault`)**:
   An isolated database schema stores true values for emergency family access when the emergency sync toggle is enabled by co-guardians.
3. **Photo & Document Image Upload**:
   - 📸 **Camera capture**: Snap photos of physical passbooks, locker keys, and paper receipts.
   - 🖼️ **Gallery selection**: Select images from your device photo library.
   - 🔒 **Zero-knowledge**: Image bytes are encrypted locally with AES-256 before upload to private Supabase storage.
   - 👁️ **In-app preview**: Full decrypted thumbnail and tap-to-view modal preview in the record detail screen.

---

## Supabase Step-by-Step Setup

### 1. Create Your Project
1. Log in to [supabase.com](https://supabase.com) and click **New Project**.
2. Set your Project Name (e.g. `KeyDiary`) and generate a strong database password.
3. Select your closest Region (e.g., `South Asia (Mumbai)`).
4. **Row Level Security (RLS)**: Keep **"Enable Row Level Security" checked**.
5. Click **Create new project** and wait ~1 minute for initialization.

### 2. Run Database Migrations in SQL Editor
Navigate to the **SQL Editor** tab in the left sidebar and run the SQL scripts in this exact order:
1. **`supabase/migrations/001_initial_schema.sql`**: Run to create all core tables and the `emergency_vault` schema.
2. **`supabase/migrations/002_rls_policies.sql`**: Run to enforce strict Row Level Security policies.
3. **`supabase/migrations/003_storage_and_audit.sql`**: Run to create the private `vault_attachments` storage bucket and audit logs.
4. **`supabase/seed.sql`**: Run to install the automatic trigger that provisions default categories whenever a new vault is created.

### 3. Copy API Credentials
1. Go to **Project Settings** (gear icon) → **API**.
2. Copy your **Project URL** (`https://xxxx.supabase.co`).
3. Copy your **anon / public key** (under *Project API keys*).

---

## Cloud APK Build via GitHub Actions (Recommended)

You do **not** need to build the APK locally or wait on Gradle downloads. GitHub Actions builds the release APK in the cloud with gigabit speeds.

### Step 1: Add Secrets to GitHub
1. Open your GitHub repository: [https://github.com/APEXPRE123207/KeyDiary](https://github.com/APEXPRE123207/KeyDiary).
2. Go to **Settings** → **Secrets and variables** → **Actions**.
3. Under **Repository secrets**, click **New repository secret** and add:
   - Name: `SUPABASE_URL` | Value: Paste your Supabase Project URL
   - Name: `SUPABASE_ANON_KEY` | Value: Paste your Supabase `anon` public key

### Step 2: Download Your Built APK
1. Go to the **Actions** tab in GitHub.
2. Select the **Build KeyDiary Android APK** workflow.
3. Click **Run workflow** (or simply push a commit to trigger it automatically).
4. When the build finishes (~2 minutes), click the completed run.
5. Scroll down to **Artifacts** at the bottom and download **`KeyDiary-Release-APK`**.
6. Transfer or open the `.apk` on your phone to install!

---

## Freeing Up Local PC Storage

If you are running low on disk space on your local computer, run these commands to wipe all local compile artifacts and temporary caches:

```bash
# 1. Clean Flutter build output and generated files
flutter clean

# 2. In PowerShell, delete local Gradle caches if present
Remove-Item -Path "android/.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE/.gradle/.tmp" -Recurse -Force -ErrorAction SilentlyContinue
```

*(Because the app is built on GitHub Actions, your local PC does not need any heavy build outputs or Gradle caches!)*

---

## Security & Documentation

- For detailed threat modeling, cryptographic specifications, and key lifecycles, see [docs/SECURITY.md](docs/SECURITY.md).
- To test the app locally on Windows desktop without Android overhead:
  ```bash
  flutter run -d windows
  ```
- To test on Chrome:
  ```bash
  flutter run -d chrome
  ```
