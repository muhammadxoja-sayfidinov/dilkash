# Dilkash Restaurant System — Comprehensive Codebase Audit (AUDIT.md)

**Date:** October 2026  
**Auditors:** Lead Flutter Architect, Senior Product Designer (UI/UX), QA Engineer  
**Scope:** `customer_app_flutter`, `courier_app_flutter`, `restaurant_system` API interfaces

---

## 1. Visual & Design Problems (The "AI-Generated" Look)

### 1.1 Inconsistent Brand Identity & Colors
- **Dual Conflicting Palettes:** `customer_app_flutter` uses `AppColors` with emerald and amber tones, while `courier_app_flutter` uses `StaffColors` with slightly different hex codes (`#0D6B4E` vs `#10866A`), creating brand fragmentation.
- **Generic AI Gradients:** Arbitrary linear gradients applied haphazardly (e.g., promo banner using `[Color(0xFF0F172A), Color(0xFF334155)]`, app bar avatar using `[Color(0xFF10866A), Color(0xFF0D6B4E)]`). Lacks a coherent design system tokens logic.
- **Emoji Badges Used as UI Elements:**
  - `OrderTrackingScreen`: `'🚀 Yetkazib berish'`, `'🛍️ Olib ketish'`
  - `OnboardingScreen`: `'🔥 PREMIUM SIFAT'`, `'🚀 30 DAQIQADA'`, `'🎁 5% KESHBEK'`
  - `CartScreen`: Emojis in address chips and buttons.
  - *Standard:* Production apps (Wolt, Yandex Eda, Uber Eats) use crisp vector iconography (SVG / rounded line glyphs), never raw OS system emojis.

### 1.2 Layout & Hierarchy Weaknesses
- **Monotonous Uniform Cards:** The home screen features a basic 2-column grid where every single card is identical. There is no editorial pacing (e.g., featured hero specials, carousel for popular dishes, category headers with badges, or portion indicators).
- **Inconsistent Border Radii:** Radii vary wildly: `10`, `14`, `16`, `18`, `20`, `24`, and `28` without a mathematical 4/8pt spacing or radius scale.
- **Crude Fallbacks:** Missing food images fall back to standard Material icon `Icons.fastfood` inside a flat color rectangle rather than a sleek branded skeleton loader or food illustration.

### 1.3 Typography & Language
- Default fallback fonts without refined letter-spacing, line-heights, or weights.
- Uzbek Latin orthography uses standard ASCII single quotes (`'`) instead of correct modifier turned commas (`oʻ`, `gʻ`), leading to jagged typographic rhythm.

---

## 2. UX Problems

### 2.1 Customer App
- **Overcrowded Cart & Checkout (`cart_screen.dart` - 1,076 lines):**
  - Map picker, district selection, name/phone inputs, tips, payment method, and summary are all stacked without clear visual step progression.
  - Small tap targets on quantity controls (+ / - buttons < 40dp).
  - Promo code / voucher entry is missing entirely.
  - No delivery time option (instant 30 min vs scheduled time slot).
- **Missing Options & Customization (`dish_detail_sheet.dart`):**
  - Dishes cannot be customized with portions (1 pors vs 0.7 pors), condiments (sirka, achchiq sous, piyoz), or cutlery requests.
- **Customer Tracking Lacks Real-Time Map:**
  - `order_tracking_screen.dart` uses a static stepper list without an interactive live map displaying the courier's real-time position moving toward the delivery destination.
  - No one-tap phone call button to contact the assigned courier directly.

### 2.2 Courier App
- **Active Order Experience (`courier_delivery_screen.dart` - 984 lines):**
  - Action confirmation relies on standard buttons rather than a tactile "Swipe-to-Deliver" / "Swipe-to-Pickup" slider, creating risk of accidental taps while driving.
  - No incoming order modal with animated countdown timer (e.g., 30s accept/reject window).
  - Couriers lack an online/offline availability switch on their main dashboard.
  - Earnings dashboard (daily completed deliveries, tips, cash collected) is completely missing.

---

## 3. Missing or Broken Functionality

| Feature | Customer App | Courier App | Status / Impact |
|---|---|---|---|
| Shared Design System Package | ❌ Missing | ❌ Missing | Duplicated, drifting styling code |
| Live Courier Tracking Map | ❌ Missing on Customer screen | ⚠️ Present but unmodular | Customer cannot see courier location |
| Online/Offline Courier Status | N/A | ❌ Missing | Courier cannot go off-duty |
| Incoming Order Audio/Countdown | N/A | ❌ Missing | Courier misses urgent delivery alerts |
| Promo Code Engine | ❌ Missing | N/A | Marketing discounts unavailable |
| Delivery Time Scheduler | ❌ Missing | N/A | Customers cannot schedule orders |
| Courier Earnings / Wallet | N/A | ❌ Missing | Courier cannot see daily revenue |
| Offline / Network Error States | ⚠️ Basic text only | ⚠️ Basic text only | No retry illustrations or cache recovery |

---

## 4. Architecture & Code Smells

1. **God Classes & Monolithic Files:**
   - `cart_screen.dart`: 1,076 lines handling UI, state, validation, geocoding, and map rendering.
   - `courier_delivery_screen.dart`: 984 lines combining map routing, distance formulas, status updates, and sheet widgets.
   - `home_screen.dart`: 601 lines combining banners, filters, grid rendering, and order tracking dialogs.
2. **Hardcoded IP Addresses:**
   - `models/dish.dart` line 39: `img = 'http://127.0.0.1:8000$img';` breaks image display whenever the app runs on a physical device over Wi-Fi (`10.40.4.94`).
3. **Fragmented State Management:**
   - Customer app uses `Provider`, while Courier app relies on raw `setState` and `ListenableBuilder(StaffThemeController)`.
4. **Imperative Routing:**
   - Ubiquitous `Navigator.push(MaterialPageRoute(...))` without named or declarative routing, preventing deep linking or clean navigation stacks.
5. **Lack of Immutability:**
   - Models are mutable Dart classes with handwritten JSON parsing lacking runtime safety.

---

## 5. Performance Issues

1. **Unbounded Network Image Loading:**
   - Standard `Image.network` is used without `cached_network_image`, causing duplicate network requests and image flickering on scroll.
2. **Aggressive Polling:**
   - Unthrottled `Timer.periodic(Duration(seconds: 7))` in tracking screens drains battery without checking whether the screen is currently visible or in background.
3. **Widget Rebuild Overhead:**
   - Lack of `const` constructors on static subtrees leads to needless rebuilds of heavy widgets.

---

## 6. Audit Verdict
Both apps have working backend integrations, but their visual presentation, UX patterns, and architecture reflect prototype-level code. Rebuilding them with a shared design system package, production-grade components, and Wolt/Uber Eats level polish will transform them into world-class applications.
