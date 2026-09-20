# KeyDiary 🗝️📔
### *Because keeping all your bank accounts, FD receipts, and locker keys in a fading 1998 diary behind the winter blankets is not a security strategy.*

---

## The Origin Story

Every household has one. 

A legendary, slightly torn, ruled notebook. Usually resting in the deepest, darkest drawer of a Godrej steel almirah, nestled underneath 14 layers of old income tax returns and a sweater nobody has worn since 2004. 

Inside this sacred diary lies your family’s entire financial existence:
- Fixed deposit certificates where the ink faded during the Obama administration.
- Account numbers scribbled next to the name of a bank branch manager named "Sharma ji" who retired in 2012.
- The location of the spare locker key: *"Behind the third tin of Horlicks on the kitchen loft."*
- Passwords written like: `BankPass@1234 (do not share)`.

If that diary gets lost, eaten by termites, or soaked during a monsoon leak, your family’s net worth turns into an unsolved archeological mystery. 

**KeyDiary** replaces that panic with a private, client-side encrypted vault built specifically for two trusted family members (e.g. Dad and Co-Guardian / Child). It keeps your vital records organized, searchable, and synced across devices — without handing your secrets to Big Tech or unencrypted cloud databases.

---

## How It Actually Works (The Good Stuff)

### 1. Zero-Knowledge Encryption (Even Supabase Can’t Snoop)
Unlike popular "cloud notes" apps that store your data in plain text so their AI can read your grocery list, KeyDiary encrypts **everything on your phone** before a single byte leaves the device:
- **Algorithm**: Military-grade **AES-256-GCM** with unique 12-byte cryptographically secure nonces for every single field and document.
- **Master Keys**: Generated locally and sealed inside your phone's hardware enclave (Android Keystore / iOS Keychain).
- **What the database sees**: Jumbled, unintelligible ciphertext. If an attacker breaches the server, all they steal is high-entropy digital noise.

### 2. The "Break-Glass" Emergency Store (`emergency_vault`)
*“What if Dad forgets his master password and the phone falls into a bucket of water?”*

We thought of that. KeyDiary features a dual-schema PostgreSQL architecture:
- `public.*`: Normal zero-knowledge encrypted store for daily life.
- `emergency_vault.*`: A physically isolated database schema that stores emergency plaintext values **only when the co-guardian syncs it**. 
If worst comes to worst and client keys are permanently lost, an authorized family member can log straight into the Supabase dashboard and read the vital recovery details in clean SQL tables.

### 3. Quick Unlock: 6-Digit Master PIN & Biometrics
- **Biometrics**: Tap and go with Fingerprint or Face ID via your device's hardware Secure Enclave.
- **6-Digit Master PIN**: Protected by **PBKDF2-HMAC-SHA256** (100,000 rounds) and protected against brute force:
  - 3 wrong tries: 30-second penalty box.
  - 5 wrong tries: 60-second lockout.
  - 10 wrong tries: 5-minute walk of shame.
- **Tactile Feedback**: Subtle error shake on the PIN dots if you fat-finger your code.

### 4. No Email Spam, Just Member Names
Nobody wants to remember which obscure email they signed up with or wait 15 minutes for a verification link that lands in the Spam folder. You log in with your **Member Name** (e.g. `Dad`, `Child`, `Mom`) and your password. That’s it.

### 5. Encrypted Photo Capture
- Snap a photo of a physical passbook, paper deed, or safe key using the in-app camera.
- The raw image bytes are encrypted in memory on your phone with AES-256 before being uploaded to a private, non-public Supabase storage bucket.
- Preview them anytime with instant in-app decryption.

---

## The 10 Family Vault Categories

KeyDiary automatically provisions these categories the moment your vault is born:

| Category | What You Should Actually Put Here |
| :--- | :--- |
| **Investments & FDs** | Fixed deposits, mutual funds, demat accounts, maturity dates, interest rates. |
| **Bank Accounts & Cards** | Savings/current accounts, IFSC codes, debit card emergency hotlines. |
| **Keys & Safe Spots** | Godrej locker combinations, duplicate car keys, safe deposit boxes. |
| **Life & Health Insurance** | LIC policy numbers, premium due dates, TPA hospital cashless card info. |
| **Property & Real Estate** | Flat registration deeds, mutation numbers, holding tax receipts. |
| **Important Documents** | Passport numbers, Aadhaar, PAN cards, birth certificates. |
| **Loans & Liabilities** | Home loans, car EMI schedules, outstanding personal dues. |
| **Emergency Medical** | Blood groups, regular prescriptions, primary family doctor contact. |
| **Subscriptions & Utilities** | Electricity consumer numbers, LPG gas booking IDs, Wi-Fi router logins. |
| **Private Family Diary** | Any personal message, family directive, or confidential note. |

---

## Supabase Backend Setup (5 Minutes Flat)

KeyDiary uses Supabase for authentication, PostgreSQL storage, and private file buckets.

### Step 1: Create a Supabase Project
1. Head over to [supabase.com](https://supabase.com) and click **New Project**.
2. Name it `KeyDiary` (or whatever you like).
3. Set a strong database password and choose your closest region (e.g. `Mumbai` or `Singapore`).
4. **Row Level Security (RLS)**: Leave **"Enable Row Level Security" checked**.
5. Click **Create Project** and give it ~60 seconds to spin up.

### Step 2: Run the SQL Migrations
Open the **SQL Editor** tab in the Supabase dashboard and run these four scripts in order (copy-paste from the repo):

1. **`supabase/migrations/001_initial_schema.sql`**
   *Creates all core tables (`vaults`, `members`, `entries`, `entry_fields`, `attachments`) plus the isolated `emergency_vault` schema.*
2. **`supabase/migrations/002_rls_policies.sql`**
   *Enforces strict Row Level Security rules so users can only ever access vaults they belong to.*
3. **`supabase/migrations/003_storage_and_audit.sql`**
   *Configures the private `vault_attachments` storage bucket and sets up tamper-evident audit logging.*
4. **`supabase/seed.sql`**
   *Installs the automated PostgreSQL trigger that provisions all 10 default categories the moment a new vault is created.*

### Step 3: Grab Your API Keys
1. Go to **Project Settings** (gear icon) → **API**.
2. Note your **Project URL** (`https://xxxxxxxxxxxxxxxx.supabase.co`).
3. Note your **anon / public key** (`eyJhbGci...`).

---

## Cloud APK Build via GitHub Actions (Zero Local Hassle)

Building Android apps locally usually means downloading a 2GB Android NDK, watching Gradle daemons chew through your RAM, and praying Maven Central doesn't throttle your connection. 

**Don't do that to your laptop.** Let GitHub Actions compile your release APK in the cloud in under 2 minutes:

### 1. Add Secrets to Your GitHub Repo
1. Open your repository: [https://github.com/APEXPRE123207/KeyDiary](https://github.com/APEXPRE123207/KeyDiary).
2. Go to **Settings** → **Secrets and variables** → **Actions**.
3. Click **New repository secret** and add:
   * **Name**: `SUPABASE_URL` | **Value**: Your Supabase project URL
   * **Name**: `SUPABASE_ANON_KEY` | **Value**: Your Supabase `anon` public key

### 2. Trigger the Build
1. Go to the **Actions** tab in your repository.
2. Click **Build KeyDiary Android APK** in the left sidebar.
3. Click **Run workflow** → **Run workflow** (or simply push any commit to `main`).
4. When the run finishes (~2 minutes), click on it.
5. Scroll down to **Artifacts** at the bottom and download **`KeyDiary-Release-APK`**.
6. Unzip, copy the APK to your phone, install, and you're good to go!

---

## Running Locally Without Burning Your CPU

If you want to run or test the app on your computer without running a heavy Android emulator or Gradle:

```bash
# Run instantly as a native Windows desktop app:
flutter run -d windows

# Or run in Chrome browser:
flutter run -d chrome

# Run all security and cryptographic tests:
flutter test
```

### Free Up Local Storage
If you've been running low on disk space, wipe all local build leftovers with:

```powershell
# In PowerShell:
flutter clean
Remove-Item -Path "android/.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE/.gradle/.tmp" -Recurse -Force -ErrorAction SilentlyContinue
```

---

## Security Specifications

* **Symmetric Encryption**: AES-256-GCM authenticated encryption (12-byte random IVs, 16-byte authentication tags).
* **Key Derivation**: PBKDF2 with HMAC-SHA256, 100,000 iterations, 128-bit cryptographic salt.
* **On-Device Key Storage**: Android Keystore (backed by StrongBox / TEE) and iOS Keychain (backed by Secure Enclave).
* **Network Security**: TLS 1.3 only, strict RLS database authorization, zero plaintext storage in public schemas.
* **Auditability**: All entry edits and emergency sync operations create immutable log records.

---

*Made with love, common sense, and zero trust in plain paper notebooks.*
