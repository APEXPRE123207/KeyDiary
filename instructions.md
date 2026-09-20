# KEYDIARY — FULL VIBE-CODING BUILD SPECIFICATION

## 1. PROJECT OVERVIEW

Build a production-quality mobile application called **KeyDiary**.

KeyDiary is a **private, encrypted family information vault** designed for two trusted users: a father and his child.

The app replaces a physical diary that currently contains sensitive information such as:

* Investments
* Bank/account information
* Keys and where they are stored
* Insurance information
* Property information
* Cards
* Important financial information
* Documents
* Custom personal records
* Other sensitive information

The application must be designed around **privacy, security, simplicity, and ease of use**, particularly for a non-technical older user.

This is NOT a generic notes app.

It should feel like a combination of:

* A secure vault
* A structured personal diary
* A lightweight password manager
* A family information repository

The two authorized users should be able to securely access the same private vault from their own devices.

---

# 2. PRIMARY TECHNOLOGY STACK

Use:

### Frontend

* Flutter
* Dart
* Material 3
* Responsive mobile-first UI
* Android and iOS compatible architecture

### Backend

* Supabase
* Supabase Authentication
* PostgreSQL
* Row Level Security
* Supabase Storage
* Realtime where useful

### Local security

Use platform secure storage:

* Android Keystore
* iOS Keychain / Secure Enclave where applicable

Use Flutter-compatible packages for:

* Biometric authentication
* Secure local storage
* Cryptographic operations
* UUID generation
* File handling
* Image/PDF handling

Do NOT invent cryptography.

Use established, audited cryptographic primitives and well-maintained packages.

---

# 3. IMPORTANT SECURITY REQUIREMENT

Security is one of the most important requirements of this project.

Do NOT treat Supabase database encryption at rest as equivalent to application-level encryption.

Sensitive user data should preferably be encrypted **on the client before being uploaded to Supabase**.

Conceptually:

USER INPUT
↓
Flutter application
↓
Client-side encryption
↓
Ciphertext
↓
Supabase
↓
PostgreSQL / Storage

Supabase should not need to know the plaintext values of highly sensitive fields.

For example:

User enters:

Bank: SBI
Account Number: 123456789
Amount: ₹500000

The database should preferably contain encrypted values rather than:

123456789

The application decrypts the data only after the authorized user has authenticated and unlocked the vault.

---

# 4. AUTHENTICATION ARCHITECTURE

Implement proper user authentication using Supabase Auth.

Each person should have their own account.

Do NOT have both people share one username/password.

Example:

Vault
├── Father
└── Child

Each user:

* Has their own Supabase Auth account
* Has their own authentication credentials
* Is associated with the shared KeyDiary vault
* Has a role

Possible roles:

OWNER
MEMBER

Initially:

Father:

* OWNER

Child:

* MEMBER

The architecture should allow additional roles/permissions in the future.

---

# 5. APP SECURITY LAYERS

The app should use multiple layers of security.

Recommended flow:

OPEN APP
↓
Check authentication
↓
Check local app lock
↓
PIN / biometric authentication
↓
Unlock encryption key
↓
Open vault

The app must support:

### PIN

A user can configure an application PIN.

The PIN must NOT be stored as plaintext.

Never store:

"1234"

Instead store a secure password-derived/verifier representation.

Use an appropriate password hashing/KDF mechanism.

Do not implement custom hashing.

---

# 6. BIOMETRIC AUTHENTICATION

Support:

* Fingerprint
* Face authentication where supported
* Other OS-supported biometrics

Biometric authentication should be used for:

### App unlock

Opening KeyDiary.

### Sensitive category unlock

Certain categories can require biometric authentication every time they are opened.

For example:

Keys
Investments
Cards

The user should be able to configure whether a category requires additional authentication.

Example:

Home
↓
Investments
↓
Biometric prompt
↓
Investment data

Do NOT implement your own fingerprint recognition.

Use the device operating system's biometric authentication APIs.

---

# 7. ENCRYPTION KEY ARCHITECTURE

Do not derive the entire encryption system from the PIN alone.

Design the system around a randomly generated vault encryption key.

Conceptually:

Vault Encryption Key
↓
Encrypt sensitive data

The key itself should be protected using the device's secure storage.

For example:

Android:
Android Keystore

iOS:
Keychain / Secure Enclave where applicable

The exact implementation should use established cryptographic libraries.

Prefer authenticated encryption such as:

AES-256-GCM

or another modern authenticated encryption construction supported by a reputable library.

Every encrypted object should have the information required for decryption, such as:

* Version
* Algorithm identifier
* IV/nonce
* Ciphertext
* Authentication tag where applicable

Never reuse nonces incorrectly.

Never invent cryptographic algorithms.

---

# 8. SHARED VAULT PROBLEM

There are two separate concerns:

1. Authentication
2. Encryption

Supabase authentication determines:

"Is this person allowed to access the vault?"

Encryption determines:

"Can this person decrypt the contents?"

Design the system carefully so that the shared vault can be accessed by both authorized users.

Do not simply hard-code an encryption key into the Flutter application.

Do not put secrets in:

* Dart source code
* .env committed to Git
* GitHub
* Supabase frontend configuration
* APK assets

Supabase's public anon key can be used according to Supabase's normal architecture, but service-role keys and other privileged secrets must NEVER be included in the mobile app.

---

# 9. KEY RECOVERY / MULTI-DEVICE DESIGN

The architecture must account for the fact that a user may:

* Buy a new phone
* Delete the app
* Lose their phone
* Reinstall the application

Do not silently make the vault unrecoverable.

Design a secure recovery mechanism.

For the MVP, implement a clearly documented recovery strategy.

Potential architecture:

Each vault has a vault key.

The vault key is encrypted/wrapped separately for each authorized user/device.

Example:

Vault Encryption Key
├── encrypted for Father
└── encrypted for Child

When a new device is authorized, the appropriate recovery/authentication mechanism can provision the vault key.

Do not implement an unsafe "send encryption key through email" mechanism.

If full multi-device end-to-end key management is too complex for the first implementation, build the architecture so it can be added later rather than creating an insecure shortcut.

---

# 10. DATABASE ARCHITECTURE

Use PostgreSQL through Supabase.

Recommended schema:

## profiles

id
user_id
display_name
avatar_url
created_at
updated_at

---

## vaults

id
name
created_by
created_at
updated_at

Example:

KeyDiary Family Vault

---

## vault_members

id
vault_id
user_id
role
created_at

Roles:

OWNER
MEMBER

Add unique constraint:

(vault_id, user_id)

---

## categories

id
vault_id
name
description
icon
color
position
is_locked
created_by
created_at
updated_at

Examples:

Investments
Keys
Insurance
Cards
Property
Documents

---

## entries

id
category_id
title_encrypted
notes_encrypted
created_by
created_at
updated_at

The title may also be encrypted if it is sensitive.

---

## entry_fields

id
entry_id
field_name_encrypted
field_type
field_value_encrypted
position
is_sensitive
created_at
updated_at

Field types:

TEXT
LONG_TEXT
NUMBER
CURRENCY
DATE
PHONE
EMAIL
URL
SECRET
BOOLEAN
IMAGE
DOCUMENT
LOCATION_DESCRIPTION

Do not make the database schema depend on specific categories.

The entire point is to allow users to define their own fields.

---

## attachments

id
entry_id
storage_path
file_name_encrypted
mime_type
size
created_at

Sensitive attachment metadata should be considered carefully.

---

## audit_logs

id
vault_id
user_id
action
entity_type
entity_id
created_at

Do not log sensitive plaintext values.

Example:

GOOD:

"User opened entry 7d8..."

BAD:

"User viewed SBI account number 123456789"

Audit logs should never accidentally become another source of sensitive data.

---

# 11. ROW LEVEL SECURITY

Supabase Row Level Security is mandatory.

Users must only be able to access vaults for which they are authorized members.

Example conceptual rule:

User A belongs to Vault X.

User A can:

SELECT Vault X

User A cannot:

SELECT Vault Y

RLS should be implemented for:

* vaults
* vault_members
* categories
* entries
* entry_fields
* attachments
* audit_logs

Never rely exclusively on Flutter-side checks.

The frontend can hide things.

RLS must enforce security at the database level.

---

# 12. STORAGE SECURITY

Use Supabase Storage for:

* Images
* PDFs
* Other documents

Do not create a publicly accessible bucket for sensitive files.

Storage must be private.

Use authenticated access / signed URLs as appropriate.

Sensitive documents should preferably be encrypted before upload if the security architecture supports it.

Do not expose permanent public URLs for private documents.

---

# 13. HOME SCREEN

The home screen is the central screen of KeyDiary.

Design:

---

## KeyDiary                              🔔  ⚙

Good evening, Dad

Your Vault

┌────────────────┐ ┌────────────────┐
│                │ │                │
│  Investments   │ │     Keys       │
│      💰        │ │      🔑        │
│  8 records     │ │   14 records   │
│                │ │                │
└────────────────┘ └────────────────┘

┌────────────────┐ ┌────────────────┐
│                │ │                │
│   Insurance    │ │     Cards      │
│      🛡        │ │      💳        │
│   5 records    │ │    4 records   │
│                │ │                │
└────────────────┘ └────────────────┘

```
             + Add
```

---

The categories should appear as attractive cards.

Avoid an overly complicated dashboard.

---

# 14. CATEGORY SYSTEM

Categories are fully customizable.

Default categories:

1. Investments
2. Bank Accounts
3. Keys
4. Cards
5. Insurance
6. Property
7. Documents
8. Loans
9. Emergency
10. Other

Users can:

* Create category
* Rename category
* Delete category
* Reorder categories
* Change icon
* Change visual appearance
* Enable/disable biometric protection

Do not hard-code the category list into the application.

Categories should come from Supabase.

---

# 15. ADD CATEGORY

When the user taps:

* Add Category

Show:

Category Name

[________________]

Icon

[ 🔑 ] [ 💰 ] [ 🏠 ] [ 📄 ] [ 🛡 ] [ 💳 ]

Security

[ ] Require biometric authentication

Save

The icon system should be extendable.

---

# 16. CATEGORY SCREEN

When opening a category:

---

## ← Investments                         🔒

Search

[ Search investments... ]

* Add Entry

---

SBI Fixed Deposit
₹5,00,000
Maturity: 12 Apr 2028

---

LIC Policy
Policy No: XXXXX
Premium: ₹25,000/year

---

Entries should use cards.

Sensitive values should optionally be masked.

Example:

Account Number
••••••••••1234

Tap to reveal.

---

# 17. BIOMETRIC CATEGORY LOCK

If a category has:

is_locked = true

Opening it should trigger biometric authentication.

Example:

---

```
         🔒 Investments
```

---

```
  Authenticate to continue

        [Fingerprint]

  Use PIN instead
```

---

Never display the category contents before successful authentication.

---

# 18. ENTRY CREATION

The entry creation UI must be flexible.

Example:

Add Investment

Title:

[ SBI Fixed Deposit ]

Fields:

Bank
[ SBI ]

Amount
[ ₹5,00,000 ]

Maturity Date
[ 12 Apr 2028 ]

Nominee
[ Soumyadip ]

Notes
[ Original document is in locker ]

* Add Field

SAVE

---

# 19. CUSTOM FIELD CREATION

When the user selects:

* Add Field

Show:

Field Name

[________________]

Field Type

[ Text ▼ ]

Possible types:

Text
Number
Currency
Date
Phone
Email
URL
Secret
Long Text
Boolean

Then:

SAVE FIELD

Example:

Field Name:
Branch Manager

Field Type:
Text

This field should then appear in the entry.

---

# 20. FIELD DISPLAY

Different field types should have appropriate UI.

TEXT:

Bank
SBI

CURRENCY:

Amount
₹5,00,000

DATE:

Maturity
12 April 2028

PHONE:

Contact
+91 XXXXX XXXXX

SECRET:

Card Number
•••• •••• •••• 1234

[Reveal]

URL:

Website
[Open]

BOOLEAN:

Nominee Verified
✓

---

# 21. SECRET FIELD

Secret fields should:

* Default to masked
* Have reveal/hide button
* Never appear in logs
* Never appear in analytics
* Never appear in crash reports
* Never be copied to clipboard without explicit user action

If copied to clipboard:

Show a warning or automatically clear the clipboard after a short configurable period where practical.

---

# 22. ENTRY EDITING

Every entry should support:

Edit
Delete
Duplicate
Share/export (if later enabled)
Add field
Remove field
Reorder fields

Deleting should require confirmation.

For highly sensitive entries, optionally require biometric authentication before deletion.

---

# 23. SEARCH

Implement local/search functionality.

Search should allow:

* Category search
* Entry title search
* Field search where appropriate

However, remember:

Encrypted data cannot simply be searched server-side in plaintext.

For the initial architecture, once the vault is unlocked, decrypt the necessary records locally and perform local search.

Do not send plaintext search queries to Supabase.

---

# 24. HOME SEARCH

Provide a global search button.

Example:

---

## Search KeyDiary

[ 🔍 Search everything... ]

Results:

Investments
→ SBI Fixed Deposit

Keys
→ Main Gate Key

Insurance
→ LIC Policy

Search results must respect the same access controls and locked-category rules.

Do not reveal the existence of sensitive locked information unnecessarily.

---

# 25. DOCUMENT SUPPORT

Entries should optionally support attachments.

Supported initially:

* Images
* PDF

Example:

LIC Policy

Fields:
Policy Number
Premium
Maturity Date

Attachments:

📄 LIC_Policy.pdf
🖼 Receipt.jpg

Attachments must be private.

Allow:

View
Download/open
Delete

Do not make files public.

---

# 26. CAMERA / IMAGE SUPPORT

Allow users to capture an image directly.

Examples:

* Photograph of a receipt
* Photograph of an important document
* Photograph of a key location
* Photograph of a certificate

Before upload:

Optionally compress large images.

Never compromise readability of documents unnecessarily.

---

# 27. DASHBOARD STATISTICS

Keep dashboard statistics minimal.

Useful:

Number of categories
Number of entries

Avoid unnecessary financial analytics.

KeyDiary is an information vault, not a financial portfolio management system.

Do NOT attempt to calculate investment returns unless explicitly added later.

---

# 28. SETTINGS

Settings screen:

Profile
Security
Vault
Appearance
Notifications
Backup & Recovery
About

---

# 29. SECURITY SETTINGS

Security:

App PIN
Change PIN
Biometric Authentication
Auto-lock duration
Locked Categories
Clipboard protection
Session management

Auto-lock options:

Immediately
30 seconds
1 minute
5 minutes
15 minutes
Never

Default:

1 minute

When the application goes to background for longer than the configured period:

LOCK APP

Sensitive information must not remain visible.

---

# 30. APP BACKGROUND SECURITY

When the app is backgrounded:

Do not allow sensitive screen contents to appear in the app switcher preview where platform APIs permit preventing screenshots/previews.

Use:

FLAG_SECURE

or the appropriate platform equivalent on Android.

Use iOS privacy mechanisms where appropriate.

---

# 31. AUTO LOCK

Example:

User opens KeyDiary.

Leaves application.

Returns after 2 minutes.

If timeout is 1 minute:

PIN/Biometric screen appears.

The decrypted vault key should not remain unnecessarily accessible indefinitely.

---

# 32. OFFLINE SUPPORT

The app should preferably support limited offline functionality after the vault has previously been unlocked.

However, offline storage must remain encrypted.

Never store plaintext vault data casually in:

* SharedPreferences
* SQLite plaintext
* Hive plaintext
* JSON files
* cache files

If local caching is implemented:

Encrypt it.

---

# 33. NETWORK SECURITY

Use HTTPS/TLS.

Do not disable certificate validation.

Do not accept arbitrary certificates.

Do not log request bodies containing sensitive data.

---

# 34. ERROR HANDLING

Never display technical errors to the user.

Bad:

"PostgrestException: JWT expired..."

Better:

"Your session has expired. Please sign in again."

For security-related failures:

"Unable to unlock the vault."

Do not expose cryptographic implementation details.

---

# 35. LOGGING

Development logs can exist during development but must never contain:

* PIN
* Password
* Encryption keys
* Card numbers
* Account numbers
* Secret field values
* Document contents
* Access tokens

Before release:

Disable verbose debugging.

---

# 36. SUPABASE AUTH

Use Supabase Auth.

Possible initial login:

Email + password

Optionally add magic link later.

After successful authentication:

Create/retrieve user's vault membership.

Do not automatically grant vault access just because someone is authenticated.

Authentication:

"Who are you?"

Authorization:

"Which vault are you allowed to access?"

Both must be enforced.

---

# 37. FAMILY VAULT INVITATION

Implement a secure mechanism for the owner to invite the second user.

Possible UX:

Father:

Settings
→ Vault
→ Add Family Member
→ Invite

Enter email:

[________________]

Send invitation.

The second user accepts the invitation and becomes a vault member.

Do not allow arbitrary users to join a vault by knowing its ID.

---

# 38. PERMISSIONS

Initial permissions:

OWNER:

* Create categories
* Edit categories
* Delete categories
* Create entries
* Edit entries
* Delete entries
* Manage members

MEMBER:

* View entries
* Create entries
* Edit entries
* Delete own entries

Design this so permissions can later be customized.

---

# 39. AUDIT TRAIL

Create a lightweight audit system.

Record events such as:

User logged in
User added entry
User edited entry
User deleted entry
User added category
User invited member
User changed security settings

Never record the actual sensitive values.

Settings should allow the owner to view recent activity.

Example:

Recent Activity

Today

You added "SBI Fixed Deposit"
Dad edited "LIC Policy"

Yesterday

You added "Main Door Key"

---

# 40. UI DESIGN LANGUAGE

The app should feel:

* Premium
* Calm
* Secure
* Trustworthy
* Minimal
* Mature

Avoid:

* Excessive gradients
* Neon colors
* Gamification
* Excessive animations
* Clutter
* Tiny text
* Too many icons

Use Material 3 but customize it enough that it does not look like a default Flutter demo.

---

# 41. ACCESSIBILITY

Because the primary user may be older:

Use:

* Large readable typography
* High contrast
* Large touch targets
* Clear labels
* Minimal hidden gestures
* Simple navigation
* Confirmation for destructive actions

Minimum comfortable touch target:

~48dp.

Important information should not rely solely on color.

---

# 42. THEME

Support:

Light mode
Dark mode
System default

Default:

System default.

Use a sophisticated neutral palette.

The UI should communicate security without looking like a "hacker" application.

---

# 43. NAVIGATION

Recommended bottom navigation:

Home
Search
Activity
Settings

However, if this creates unnecessary complexity, use:

Home
Search
Settings

Activity can be accessible from Settings.

Keep navigation simple.

---

# 44. EMPTY STATES

For a category with no entries:

---

```
        🔐

   No information yet
```

Add your first record to this category.

```
      + Add Entry
```

---

Do not show technical database messages.

---

# 45. LOADING STATES

Use skeleton loaders where appropriate.

Avoid full-screen loading spinners for small operations.

For authentication:

Unlocking vault...

For sync:

Syncing...

---

# 46. OFFLINE / SYNC STATUS

Show a subtle status indicator:

✓ Synced

or

↻ Syncing...

or

⚠ Offline

Do not display alarming messages for temporary connectivity problems.

---

# 47. DATA SYNCHRONIZATION

Supabase should be the source of truth for synchronized vault data.

When changes are made:

Flutter
→ encrypt
→ upload
→ database

When another device changes something:

database
→ download
→ decrypt locally
→ update UI

Use realtime subscriptions only where they provide clear value.

Avoid unnecessary realtime complexity initially.

---

# 48. CONFLICT HANDLING

If two devices edit the same entry simultaneously:

Do not silently overwrite important information.

At minimum implement:

updated_at

and detect stale edits.

Possible MVP behavior:

" This entry was modified on another device. Reload before saving your changes."

A more sophisticated conflict-resolution system can be implemented later.

---

# 49. DELETE BEHAVIOR

Deletion should be deliberate.

For normal entries:

Confirmation:

Delete "SBI Fixed Deposit"?

Cancel
Delete

For categories:

Deleting a category containing entries should require explicit confirmation.

Example:

"This category contains 8 entries. Delete category and all entries?"

Do not accidentally cascade-delete sensitive information without confirmation.

---

# 50. DATA EXPORT

Do NOT implement insecure plaintext export by default.

If export is implemented later:

Require authentication.

Possible export:

Encrypted KeyDiary Backup

The backup should itself be encrypted and protected by a user-provided password/passphrase or another secure mechanism.

Do not generate an unencrypted JSON file containing all secrets unless the user explicitly chooses a clearly warned plaintext export.

---

# 51. BACKUP

The user should have a clear understanding of:

* What is stored locally
* What is stored in Supabase
* What is encrypted
* What happens if the phone is lost
* How account recovery works

Create a simple Backup & Recovery screen.

Example:

Vault status

✓ Cloud backup enabled

Last synced:
Today, 9:42 PM

Recovery:
Configured

---

# 52. SECURITY ON LOST DEVICE

If the phone is lost:

The user should be able to revoke the device/session.

Settings:

Security
→ Active Sessions

Father's Phone
Current device

Child's Phone
Last active 2 hours ago

[Revoke]

Revoking a session should prevent that device from accessing the backend after authentication/session invalidation.

---

# 53. DATABASE MIGRATIONS

Create proper Supabase SQL migrations.

Do not manually create database tables through random dashboard clicks and leave the project undocumented.

Store migrations in:

supabase/migrations/

Example:

001_initial_schema.sql
002_rls_policies.sql
003_storage.sql

---

# 54. PROJECT STRUCTURE

Use clean architecture.

Suggested Flutter structure:

lib/

```
main.dart

app/
    app.dart
    router.dart
    theme.dart

core/
    constants/
    errors/
    security/
    storage/
    network/
    utils/
    widgets/

features/

    auth/
        data/
        domain/
        presentation/

    vault/
        data/
        domain/
        presentation/

    categories/
        data/
        domain/
        presentation/

    entries/
        data/
        domain/
        presentation/

    search/
        data/
        domain/
        presentation/

    settings/
        data/
        domain/
        presentation/

    audit/
        data/
        domain/
        presentation/

models/
```

Use clear separation between:

Presentation
Domain
Data

Do not put Supabase calls directly inside UI widgets.

---

# 55. STATE MANAGEMENT

Choose one state management architecture and use it consistently.

Recommended:

Riverpod

or another mature Flutter state-management solution.

Do NOT mix multiple state-management approaches unnecessarily.

---

# 56. DEPENDENCIES

Prefer mature, actively maintained packages.

Potential categories:

supabase_flutter
local_auth
flutter_secure_storage
cryptography
uuid
go_router
riverpod
image_picker
file_picker
intl

Before selecting exact packages, verify compatibility with the current Flutter stable release.

Do not blindly use outdated package APIs.

---

# 57. ENVIRONMENT VARIABLES

Use environment configuration.

Example:

SUPABASE_URL
SUPABASE_ANON_KEY

Never include:

SUPABASE_SERVICE_ROLE_KEY

in the mobile application.

Provide:

.env.example

but do not commit real credentials.

Add sensitive environment files to:

.gitignore

---

# 58. GITIGNORE

At minimum:

.env
.env.*
!.env.example

.dart_tool/
build/
.idea/
.vscode/

Never commit:

* Supabase service keys
* passwords
* private certificates
* encryption keys
* test production credentials

---

# 59. TESTING

Implement automated tests.

### Unit tests

Test:

* Encryption/decryption
* Field serialization
* Validation
* Category operations
* Entry operations
* PIN validation
* Search
* Permission logic

Example:

plaintext
→ encrypt
→ decrypt
→ original plaintext

must match.

### Widget tests

Test:

* Login
* Home
* Category
* Add entry
* Edit entry
* Settings

### Integration tests

Test:

Register
→ login
→ create vault
→ create category
→ create entry
→ logout
→ login
→ retrieve entry

Also test:

User A cannot access User B's vault.

---

# 60. SECURITY TESTING

Explicitly test:

* Unauthorized database access
* RLS violations
* Expired sessions
* Invalid vault membership
* Deleted users
* Revoked sessions
* Locked categories
* PIN failures
* Biometric failures
* Offline cache exposure
* Screenshot exposure
* Logging of secrets

Do not consider the application secure merely because authentication works.

---

# 61. PIN BRUTE-FORCE PROTECTION

Implement protection against repeated PIN attempts.

Possible behavior:

After several incorrect attempts:

Temporary delay.

Example:

Attempt 1 → immediate
Attempt 2 → immediate
Attempt 3 → delay
Attempt 4 → longer delay

Do not implement a simple unlimited PIN loop.

Consider clearing locally cached encryption material after repeated failed authentication depending on the security architecture.

Do not lock the user out permanently without a recovery mechanism.

---

# 62. SESSION EXPIRATION

Handle expired Supabase sessions gracefully.

If backend authentication expires:

Return to login.

Do not crash.

Do not display raw JWT errors.

---

# 63. SECURITY QUESTIONS

Do NOT use traditional security questions such as:

"What's your mother's maiden name?"

They are weak.

Use secure authentication/recovery mechanisms instead.

---

# 64. FIRST-RUN EXPERIENCE

On first launch:

---

```
             KeyDiary

    Your private family vault.

         [ Get Started ]
```

---

Then:

Create account
or
Sign in

After authentication:

Create Vault

Vault name:
[ Family Vault ]

Then:

Enable biometric authentication?

[ Enable ]

Then:

Create App PIN

Enter PIN
Confirm PIN

Then:

Home

---

# 65. SECOND USER ONBOARDING

When Father invites the child:

Child receives invitation.

After accepting:

Sign in/create account.

The application detects:

"You've been invited to Family Vault."

Accept

Then:

Vault appears on home screen.

---

# 66. DEFAULT CATEGORIES

On vault creation, offer:

Create default categories?

✓ Investments
✓ Bank Accounts
✓ Keys
✓ Insurance
✓ Cards
✓ Property
✓ Documents
✓ Loans

[Continue]

Allow users to modify them afterward.

---

# 67. CATEGORY ICONS

Use a controlled icon set.

Examples:

Investments → trending_up
Bank → account_balance
Keys → key
Insurance → shield
Cards → credit_card
Property → home
Documents → description
Loans → payments
Emergency → emergency
Other → folder

Do not rely on arbitrary remote image URLs for icons.

---

# 68. SENSITIVE DATA WARNING

When adding certain fields such as:

Card Number
Account Number
Password
Secret
PIN

show a subtle warning:

"This information will be stored in your encrypted KeyDiary vault."

Do not make the warning annoying.

---

# 69. CARD NUMBER HANDLING

Do not automatically classify arbitrary numeric values as payment-card numbers.

If a user explicitly creates a Card Number field:

* Store encrypted
* Display masked
* Provide reveal action
* Avoid logging
* Avoid analytics
* Avoid indexing plaintext

Potential display:

•••• •••• •••• 1234

---

# 70. FINANCIAL DATA

Do not connect to banks in the MVP.

KeyDiary is a storage system, not an aggregator.

Do not request unnecessary financial permissions.

No:

* Bank API
* UPI API
* Investment brokerage API

unless explicitly added as a future feature.

---

# 71. NOTIFICATIONS

Keep notifications minimal.

Possible notifications:

"Your KeyDiary vault was accessed from a new device."

"Someone accepted your vault invitation."

"Your session was revoked."

Do NOT include sensitive information in push notification text.

Bad:

"SBI account ₹5,00,000 was edited."

Good:

"An entry in KeyDiary was updated."

---

# 72. APP LOCK NOTIFICATION CONTENT

On lock screen, never expose sensitive data.

Avoid:

"Soumyadip edited SBI Fixed Deposit"

Prefer:

"KeyDiary activity"

---

# 73. DESIGN DETAILS

Use rounded cards.

Moderate corner radius.

Clear hierarchy.

Example typography:

App title:
Large / bold

Category:
Medium / semibold

Metadata:
Small / muted

Secret values:
Monospaced font may be used when appropriate.

Maintain excellent spacing.

Avoid overcrowding.

---

# 74. ANIMATION

Use subtle animation:

* Page transitions
* Card appearance
* Expand/collapse
* Success feedback

Do NOT use unnecessary animations on every interaction.

Security-related screens should feel stable and trustworthy.

---

# 75. ICON + BRAND

Create a simple KeyDiary identity.

Possible visual concept:

Key + diary/book combination.

Do not make it look like a literal house key management application.

The icon should communicate:

"Important information protected securely."

---

# 76. APP NAME

Application name:

KeyDiary

Use exactly:

KeyDiary

Not:

Key Diary
Key-Diary
KeyDiary Vault

The internal package identifier can be:

com.<developer>.keydiary

Use an appropriate placeholder until the developer chooses the final package ID.

---

# 77. PERFORMANCE

The application should remain fast with:

* 10 categories
* 1,000+ entries
* Many custom fields
* Large document attachments

Do not decrypt an unnecessarily large amount of data at once.

Load records lazily where practical.

Do not block the UI thread with expensive cryptographic or file operations.

---

# 78. DATA VALIDATION

Implement proper validation.

Examples:

Required field:

Category name cannot be empty.

Email:

Validate format.

Phone:

Allow international formats.

Currency:

Prevent invalid numeric values.

Date:

Use native date picker.

Do not make validation unnecessarily restrictive.

---

# 79. ENTRY TEMPLATE SYSTEM

Potential future feature:

Category templates.

For example:

Investment template:

Institution
Investment Type
Amount
Start Date
Maturity Date
Nominee
Notes

Key template:

Key Name
Location
Purpose
Backup Key
Notes

Insurance template:

Provider
Policy Number
Type
Premium
Due Date
Nominee
Maturity

Do not hard-code this into the initial database architecture.

Build custom fields so templates can be introduced later.

---

# 80. IMPORTANT UX PRINCIPLE

The application should never force users to understand:

* JSON
* Databases
* Encryption
* Supabase
* schemas
* APIs

All complexity stays behind the interface.

The user should think:

"Add information."

Not:

"Create database record."

---

# 81. DEVELOPMENT PHASES

Build the application in phases.

## PHASE 1 — Foundation

Create:

* Flutter project
* Theme
* Routing
* Supabase configuration
* Authentication
* Basic project architecture

---

## PHASE 2 — Vault

Implement:

* Vault creation
* Vault membership
* RLS
* Categories
* Home screen

---

## PHASE 3 — Entries

Implement:

* Entry creation
* Custom fields
* Entry viewing
* Editing
* Deleting

---

## PHASE 4 — Security

Implement:

* App PIN
* Biometrics
* Secure storage
* Encryption
* Auto-lock
* Sensitive-field masking

Do NOT postpone security until after production data is already stored.

---

## PHASE 5 — Documents

Implement:

* Image upload
* PDF upload
* Private storage
* Document viewer

---

## PHASE 6 — Family Sharing

Implement:

* Invitations
* Membership
* Permissions
* Multi-user access

---

## PHASE 7 — Search & Activity

Implement:

* Local search
* Activity log
* Sync state

---

## PHASE 8 — Testing

Implement:

* Unit tests
* Widget tests
* Integration tests
* Security/RLS tests

---

# 82. SUPABASE SETUP

Generate SQL migrations for:

* Tables
* Indexes
* Foreign keys
* Constraints
* RLS
* RLS policies
* Storage policies

Document how to run them.

Provide:

supabase/

```
migrations/

seed.sql
```

Do not require manually editing SQL to run the application.

---

# 83. README

Create a complete README containing:

Project overview
Architecture
Tech stack
Flutter setup
Supabase setup
Environment variables
Database migrations
Running locally
Testing
Building Android
Security architecture
Encryption architecture
Recovery architecture
Known limitations
Future improvements

---

# 84. SECURITY DOCUMENTATION

Create:

docs/SECURITY.md

Document:

* Authentication
* Authorization
* RLS
* Encryption
* Key management
* Secure storage
* Biometric authentication
* Session management
* Local storage
* Logging policy
* Backup/recovery
* Threat model
* Known limitations

Do not claim "military-grade" or "100% secure".

Use precise technical language.

---

# 85. THREAT MODEL

Consider at minimum:

### Threat 1

Someone steals the phone.

Mitigation:

* OS device security
* App PIN
* Biometrics
* Auto-lock
* Secure storage
* Encrypted local cache

### Threat 2

Someone gets Supabase database access.

Mitigation:

* RLS
* Client-side encryption
* No plaintext sensitive values

### Threat 3

Someone obtains application source/APK.

Mitigation:

* No embedded secrets
* No service-role keys
* Encryption keys not hard-coded

### Threat 4

Unauthorized user attempts database access.

Mitigation:

* Supabase Auth
* RLS
* Vault membership checks

### Threat 5

Phone is replaced.

Mitigation:

* Recovery architecture

---

# 86. DO NOT DO THESE THINGS

Never:

1. Hard-code passwords.
2. Hard-code encryption keys.
3. Store PIN in plaintext.
4. Store service-role Supabase keys in the app.
5. Create public storage buckets for private documents.
6. Log sensitive values.
7. Put secrets in analytics.
8. Send plaintext secrets to a server unnecessarily.
9. Implement custom cryptographic algorithms.
10. Pretend hashing is encryption.
11. Rely only on frontend authorization.
12. Store plaintext sensitive information in SharedPreferences.
13. Automatically expose sensitive information in notifications.
14. Put account/card numbers in crash logs.
15. Make the app look like a generic CRUD demo.

---

# 87. CODE QUALITY

Write production-quality code.

Avoid:

* giant widgets
* duplicated logic
* magic strings
* hard-coded database IDs
* business logic inside UI
* unnecessary global variables
* unsafe null handling
* abandoned dependencies

Use:

* Strong typing
* Models
* Repositories
* Services
* Providers/controllers
* Dependency injection where useful
* Constants
* Error handling

---

# 88. COMMENTS

Do not comment obvious code.

Instead, document non-obvious security decisions.

Example:

GOOD:

// Vault keys are stored using platform secure storage rather than
// SharedPreferences because SharedPreferences is not designed for
// protecting cryptographic material.

BAD:

// Save key
saveKey();

---

# 89. FINAL USER EXPERIENCE

The finished application should feel like:

Open KeyDiary

↓
Biometric authentication

↓

Beautiful home dashboard

↓

Tap:

Investments

↓

Biometric authentication

↓

See:

SBI Fixed Deposit
LIC Policy
Mutual Fund

↓

Tap SBI Fixed Deposit

↓

See:

Bank
SBI

Amount
₹5,00,000

Maturity
12 April 2028

Nominee
Soumyadip

Notes
Original receipt in locker.

Everything is simple.

Everything sensitive is protected.

---

# 90. BUILD REQUIREMENT

Do not stop at generating architecture or pseudo-code.

Actually implement the application.

Create:

* Flutter source code
* Supabase SQL migrations
* RLS policies
* Storage policies
* Models
* Repositories
* Services
* UI
* Authentication
* Encryption layer
* Secure storage
* PIN system
* Biometric authentication
* Categories
* Entries
* Custom fields
* Search
* Settings
* Tests
* README
* SECURITY.md

Where a feature cannot safely be implemented without additional design decisions, clearly isolate it behind an interface rather than implementing an insecure shortcut.

---

# 91. IMPLEMENTATION PRIORITY

If you have to choose between:

A beautiful UI

and

correct security architecture,

choose the security architecture.

If you have to choose between:

More features

and

reliable core functionality,

choose reliable core functionality.

The MVP must prioritize:

1. Authentication
2. Authorization
3. Encryption
4. Secure storage
5. Vault
6. Categories
7. Entries
8. Custom fields
9. Family sharing
10. Documents
11. Search
12. Settings
13. Testing

---

# 92. ACCEPTANCE CRITERIA

The application is considered functional only when the following workflow works:

### User A

Register

↓

Create vault

↓

Create category "Investments"

↓

Create entry "SBI FD"

↓

Add custom fields

↓

Save

↓

Close app

↓

Reopen

↓

Authenticate

↓

View entry

---

### User B

Register

↓

Accept vault invitation

↓

Authenticate

↓

Open KeyDiary

↓

See shared vault

↓

Open Investments

↓

Authenticate if required

↓

View SBI FD

---

### Security test

User B attempts to access an unrelated vault.

Result:

ACCESS DENIED.

---

### Database test

Database contains ciphertext for sensitive values rather than plaintext sensitive information.

---

### Device test

App is backgrounded beyond timeout.

Return to app.

Result:

APP LOCKED.

---

### Biometric test

Protected category opened.

Result:

Biometric prompt.

Failed biometric:

No sensitive data revealed.

---

### PIN test

Incorrect PIN:

Vault remains locked.

Repeated failures:

Rate limiting / delay.

---

# 93. FINAL DEVELOPMENT INSTRUCTION

Build KeyDiary as a real application rather than a prototype mockup.

Start by creating the project architecture and Supabase schema.

Then implement authentication and the secure vault foundation.

Then implement categories and custom entries.

Then implement security features.

Then implement documents, search, activity, and settings.

After each major phase:

1. Run tests.
2. Fix errors.
3. Verify database policies.
4. Verify the UI.
5. Check for sensitive-data leakage.
6. Continue to the next phase.

Do not move forward while the previous phase is fundamentally broken.

Whenever there is a security-sensitive implementation decision, prefer established security practices and current official package documentation rather than inventing a custom solution.

I will connect you to github repo later, but for future instructions, do not push anything without my permission.

The final result should be a polished, maintainable, secure Flutter + Supabase application named **KeyDiary**.
