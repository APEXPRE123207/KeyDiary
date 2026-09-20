# KeyDiary Security & Cryptographic Architecture

## 1. Overview & Security Philosophy
KeyDiary is a private, multi-generational family information vault built on a **Zero-Knowledge Architecture**. The application treats backend database providers (such as Supabase PostgreSQL and Storage) as untrusted transport and storage channels. Sensitive user records are encrypted client-side on the device before transmission.

---

## 2. Threat Model

### Threat 1: Device Physical Theft
- **Scenario**: An adversary steals the physical mobile device.
- **Mitigations**:
  - Device-level OS security (Android PIN/Biometrics, iOS passcode/Face ID).
  - App Master PIN derived with **PBKDF2-HMAC-SHA256** (100,000 iterations, random salt).
  - Progressive rate-limiting delays after 3 failed attempts (10s, 30s, 60s).
  - Biometric protection on sensitive categories (e.g., Investments, Bank details).
  - Configurable auto-lock on backgrounding (Immediately, 30s, 1m, 5m, 15m; default: 1 minute).
  - Decrypted Vault Encryption Keys (VEK) are held strictly in transient device RAM and wiped upon lock.
  - Screen privacy flags (`FLAG_SECURE`) prevent sensitive screen capture in app switchers.

### Threat 2: Supabase Database Compromise
- **Scenario**: An attacker obtains unauthorized access to Supabase PostgreSQL or storage buckets.
- **Mitigations**:
  - **Zero Plaintext Secrets**: `title_encrypted`, `notes_encrypted`, `field_name_encrypted`, and `field_value_encrypted` contain only AES-256-GCM ciphertexts.
  - The database has no mathematical means to decrypt account numbers, PINs, or safe spot notes.
  - Strict Row Level Security (RLS) policies enforce vault isolation at the SQL query planner level.

### Threat 3: APK / Source Decompilation
- **Scenario**: An adversary decompiles the client application package.
- **Mitigations**:
  - Zero hard-coded encryption keys, passwords, or service-role keys in Dart code or application assets.
  - Keys are dynamically generated using platform CSPRNGs (`cryptography` package).
  - Keys are persisted exclusively in hardware-backed storage (Android Keystore / iOS Keychain).

### Threat 4: Unauthorized Multi-Tenant Cross-Access
- **Scenario**: User B attempts to access User A's private vault by guessing or knowing its UUID.
- **Mitigations**:
  - PostgreSQL Row Level Security checks membership against `vault_members` for every `SELECT`, `INSERT`, `UPDATE`, and `DELETE`.
  - Without a matching `vault_members` record for `auth.uid()`, access is rejected with `ACCESS DENIED`.

---

## 3. Cryptographic Primitives

### Symmetric Cipher: AES-256-GCM
- **Algorithm**: Authenticated Encryption with Associated Data (AEAD) via AES-GCM 256-bit.
- **Nonce/IV**: 96-bit (12 bytes) cryptographically secure random nonces generated per encryption operation. Nonces are never reused.
- **Authentication Tag**: 128-bit (16 bytes) MAC verification tag ensuring ciphertext integrity. Any tampering causes decryption rejection.
- **Packed Wire Format**:
  `Base64( [1 byte version: 0x01] + [12 bytes nonce] + [16 bytes tag] + [ciphertext] )`

### Key Derivation: PBKDF2-HMAC-SHA256
- **Iterations**: 100,000.
- **Salt**: 16 bytes secure random salt generated per user PIN.
- **Output**: 256-bit key verifier.

### Vault Encryption Key (VEK) Lifecycle & Wrapping
1. **Creation**: When a vault is created, a 256-bit random VEK is generated on-device.
2. **Key Wrapping**: The VEK is wrapped (encrypted) individually for each authorized member using their member key and saved in `vault_members.encrypted_vault_key`.
3. **Sharing**: When inviting a second family member (co-guardian), the member securely unwraps the VEK on acceptance.

---

## 4. Emergency Family Recovery Store
In accordance with user specifications, KeyDiary provides an isolated emergency recovery schema:
- **Schema**: `emergency_vault`
- **Tables**: `emergency_vault.entries`, `emergency_vault.entry_fields`
- **Purpose**: Facilitates controlled data recovery for designated heirs/co-guardians in certified emergency circumstances.
- **Access Control**: Governed by independent RLS policies restricted to authorized vault members.
- **Audit Logging**: Every emergency sync action is cryptographically logged in `audit_logs`.

---

## 5. Non-Sensitive Audit Trail
KeyDiary enforces a strict no-plaintext policy in logs:
- Permitted: Actions (`ENTRY_CREATED`, `ENTRY_UPDATED`), Entity Types (`ENTRY`, `CATEGORY`), Timestamps, User roles.
- Prohibited: Account numbers, monetary values, card numbers, passcodes, and plaintext titles.
