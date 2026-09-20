---
name: Family Vault & Ledger
colors:
  surface: '#f6fbf5'
  surface-dim: '#d7dbd6'
  surface-bright: '#f6fbf5'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f5f0'
  surface-container: '#ebefea'
  surface-container-high: '#e5e9e4'
  surface-container-highest: '#dfe4df'
  on-surface: '#181d1a'
  on-surface-variant: '#3f4948'
  inverse-surface: '#2c322e'
  inverse-on-surface: '#edf2ed'
  outline: '#707978'
  outline-variant: '#bfc8c7'
  surface-tint: '#2a6865'
  primary: '#004543'
  on-primary: '#ffffff'
  primary-container: '#1d5d5b'
  on-primary-container: '#97d4d0'
  inverse-primary: '#95d1ce'
  secondary: '#565f69'
  on-secondary: '#ffffff'
  secondary-container: '#dae3ef'
  on-secondary-container: '#5c656f'
  tertiary: '#353f3e'
  on-tertiary: '#ffffff'
  tertiary-container: '#4c5655'
  on-tertiary-container: '#c1cbc9'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b1eeeb'
  primary-fixed-dim: '#95d1ce'
  on-primary-fixed: '#00201f'
  on-primary-fixed-variant: '#074f4e'
  secondary-fixed: '#dae3ef'
  secondary-fixed-dim: '#bec7d2'
  on-secondary-fixed: '#141c25'
  on-secondary-fixed-variant: '#3f4851'
  tertiary-fixed: '#dbe5e3'
  tertiary-fixed-dim: '#bfc9c7'
  on-tertiary-fixed: '#141d1c'
  on-tertiary-fixed-variant: '#3f4947'
  background: '#f6fbf5'
  on-background: '#181d1a'
  surface-variant: '#dfe4df'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 34px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 23px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 19px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.03em
  data-mono:
    fontFamily: JetBrains Mono
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 22px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  margin: 1.25rem
  margin-tablet: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

This design system expresses quiet security, archival warmth, and domestic clarity. It rejects both cold, paranoid cyber-security tropes (terminal fonts, neon highlights, locks with warning bars) and unstructured consumer note-taking aesthetics. Instead, it captures the dignity and permanence of a leather-bound family registry or safety deposit ledger translated into a modern, highly legible mobile utility.

The design movement is **Tactile Warm Modernism**: crisp card planes, generous negative space, gentle paper-like undertones, and reassuring micro-interactions. The interface prioritizes multi-generational accessibility—particularly accommodating older adults through generous touch targets, distinct visual grouping, high legibility, and calm, unhurried feedback loops. Every state reassures the user that their household's most critical assets, vital records, medical directives, and passcodes are safeguarded without demanding technical mastery.

## Colors

The palette grounds the interface in comforting earth-and-mineral tones rather than sterile blue or aggressive warning reds.

- **Canvas & Backing**: `#FBF9F5` serves as the primary canvas tint, preventing clinical glare while maintaining optimal contrast. Secondary container surfaces utilize `#F5F3EE`.
- **Card Surfaces**: Pure `#FFFFFF` elevates individual cards above the warm canvas, bounded by subtle linen borders (`#EBE7DF`).
- **Typography**: Primary copy is rendered in deep forest charcoal (`#1F2421`), ensuring 13:1+ contrast against white surfaces. Secondary metadata, timestamps, and descriptive subheaders use warm slate (`#6E7781`).
- **Brand Primary Accent**: Deep Muted Teal (`#1D5D5B`) acts as the anchor for primary actions, selected navigation items, and positive security badges. Its darker press state is `#174846`.
- **Tint Wash**: `#E8F2F0` and `#F0F6F5` provide soft category washes, icon circular backdrops, and active row indicators.
- **Status & Semantics**:
  - *Vault Locked / Encrypted / Synced*: Calm Sage Green (`#2E7D32` text/icon over `#EAF5EA` pill background).
  - *Review Needed / Expiring*: Warm Amber (`#B45309` text over `#FEF3C7` background).
  - *Sensitive / Urgent / Delete*: Muted Rose (`#B91C1C` text over `#FEE2E2` background).

## Typography

Typography is set exclusively in **Plus Jakarta Sans**, chosen for its generous x-height, clear aperture counters, and warm geometric terminals that prevent character confusion (e.g., distinguishing uppercase `I`, numeral `1`, and lowercase `l`). For unmasked passwords, recovery keys, and identification codes, **JetBrains Mono** is utilized strictly to provide unambiguous numeric structure.

- Headlines rely on `600` (SemiBold) rather than aggressive extra-bold or black weights to preserve an editorial, welcoming atmosphere.
- Body text uses a standard `17px` base (`body-lg`) across primary mobile reading lists to accommodate varying visual acuities without requiring systemic magnification.
- Line heights remain comfortably spacious (1.45x–1.55x) to facilitate continuous tracking down data-dense checklists and document indexes.

## Layout & Spacing

The layout model is driven by a single-column content rail for mobile viewports, scaling to a 2-column or 3-column asymmetric utility grid on tablets and foldable split-screens.

- **Mobile Viewports (<600px)**: The standard outer canvas margin is `1.25rem` (`margin`), maximizing horizontal space for document preview cards while retaining a padded, non-crowded perimeter. Internal stack spacing follows strict vertical increments of `0.75rem` (`12px`) and `1rem` (`16px`).
- **Tablet / Large Foldables (600px–1024px)**: Margins expand to `2rem` (`margin-tablet`) with a 12-column fluid grid, typically divided into a 4-column persistent family directory/category list and an 8-column detail ledger.
- **Touch Boundaries**: Every interactive row, sensitive disclosure trigger, and action button enforces an absolute minimum bounding area of `48px × 48px`, regardless of the visual glyph size.

## Elevation & Depth

Visual hierarchy uses tonal surface layering combined with low-opacity ambient shadows tinted with the primary hue rather than dead black.

- **Base Layer (L0)**: `#FBF9F5` canvas background. No shadow.
- **Card Tier (L1)**: `#FFFFFF` resting card atop canvas. Border: `1px solid #EBE7DF`. Shadow: `0 2px 8px rgba(29, 93, 91, 0.04), 0 1px 2px rgba(0, 0, 0, 0.02)`.
- **Interactive / Focus Tier (L2)**: Active cards, search bars, and pressed elements. Border: `1px solid #1D5D5B` at 30% alpha. Shadow: `0 6px 16px rgba(29, 93, 91, 0.07)`.
- **Overlay / Bottom Sheet (L3)**: Modal sheets, drawer controllers, and action sheets. Surface: `#FFFFFF`. Shadow: `0 -4px 24px rgba(31, 36, 33, 0.08)`. Features a top drag indicator (`36px × 4px`, color `#EBE7DF`, rounded pill).
- **Sensitive Blur Overlay**: For masked data panes, an opaque frosted treatment using `backdrop-filter: blur(8px)` with a `rgba(251, 249, 245, 0.85)` surface wash is applied to hide credentials until explicit biometric/tap unlock.

## Shapes

The roundedness tier is set to **Level 2 (Rounded)**. This offers a tactile, friendly physical feel that emulates stationery folders and bound indexes while maintaining formal structure.

- Standard cards, grouped list containers, and text fields use `rounded-lg` (`1rem` / `16px`).
- Nested chips, category badges, and lock indicators use full pill radii (`rounded-full` / `9999px`) to immediately convey their status and interactive filter roles.
- Action sheets and modal dialogs adopt `rounded-xl` (`1.5rem` / `24px`) along top contours.

## Components

### Buttons
- **Primary**: Full-width or inline container with solid `#1D5D5B` fill, `#FFFFFF` text (`label-lg`), `1rem` corner radius, and `52px` height on mobile. Subtle scale transition (`0.98`) upon active press.
- **Secondary / Ghost**: `#FFFFFF` surface with `1px solid #EBE7DF` outline and `#1D5D5B` text. On press, shifts to `#F0F6F5`.
- **Mask Reveal Toggle**: Soft pill button with `36px` height, featuring `#E8F2F0` background, `#1D5D5B` icon (eye / eye-slash), and `body-sm` label.

### Cards & Category Tiles
- **Category Summary Tiles**: Arranged in a 2-column grid on mobile. White surface, `1px solid #EBE7DF` border, `16px` padding. Contains a `44px` circular badge with `#E8F2F0` fill housing a `#1D5D5B` monochrome icon, followed by `headline-sm` title and `body-sm` count label.
- **Entry Record Card**: Horizontal list-card pattern. Leading category glyph, title in `label-lg`, metadata subtitle in `body-sm` (`#6E7781`), and a trailing chevron or sensitive masked dot cluster (`•••• ••••`).

### Input Fields & Sensitive Disclosures
- **Input Field**: Height `52px`, `rounded-lg`, background `#FFFFFF`, border `1px solid #EBE7DF`. Floating label in `label-md` (`#6E7781`). Active focus state applies a `1.5px` border in `#1D5D5B` without harsh drop shadows.
- **Masked Data Presentation**: Monospace text (`JetBrains Mono`) with subtle letter spacing, placed in an inset container with `#F5F3EE` background and a single-tap copy button with haptic feedback confirmation.

### Status Badges & Security Indicators
- **Vault Status Pill**: Placed subtly in the top app bar. Displays an outline shield or padlock icon with a small sage green dot (`#2E7D32`) and text: "Family Vault Locked" or "Synced just now" in `label-sm`. No intrusive siren colors or alert banners.
- **Access Level Tag**: Pill badge with `label-sm` font designating item ownership (e.g., "Shared with Parents", "Private to Me") using `#F5F3EE` background and `#6E7781` text.

### Bottom Sheets
- Rounded top corners (`24px`), persistent top-center pill handle (`width: 36px`, `height: 4px`, `background: #EBE7DF`, `margin-top: 8px`). Contains step-by-step confirmation for revealing master pins or emergency contact instructions.