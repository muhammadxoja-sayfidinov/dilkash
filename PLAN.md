# Dilkash Restaurant Apps — Implementation Plan & Milestones (PLAN.md)

## Status: IN PROGRESS

---

### Phase 0: Audit & Architecture Blueprint
- [x] Comprehensive Codebase Audit (`AUDIT.md`)
- [x] Product & Architectural Decisions (`DECISIONS.md`)
- [x] Git repository initialization and clean `.gitignore`
- [x] Implementation Plan with Milestones (`PLAN.md`)

---

### Phase 1: Shared Design System (`packages/dilkash_design_system`)
- [ ] Milestone 1.1: Initialize Flutter package `dilkash_design_system`
- [ ] Milestone 1.2: Design Tokens (DilkashColors, DilkashTypography, DilkashSpacing, DilkashRadii, DilkashShadows, Light & Dark themes)
- [ ] Milestone 1.3: Reusable UI Components:
  - `DilkashButton` (Primary, Secondary, Outline, Danger, all states: normal, hover, pressed, disabled, loading)
  - `DilkashTextField` (Phone +998 formatter, search input, address input, password/PIN)
  - `DilkashChip` (Category filter pills, status badges)
  - `DilkashDishCard` (Editorial menu item card with badge, price, quick-add stepper)
  - `DilkashQuantityStepper` (Haptic + / - stepper)
  - `DilkashStatusStepper` (Order progress tracker with custom icons)
  - `DilkashSwipeButton` (Tactile swipe-to-confirm for courier orders)
  - `DilkashBottomSheet` (Modern rounded modal container with drag handle)
  - `DilkashSkeleton` & `DilkashEmptyState` (Shimmer loaders and illustrated empty screens)
- [ ] Milestone 1.4: Uzbek Formatters & Localization utilities (`UzbekFormatters`, currency UZS, dates, clean `oʻ` and `gʻ`)
- [ ] Milestone 1.5: Unit & Widget verification, `flutter analyze` (0 errors, 0 warnings)

---

### Phase 2: Customer App Overhaul (`customer_app_flutter`)
- [ ] Milestone 2.1: Add `dilkash_design_system` dependency & update themes
- [ ] Milestone 2.2: Redesign Onboarding & Phone + OTP Login (with quick server selector)
- [ ] Milestone 2.3: Redesign Home Feed (Editorial hero carousel, sticky category tabs, trending items, 2-column menu grid)
- [ ] Milestone 2.4: Dish Details Modal Sheet (Portion selection, condiments, custom notes, cart add animation)
- [ ] Milestone 2.5: Cart & Checkout Screen (Delivery vs Pickup, scheduled time, interactive map pin, promo code discount engine, tip buttons, Payme/Click/Cash)
- [ ] Milestone 2.6: Live Order Tracking Screen (Timeline, interactive live map with courier pin and route, direct courier call button)
- [ ] Milestone 2.7: My Orders (Active vs History, reorder button, review modal)
- [ ] Milestone 2.8: Profile Screen (Saved addresses, cashback points, theme mode switcher, language preference)

---

### Phase 3: Courier App Overhaul (`courier_app_flutter`)
- [ ] Milestone 3.1: Add `dilkash_design_system` dependency & update staff theme
- [ ] Milestone 3.2: Redesign Courier Login & Online/Offline Duty Switch
- [ ] Milestone 3.3: Orders Dashboard (Assigned orders, Open orders pool, Order claim dialog)
- [ ] Milestone 3.4: Incoming Order Alert Modal (with 30-second countdown and audio/vibration cues)
- [ ] Milestone 3.5: Active Delivery Navigation Flow with tactile Swipe-to-Confirm slider:
  - Step 1: Restaurant pickup
  - Step 2: On the way to customer
  - Step 3: Arrived & delivered
- [ ] Milestone 3.6: Courier Interactive Map with route polyline, distance (km), ETA, and one-tap Yandex/Google navigation
- [ ] Milestone 3.7: Courier Earnings & Shift Summary Dashboard (Today's deliveries, cash collected, tips, rating)

---

### Phase 4: Architecture, Resilient Networking & Real-Time Sync
- [ ] Milestone 4.1: Centralized API service with dynamic LAN IP detection and fallback
- [ ] Milestone 4.2: Robust error handling, retry policies, and offline state handling
- [ ] Milestone 4.3: Lifecycle-aware polling for order tracking and courier location

---

### Phase 5: Quality Assurance & Delivery
- [ ] Milestone 5.1: `flutter analyze` returns zero issues across all apps and packages
- [ ] Milestone 5.2: Verification of backend compatibility (89/89 tests passing 100%)
- [ ] Milestone 5.3: Component and integration tests
- [ ] Milestone 5.4: Detailed README.md for both apps
- [ ] Milestone 5.5: Final walkthrough and presentation
