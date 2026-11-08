# Dilkash POS — UI/UX Audit & Reconnaissance Report (Phase 0)

**Date:** 2026-11-08  
**Target:** `pos_desktop_csharp/` (.NET 8 WPF)  
**Branch:** `design/pos-redesign`  

---

## 1. Executive Summary

This audit confirms and validates the design diagnosis outlined in the Senior UI/UX Redesign Brief (§3). Baseline snapshot captures across all 4 target viewport resolutions (`1366x768`, `1600x900`, `1920x1080`, `2560x1440`) have been generated and archived in `docs/design/snapshots/before/`.

All 18 diagnostic points from the brief were verified directly in the codebase:

| Item # | Diagnostic Issue | Status in Codebase | Evidence / Location |
|---|---|---|---|
| **1** | Emojis used as icons everywhere | **CONFIRMED** | `MainWindow.xaml` lines 28, 38-42, 64; `MainWindow.xaml.cs` lines 264, 415-420, 586, 593-596; `PaymentDialog.xaml` lines 49-51. Emojis like 🍵, 🍽, ⚡, 🛑, 📲, 📊, ⚙, 👤, 🏷, 💳, 🔒, 🥩, 🥟, 🍲, 🍔, ☕. |
| **2** | Hard-coded colors scattered | **CONFIRMED** | >100 hex literals in `MainWindow.xaml`, 37 in `Views/*.xaml`, 16 `Color.FromRgb` in code-behind. Only 13 tokens in `App.xaml`. |
| **3** | Palette drifts from brand | **CONFIRMED** | Code uses Tailwind slate-blue (`#0B1120`, `#0F172A`, `#1E293B`, `#334155`) instead of official Dilkash Deep Pine tokens (`#09100C`, `#111D17`, `#182820`, `#1E3529`). |
| **4** | 1366x768 cramped product grid | **CONFIRMED** | 1366px screen width − 280px sidebar − 260px categories − 460px cart − margins leaves <330px width, causing product grid to wrap to a single column. |
| **5** | Flat button hierarchy | **CONFIRMED** | Single button template with opacity-only hover/pressed triggers, no focus ring, no ghost or segmented controls. |
| **6** | Typography default & non-tabular | **CONFIRMED** | Default Segoe UI, no `Typography.NumeralAlignment="Tabular"`, prices and timers jump when values tick. |
| **7** | Dev jargon leaks into UI | **CONFIRMED** | "Professional Enterprise Edition (1920x1080 Full HD)", "1920x1080 Enterprise Kassa", "Django REST API URL". |
| **8** | Uzbek orthography non-compliant | **CONFIRMED** | Uses ASCII apostrophe `'` (`so'm`, `Bo'sh`, `O'chirish`) instead of official Uzbek turned comma `ʻ` (U+02BB: `soʻm`, `Boʻsh`). |
| **9** | Native `MessageBox.Show` calls | **CONFIRMED** | 26 separate `MessageBox.Show` calls across MainWindow and dialogs. |
| **10** | Inconsistent borderless dialogs | **CONFIRMED** | Modal dialogs are plain borderless windows with no backdrop scrim, no entry animation, and disparate widths (480px, 680px, 820px). |
| **11** | Table status color semantics | **CONFIRMED** | Occupied tables use red (`#EF4444`), giving the impression of an error rather than an active guest table. |
| **12** | `Product.ImageUrl` unused | **CONFIRMED** | 0 references to `ImageUrl` in UI views; tiles render as plain text-only containers. |
| **13** | Whole grid cleared on every tap | **CONFIRMED** | `ProductsWrapPanel.Children.Clear()` and `TablesWrapPanel.Children.Clear()` called on every interaction, causing redraw flicker. |
| **14** | Touch ergonomics missing | **CONFIRMED** | `PanningMode="VerticalOnly"` not used; stylus flicks and tap feedback unmanaged. |
| **15** | Rainbow KPI card borders | **CONFIRMED** | Four mismatched border colors (emerald, sky, purple, amber) without a cohesive surface hierarchy. |
| **16** | Absence of designed empty/loading states | **CONFIRMED** | No loading skeletons or designed empty states for tables, search results, or stop-list. |
| **17** | Wasted sidebar screen real estate | **CONFIRMED** | 280px static sidebar plus 100px header and 95px profile block consume substantial width. |
| **18** | Missing executable identity | **CONFIRMED** | Default generic WPF executable icon, no custom `.ico`, no splash screen. |

---

## 2. Baseline Snapshots Inventory

The baseline automated capture generated 44 high-resolution images in `docs/design/snapshots/before/`:

- **1366x768:** `tables.png`, `quick_pos.png`, `stop_list.png`, `online.png`, `shift.png`, `settings.png`, `dialog_payment_cash.png`, `dialog_open_table.png`, `dialog_item_modifier.png`, `dialog_discount.png`, `dialog_shift_report.png`
- **1600x900:** same 11 views
- **1920x1080:** same 11 views
- **2560x1440:** same 11 views

## 3. Phase 0 Gate Verification
- [x] Codebase fully inspected and read.
- [x] Compilation verified (`dotnet build -c Release` succeeded with 0 errors).
- [x] CLI `--demo` and `--snapshots` entry points active and operational.
- [x] Baseline "before" snapshots captured across all target resolutions.
- [x] Infinite recursion bug in `Order.RecalculateTotals()` resolved.
- [x] Branch `design/pos-redesign` initialized.

Phase 0 Recon is complete. Proceeding to Phase 1 Foundations.
