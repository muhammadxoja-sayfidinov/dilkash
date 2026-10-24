# Dilkash Restaurant Apps — Architecture & Design Decisions (DECISIONS.md)

This document records the architectural, design, brand, and product decisions made by the Lead Flutter Architect, Product Designer (UI/UX), and QA Engineer.

---

## 1. Brand Identity & Visual Language

### Brand Concept
- **Restaurant Name:** Dilkash (Oʻzbekcha: *Dilkash* — "dilni quvontiruvchi, yoqimli, samimiy").
- **Cuisine:** Premium authentic Uzbek cuisine (Toshkent Toʻy Oshi, Gʻijduvon Shashlik, Tandir Somsa, Qozon Kabob, Lagʻmon) with modern presentation and packaging.
- **Visual Personality:** Warm, trustworthy, culinary-focused, modern editorial. Inspired by Wolt and Uber Eats, with cultural Uzbek authenticity (ornamental micro-motifs, rich culinary tones).

### Color System (Hex & Semantics)
- **Primary — Dilkash Forest Emerald:**
  - Light mode: `#0D6B4E` (Primary 500), `#08523B` (Primary 700), `#E8F5EF` (Primary 50 / Soft tint).
  - Dark mode: `#10B981` (Primary 400), `#142820` (Surface Emerald tint).
  - *Rationale:* Evokes culinary freshness, herbal seasoning (rayhon, kashnich), halal hospitality, and premium prestige.
- **Accent — Saffron & Woodfire Amber:**
  - `#D97706` (Amber 600), `#F59E0B` (Amber 500), `#FFFBEB` (Amber 50).
  - *Rationale:* Associated with golden rice grains (osh), woodfire tandoor ovens, and appetizing warmth.
- **Neutrals & Surfaces:**
  - Light background: `#F8FAFC` (Slate 50), Card: `#FFFFFF`, Borders: `#E2E8F0` (Slate 200).
  - Dark background: `#09100C` (Deep Pine Night), Card: `#111D17`, Borders: `#1E3529`.
  - Avoids pure black `#000000` to prevent harsh contrast and visual fatigue.
- **Semantic Feedback:**
  - Success: `#059669`
  - Warning: `#D97706`
  - Error: `#E11D48`
  - Navigation / Info: `#2563EB`

### Typography & Orthography
- **Font Stack:** Clean geometric modern typography with full Latin and Cyrillic support.
- **Uzbek Latin Letters:** Strict correct handling of `oʻ` (U+02BB modifier letter turned comma or U+02BC apostrophe) and `gʻ`, avoiding generic backticks (`` o` ``) or ugly quote breaks.
- **Currency & Formatting:** Standard Uzbek formatting: `45 000 soʻm` (non-breaking thin space between thousands, lowercase `soʻm`). Phone format: `+998 (90) 123-45-67`.

---

## 2. Anti-"AI-Generated" Design Directives

To guarantee the apps look handcrafted by a top product design studio:
1. **No Emojis as Icons:** Replace all emoji badges (`🚀`, `🛍️`, `🔥`) with crisp, vector-rendered SVG/Material Rounded icons.
2. **Editorial Hierarchy:** Reject repetitive uniform grids. Introduce dynamic pacing:
   - Sticky category header with active tab indicator and item counts.
   - Featured chef's specials hero banner with realistic food imagery.
   - Distinct horizontal cards for "Mashhur taomlar" (Trending).
   - Two-column dense menu cards with quick-add steppers and portion tags.
3. **Tactile Interaction:**
   - Haptic feedback on quantity steppers.
   - Bottom sheet modals with drag handles and physics-based dismiss.
   - Smooth animated swipe-to-confirm slider for couriers.
   - Subtle badge scale animations on cart updates.

---

## 3. Monorepo Architecture & Package Structure

```
New Folder With Items/
├── packages/
│   └── dilkash_design_system/     <-- Shared design tokens, widgets, formatters
├── customer_app_flutter/          <-- Customer delivery & pickup app
├── courier_app_flutter/           <-- Courier navigation & order delivery app
└── restaurant_system/             <-- Django POS & Kitchen backend
```

- **Shared Design System (`packages/dilkash_design_system`):**
  - Exports tokens: `DilkashColors`, `DilkashTypography`, `DilkashSpacing`, `DilkashRadii`, `DilkashShadows`.
  - Exports reusable UI: `DilkashButton`, `DilkashTextField`, `DilkashChip`, `DilkashDishCard`, `DilkashBottomSheet`, `DilkashQuantityStepper`, `DilkashStatusStepper`, `DilkashSkeleton`, `DilkashEmptyState`, `DilkashSwipeButton`.
  - Exports utilities: `UzbekFormatters` (currency, phone, date), `UzbekStrings`.

- **State Management:**
  - Clean separation: Domain Entities -> Repositories / API Services -> Providers / Notifiers -> UI Screens.
  - Ensures seamless hot-reload compatibility with running Flutter instances on physical devices.

---

## 4. Connectivity & Physical Device Strategy
- Base URL is dynamic and persisted in `SharedPreferences`.
- Supports both Local Wi-Fi IP (`http://10.40.4.94:8000`), ADB reverse USB (`http://127.0.0.1:8000`), and Cloudflare HTTPS tunnel fallback.
- Image URLs automatically prepend the active `baseUrl` if relative paths (`/media/...`) are returned by the backend.

---

## 5. Definition of Done & Quality Gate
1. `flutter analyze` passes with 0 errors and 0 warnings on all packages and apps.
2. All 89 QA backend tests in `qa_engine_test.py` pass 100%.
3. Full light and dark theme support across all screens.
4. Tap targets >= 48x48 dp with high contrast AA compliance.
