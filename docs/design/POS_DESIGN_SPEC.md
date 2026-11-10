# Dilkash POS — Design System & UI Specification

**Branch:** `design/pos-redesign`  
**Stack:** WPF (.NET 8 Windows, `net8.0-windows`, zero third-party UI packages)  
**Product Metadata:** `Dilkash POS` v`2.0.0` (`Dilkash Milliy Taomlar`)  
**Language & Formatting:** Uzbek Latin using typographic okina `ʻ` (`U+02BB`), 24h clock, tabular numbers, `MoneyFormatter` (`\u00A0so\u02BBm`, non-breaking space separators).

---

## 1. Visual Foundations & Tokens (`Resources/Theme/Tokens.xaml`)

### 1.1 Deep Pine Color Palette
All theme colors are defined once in `pos_desktop_csharp/Resources/Theme/Tokens.xaml` with frozen `SolidColorBrush` resources (`po:Freeze="True"`) consumed exclusively via `{DynamicResource}` (supporting clean future theme switching).

| Token | Hex | Role |
|---|---|---|
| `ColorBg` | `#09100C` | Primary app canvas & shell backdrop |
| `ColorSurface` | `#111D17` | Cards, panels, top bar, nav rail |
| `ColorSurfaceElevated` | `#182820` | Modals, toasts, elevated interactive plates |
| `ColorInput` | `#0D1712` | Input fields (`TextBox`, `ComboBox`, `SearchBox`) |
| `ColorBorder` | `#1E3529` | Default strokes & card dividers |
| `ColorBorderSubtle` | `#14241C` | Hairline separators & structural borders |
| `ColorBorderHover` | `#2B4B3B` | Hover stroke elevation |
| `ColorTextPrimary` | `#F8FAFC` | Primary headings, labels, amounts |
| `ColorTextSecondary` | `#94A3B8` | Supporting text & captions |
| `ColorTextMuted` | `#8494A7` | Micro-labels & timestamps |
| `ColorTextOnError` | `#FFFFFF` | Foreground on destructive solid fills |
| `ColorPrimary` | `#0D6B4E` | Brand Emerald action surface |
| `ColorPrimaryBright` | `#10B981` | Active borders, grand totals, highlights |
| `ColorPrimaryPressed` | `#0A5840` | Pressed CTA state |
| `ColorPrimaryTint` | `#063628` | Occupied/selected card tint |
| `ColorAmber` | `#D97706` | Warm Saffron secondary highlight CTA |
| `ColorAmberBright` | `#F59E0B` | Focus ring (`BrushFocusRing`), warnings, bill-printed indicator |
| `ColorAmberTintSoft` | `#36200D` | Pre-chek / warning card surface |
| `ColorSuccess` | `#059669` | Success feedback |
| `ColorError` | `#E11D48` | Destructive button fill |
| `ColorErrorBright` | `#FB7185` | Errors, stop-list strokes, overdue urgency |
| `ColorErrorTintSoft` | `#36121C` | Stop-listed card & overdue tint |
| `ColorInfo` | `#2563EB` | Card payment / info badge border |
| `ColorReserved` | `#8B5CF6` | Reserved (`Bron`) indicator |
| `ColorReservedTint` | `#2A1B4E` | Reserved card background tint |
| `ColorReservedText` | `#DDD6FE` | Reserved status text |
| `ColorShadow` | `#000000` | Modal, toast, and lock-card elevation shadow |

### 1.2 Verified WCAG 2.1 Contrast Ratios
| Foreground / Background Pair | Colors | Contrast | Grade |
|---|---|---:|---|
| `TextPrimary` on `Bg` | `#F8FAFC` / `#09100C` | 18.40:1 | AAA |
| `TextPrimary` on `Surface` | `#F8FAFC` / `#111D17` | 16.56:1 | AAA |
| `TextPrimary` on `SurfaceElevated` | `#F8FAFC` / `#182820` | 14.72:1 | AAA |
| `TextSecondary` on `Surface` | `#94A3B8` / `#111D17` | 6.76:1 | AA |
| `TextMuted` on `SurfaceElevated` | `#8494A7` / `#182820` | 4.97:1 | AA |
| `TextPrimary` on `Primary` | `#F8FAFC` / `#0D6B4E` | 6.21:1 | AA |
| `PrimaryBright` on `PrimaryTint` | `#10B981` / `#063628` | 5.29:1 | AA |
| `AmberBright` on `AmberTintSoft` | `#F59E0B` / `#36200D` | 7.14:1 | AAA |
| `Bg` on `Amber` (Gold CTA) | `#09100C` / `#D97706` | 6.04:1 | AA |
| `TextOnError` on `Error` (Danger CTA) | `#FFFFFF` / `#E11D48` | 4.70:1 | AA |
| `ErrorBright` on `ErrorTintSoft` | `#FB7185` / `#36121C` | 6.19:1 | AA |
| `ReservedText` on `ReservedTint` | `#DDD6FE` / `#2A1B4E` | 11.08:1 | AAA |
| `TextPrimary` on `Info` | `#F8FAFC` / `#2563EB` | 4.94:1 | AA |

### 1.3 Brand Motifs & Geometry
- **Girih Lattice (`BrushGirihLattice`)**: Geometric tile pattern rendered at `3.5%` opacity behind the left rail logo plate and lock overlay card.
- **Brand Monogram (`DrawingBrandMonogram`)**: Rounded `#0D6B4E` square with `#10B981` stroke, geometric `"D"`, and saffron `#F59E0B` status dot (`App.ico` multi-frame 16/32/48/256 px PNG-encoded ICO and `Splash.png`).
- **Radii & Spacing (`4/8` grid)**: `RadiusXs=6`, `RadiusSm=10`, `RadiusMd=14`, `RadiusLg=18`, `RadiusXl=24`, `RadiusFull=16`; spacing tokens `2..40`.
- **Motion**: `DurationPress=90ms`, `DurationHover=140ms`, `DurationModal=220ms` (`EaseOut` CubicEase).

---

## 2. Typography (`Resources/Theme/Typography.xaml`)

- **Bundled Font**: Five weights of `Inter` (`Regular`, `Medium`, `SemiBold`, `Bold`, `ExtraBold`) embedded under `Resources/Fonts/*.ttf`.
- **Glyph Verification**: `FontHelper.VerifyBundledFontGlyphs()` validates Uzbek okina (`U+02BB`) glyph availability at startup.
- **Scale & Styles**:
  - `TextCaption` / `TextCaptionMuted`: `13px`
  - `TextLabel` / `TextTimer` (`Tabular`): `14px` SemiBold
  - `TextBody` / `TextBodyBold`: `16px`
  - `TextAmount` (`Tabular`): `18px` SemiBold
  - `TextTitle`: `20px` Bold
  - `TextSection`: `24px` ExtraBold (`TextAmountHero` amber variant)
  - `TextKpi` (`Tabular`): `32px` Bold
  - `TextGrandTotal` (`Tabular`): `40px` ExtraBold (`BrushPrimaryBright`)

---

## 3. Monoline Iconography (`Resources/Theme/Icons.xaml` & `Controls/Icon.cs`)

Zero raster emojis exist anywhere in the desktop UI (`Models/PosModels.cs` default strings and `Services/EscPosPrinterService.cs` ESC/POS print output remain untouched).  
36 vector `StreamGeometry` paths normalized to `24×24` (`StrokeThickness=1.75`, rounded caps/joins) cover navigation (`IconTables`, `IconQuickSale`, `IconStop`, `IconOnline`, `IconReport`, `IconSettings`), system actions (`IconLock`, `IconUnlock`, `IconUser`, `IconTag`, `IconCard`, `IconCash`, `IconSplit`, `IconPrinter`, `IconWifi`, `IconWifiOff`, `IconClock`, `IconSearch`, `IconPlus`, `IconMinus`, `IconTrash`, `IconEdit`, `IconReceipt`, `IconSendToKitchen`, `IconCheck`, `IconClose`, `IconAlert`, `IconRefresh`, `IconFullscreen`, `IconChevronDown`, `IconChevronRight`), and kitchen departments (`IconGrill`, `IconChef`, `IconBowl`, `IconBurger`, `IconCoffee`).

---

## 4. Shared Component Catalog (`Controls/` & `Resources/Theme/Controls.xaml`)

All interactive controls enforce `MinHeight >= 48px`, `Stylus.IsTapFeedbackEnabled="False"`, `Stylus.IsPressAndHoldEnabled="False"`, `Stylus.IsFlicksEnabled="False"`, `Stylus.IsTouchFeedbackEnabled="False"`, and `2px` `#F59E0B` (`BrushFocusRing`) keyboard focus visuals.

- **Primitives**: `PrimaryButton`, `SecondaryButton`, `GhostButton`, `DangerButton`, `GoldButton`, `IconButton`, `PayButton` (`MinHeight=72`), `ChipToggle`, `SegmentedItem`, `ToggleSwitch`, `KeycapBadge`, `TextBox`, `ComboBox`.
- **Chrome & Feedback**:
  - `DialogChrome` (`ContentControl` style with backdrop dim, `S=480`, `M=640`, `L=960×640`, ESC/close wiring via `Utils/Dialogs.cs`)
  - `Field` (`ContentControl` style with label, error/helper message switching)
  - `ToastHost` & `Toast` helper (top/bottom non-blocking banner with optional undo CTA, zero `MessageBox`)
  - `ConnectionPill`, `StatusPill` (7 semantic tones), `EmptyState`, `SectionHeader`
  - `SkeletonBox` (shimmer animation bound strictly to `IsVisible == True` so collapsed skeletons consume zero CPU/GPU)
- **Domain Controls**:
  - `TableCard` (`TableCardVM`): 4 distinct visual states (`Boʻsh`, `Band`, `Hisob berildi`, `Bron`), urgency elapsed timer, quick `Hisob`/`Toʻlov` actions, single-card updates
  - `ProductTile` (`ProductTileVM`): 16:9 image/department tint placeholder, 2-line title trim, tabular price, saffron cart count badge, muted `Stop-list` badge
  - `CartLine` (`CartLineVM`): 72px+ row, amber `13px` kitchen modifier notes, 48×48 edit-note button, `Stepper` with quantity bump feedback
  - `OnlineOrderCard` (`OnlineOrderCardVM`): order #, channel pill, urgency timer (`>=3m` amber, `>=7m` red), up to 3 preview lines + `+N yana`, primary accept CTA
  - `PrinterCard` (`PrinterCardVM`): department icon plate, online/offline indicator dot, 226px centered IP:Port input (`192.168.1.100:9100`), test-print trigger
  - `KpiCard`: metric label, 32px tabular KPI value, subtitle, semantic icon

---

## 5. Responsive Breakpoints & Viewport Matrix

Validated across `1366×768`, `1600×900`, `1920×1080`, `2560×1440`, plus Windows scaling effective viewports `1536×864` (`1920×1080 @ 125%`) and `1280×720` (`1920×1080 @ 150%`, minimum supported `MinWidth=1280 MinHeight=720`):

| Metric | `< 1366px` | `1366–1549px` | `1550–1799px` | `1800–2199px` | `>= 2200px` |
|---|---:|---:|---:|---:|---:|
| Left Nav Rail | 84px | 88px | 88px | 88px | 88px |
| Right Cart Rail | 380px | 380px | 380–440px (`>=1600`) | 440px | 440px |
| Tables Grid Columns | 3 | 3 | 4 | 4 | 5 |
| Menu Product Columns | 3 | 3 | 4 | 5 | 6 |
| Stop-list Columns | 2 | 2 | 3 | 3 | 4 |

---

## 6. Global Keyboard Shortcuts & Lock Safety

- `F1`: Stollar (Tables map)
- `F2`: Tezkor savdo (Quick POS)
- `F4`: Chegirma dialogi (when `Tezkor savdo` active)
- `F5`: Onlayn buyurtmalarni yangilash
- `F11`: Kiosk / Fullscreen rejimi
- `F12`: Toʻlov oynasi (`PaymentDialog`)
- All shortcut keys are suppressed while `LockOverlay` is visible so accidental input cannot execute behind the lock screen.

---

## 7. Architectural Decisions & Non-Blocking Follow-Ups

1. **`ContentControl` vs `UserControl` for Container Components (`DialogChrome`, `Field`)**: Converted wrapper controls containing child `[ContentProperty]` slots to templated `ContentControl` styles in `Controls.xaml` to prevent WPF `MC3093` XAML NameScope collisions when consumers assign `x:Name` to slotted inputs.
2. **Lazy Container Binding Guard on Settings**: `PrinterCard` IP `TextChanged`, `ServerUrlBox`, and `ServiceFeeTypeCombo` suppress dirty state transitions when `IsLoaded == false` or without active user focus (`IsKeyboardFocusWithin`), preventing initial tab-switch template generation from falsely triggering the sticky Save bar.
3. **Detached Offscreen Snapshot Rendering**: `SnapshotRenderer` detaches `window.Content` into an exact-dimension offscreen `Border` so `1920×1080`, `2560×1440`, and taller gallery renders are never clamped by host monitor working area.
4. **Targeted Private Fix in `PosModels.Order.RecalculateTotals()`**: Fixed internal backing-field assignment (`_discountAmount` + explicit `OnPropertyChanged(nameof(DiscountAmount))`) inside `RecalculateTotals()` without modifying any public API signature, database schema, sync engine, or print output.
5. **Follow-ups for Future Backend/Auth Iterations**:
   - **Real PIN Unlock**: Current `LockOverlay` provides instant cashier screen privacy lock/unlock without PIN validation; real PIN verification belongs in a future auth endpoint task.
   - **Real Product Photography**: `ProductTile` renders polished department-tinted placeholders when `Product.ImageUrl` is empty; once menu photography URLs are populated by the backend, tiles display them with clean rounded clipping.
   - **Printer Live Ping**: `PrinterCard.IsOnline` currently reads `Department.IsOnline` from bootstrap/demo metadata; periodic TCP `:9100` port health probing in `SyncEngine` can make those dots live in production.

---

## 8. Commands & Verification

```powershell
# Component Gallery preview
dotnet run --project pos_desktop_csharp/DilkashPos.csproj -c Release -- --gallery

# Offline interactive Demo mode
dotnet run --project pos_desktop_csharp/DilkashPos.csproj -c Release -- --demo

# Automated multi-resolution & DPI snapshot capture
dotnet run --project pos_desktop_csharp/DilkashPos.csproj -c Release -- --demo --snapshots docs/design/snapshots/after

# Release build & win-x64 publish
dotnet build -c Release pos_desktop_csharp/DilkashPos.csproj
dotnet publish pos_desktop_csharp/DilkashPos.csproj -c Release -r win-x64 --no-self-contained
```
