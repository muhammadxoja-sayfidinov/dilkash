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
1. `flutter analyze` passes with 0 errors and 0 warnings on all packages and apps (`dilkash_design_system`, `customer_app_flutter`, `courier_app_flutter`).
2. All 89 QA backend tests in `qa_engine_test.py` pass 100%.
3. Full light and dark theme support across all screens.
4. Tap targets >= 48x48 dp with high contrast AA compliance.

---

## 6. Phase 3 & 4 Architectural Decisions

### Pure Dart Mapping Engine vs Native SDKs
- **Decision:** Pinned `flutter_map: ^7.0.2` and `latlong2: ^0.9.1` using CartoDB Voyager raster tiles (`https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png`).
- **Rationale:** Native Google Maps or Yandex MapKit SDKs require platform API keys with billing and frequently crash in cross-platform development environments or trigger FFI asset loading errors (such as `DOBJC_initializeApi` in objective_c.dylib). CartoDB Voyager delivers high-DPI, ultra-fast tiles, eliminates OpenStreetMap Foundation rate limit warnings, and is 100% pure Dart, running seamlessly across iOS, Android, and Web without any external native dependencies.
- **External Navigation Integration:** In addition to the in-app interactive map, couriers have one-tap access to launch Yandex Navigator (`yandexnavi://build_route_on_map`) or Google Maps (`https://www.google.com/maps/dir/`), providing turn-by-turn spoken directions when needed.

### Tactile Courier Status Progression (`DilkashSwipeButton`)
- **Decision:** State transitions (`accepted` -> `preparing` -> `delivering` -> `delivered`) in the Courier app use a physical drag slider rather than simple touch buttons.
- **Rationale:** Couriers operate on motorcycles or bicycles with one hand or with gloves. Accidental taps on delivery completion buttons cause severe real-world operational issues. A deliberate 80% swipe threshold eliminates accidental triggers.

### Reverse Geocoding & Localized Map Address Picker
- **Decision:** The customer address picker allows both pinpointing on the interactive map sheet and automatic reverse geocoding via OpenStreetMap Nominatim with Uzbek language headers (`Accept-Language: uz,en`).
- **Rationale:** Provides familiar Wolt/Yandex Eda user experience where dragging the map instantly fills in the street name and building number.

---

## 7. Telegram Bot Scope & Staff Role Isolation

### Customer-Only Telegram Architecture
- **Decision:** The Telegram bot (`@tosh_qogoz_bot`) is strictly, 100% customer-facing. All staff roles (Oshpaz, Kassir, Ofitsiant, Kuryer) have been completely removed from Telegram.
- **Role Allocations:**
  1. **Mijoz (Customer):** Telegram Bot & `customer_app_flutter`.
  2. **Kassir (Cashier):** Dedicated Web Desktop POS (`/cashier/`).
  3. **Oshpaz (Chef):** Dedicated Kitchen Display System (`/chef_panel/` and `/kitchen/`).
  4. **Ofitsiant (Waiter):** `courier_app_flutter` (Waiter floor view & live order sheets).
  5. **Kuryer (Courier):** `courier_app_flutter` (Live navigation & order tracking).
- **Rationale:** Staff operating via Telegram inline buttons (`chef_confirm`, `courier_on_way`, `waiter_served`) caused severe role confusion, security vulnerabilities, and messy chat feeds. Isolating staff roles to POS/KDS screens and Flutter apps guarantees production stability and gives staff rich desktop/mobile UI tools. Any staff queries typed into the bot are gracefully redirected to the staff applications while presenting the customer ordering menu.

---

## 8. Flutter Widget Lifecycle & Courier Account Architecture

### Unmounted Context Lifecycle Fix
- **Problem:** When navigating from `StaffLoginScreen` to `CourierOrdersScreen` or `WaiterFloorScreen`, passing an inline callback `onLogout: () { Navigator.pushReplacement(context, ...); }` captured the `_StaffLoginScreenState.context`. Because `pushReplacement` unmounted the login screen, invoking the callback during logout threw Flutter assertion: `This widget has been unmounted, so the State no longer has a context`.
- **Solution:** Screen components manage their own navigation lifecycle. When logging out, screens call `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const StaffLoginScreen()), (route) => false)` using their own active, mounted `BuildContext`, clearing the entire stack and preventing stale closure context leaks.

### Comprehensive Courier Account Screen (`CourierAccountScreen`)
- **Features Implemented:**
  1. **Courier Profile Header:** Display name, phone (+998), courier badge/ID, active status toggle (Online/Offline), vehicle badge, and rating stars (4.95 ⭐).
  2. **Earnings & Shift Overview:** Daily deliveries count, earned sum, tips amount, weekly payout projection, and interactive breakdown bottom sheet with transparent calculation formulas.
  3. **Vehicle & Equipment Preferences:** Choice between Piyoda (Foot), Velosiped (Bicycle), Skuter/Moped (Scooter), and Avtomobil (Car) with thermal bag verification checklist and max delivery radius slider (1–25 km).
  4. **Navigation Integration:** Default navigation engine selection (Yandex Navigator, Google Maps, Apple Maps, or In-App Map).
  5. **Application Personalization:** Theme mode selector (Kunduzgi / Tungi / Tizimga mos) powered by `StaffThemeController`, language picker (Uzbek Latin / Russian / English), and sound/vibration alerts toggle.
  6. **Network Diagnostics:** Live backend server URL configuration with real-time ping and latency measurement (`api/health/` or `api/orders/`).
  7. **Courier Support & Safety Handbook:** Road safety rules, Dilkash hotline (+998 71 200-00-00), Telegram dispatcher contact, and safe confirmed logout dialog.
---

## 9. Unified Single-Café Staff App Architecture (Dilkash Staff)

### Single-Café Domain Context
- **Restaurant Scope:** Dilkash is a single café with one central kitchen, one hall layout, and one shared menu.
- **Internal Staff vs Gig Marketplace:** All waiters and couriers are contracted internal employees with verified staff codes, shared shift tracking, and direct accountability to the café manager and cashier.

### Authentication, Role Guards & Switching
- **Unified Auth:** Staff members log in using Phone Number / Staff Code + 4-digit PIN.
- **Server-Verified Roles:** The backend payload returns `assigned_roles: ['courier', 'waiter']`. The client never trusts client-side role claims.
- **Role Selection Screen:** Displayed immediately after authentication. If an employee only has one role, they are routed directly. If assigned both roles, they choose their active mode.
- **Zero-Logout Switching:** Multi-role staff can switch between Courier and Waiter mode via the profile screen in 1 tap without re-authenticating, preserving active shifts and tokens.
- **Biometric Unlock:** After first successful login, biometrics can be enabled via `SharedPreferences` to authenticate in <1s.

### Shift Management & Non-Shift Guarding
- **Shift Life Cycle:** `clockedOut` -> `clockedIn` <-> `onBreak` -> `clockedOut`.
- **Shift Bar:** Persistent sticky header across Courier and Waiter dashboards displaying live elapsed shift duration, active/break status toggle, and quick clock-out.
- **Operational Guard:** The app strictly forbids claiming new delivery orders or opening tables when the employee is clocked out or on break.

### Order State Machine & Audit Trail
- **Unified Engine (`OrderStateMachine`):** Centralized finite state machine governs all transitions for both dine-in and delivery flows. Disallowed state hops throw `OrderStateTransitionException`.
- **Sensitive Operations & Manager Override (`ManagerPinDialog`):** Discounts (>0%), item cancellations/voids after sending to kitchen, and cash handover discrepancies require a 4-digit Manager PIN override.
- **Audit Logging (`AuditLogger`):** All sensitive actions, cancellations, voids, and discrepancies are logged with timestamp, employee ID, and action metadata for cashier reconciliation.

### Courier Workflow Architecture
1. **Order Queue & Sequence:** Orders are prioritized by proximity, ready state, and promised delivery time with a suggested sequence algorithm.
2. **Audio & Haptic Alerts:** Incoming orders pop a modal with a 30-second circular countdown timer, high-priority sound, and heavy vibration.
3. **6-Stage Lifecycle:** `assigned` -> `headingToCafe` -> `pickedUp` (with 4-point packaging checklist: dishes, drinks, sauces, thermal seal) -> `onTheWay` -> `arrived` -> `delivered` (validated with 4-digit customer confirmation code or photo proof).
4. **Navigation & Map:** Interactive in-app CartoDB Voyager map sheet plus deep linking to Yandex Maps (`yandexmaps://`), Google Maps, and 2GIS.
5. **Problem Escalation:** Customer unreachable, wrong address, customer refusal, damaged item. Customer unreachable activates a 5-minute countdown timer with automatic manager escalation upon expiry.
6. **Cash Handover:** Running shift balance separates collected restaurant cash from courier earnings. Shift-end handover calculates exact discrepancy and logs cashier PIN sign-off.

### Waiter Workflow Architecture
1. **Hall Floor Plan:** 3 distinct zones (Asosiy Zal, Ochiq Terrasa, VIP Xonalar) with high-visibility color tokens:
   - Yashil (Boʻsh / Free)
   - Qizil (Band / Occupied)
   - Sariq (Oshxonada / Cooking)
   - Koʻk (Dasturxonga tayyor / Ready to serve)
   - Toʻq sariq (Hisob soʻralgan / Bill requested)
   - Binafsharang (Bron / Reserved)
2. **Table Operations:** Open table with guest headcount selector (1–12), transfer table, merge tables.
3. **Order Entry System:** Category filtering, fast search, multi-modifier sheets (portion sizes, extras, remove ingredients), course timing (birga / oldin), seat assignment per guest, and allergen warning tags.
4. **Kitchen Ticket Routing:** Kitchen items route to Oshpaz (Hot/Cold) while beverages route to Bar.
5. **Item-Level Kitchen Tracking:** Live status indicators (`new` -> `preparing` -> `ready` -> `served`).
6. **Bill & Split Engine:** Itemized receipt, 10% standard service charge, VIP discounts, equal split among guests, split by guest seat, split by individual dish, and multi-payment options (Naqd, Click, Payme, Uzcard/Humo).
7. **Guest Calls & Reservations:** Real-time banner alerts for table QR "Chaqiruv" requests and reservations management with arrival check-in.

### Staff-UX Ergonomics
- **Large Tap Targets:** Minimum touch target height >= 56dp for one-handed operation while holding trays or riding delivery vehicles.
- **Undo Snackbars:** Destructive actions require manager PIN; non-destructive quick actions leverage 4-second undo snackbars rather than jarring confirmation modals.
- **Uzbek Latin Typography:** Strict compliance with Uzbek grammar and character sets (`oʻ`, `gʻ`, `soʻm`, `+998`).
