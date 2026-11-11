# Dilkash POS — Design System & UI Specification

**Branch:** `design/pos-redesign`  
**Stack:** WPF (.NET 8 Windows, `net8.0-windows`, zero third-party UI packages)  
**Product Metadata:** `Dilkash POS` v`2.0.0` (`Dilkash Milliy Taomlar`)  
**Language & Formatting:** Uzbek Latin using typographic okina `ʻ` (`U+02BB`), 24h clock, tabular numbers, `MoneyFormatter` (`\u00A0so\u02BBm`, non-breaking space separators).

---

## 1. Visual Foundations & Dual Eye-Friendly Themes

All theme colors live in paired dictionaries swapped live via `Utils/ThemeManager.cs` (`Kun` / `Tun` toggle in the Top Bar) and consumed via `{DynamicResource}` with frozen `SolidColorBrush` resources (`po:Freeze="True"`).

### 1.1 Daylight Light Palette — Default (`Resources/Theme/Tokens.Light.xaml`)
Designed for long daytime restaurant shifts without screen glare or eye fatigue:

| Token | Light Hex | Dark Hex (`Tokens.Dark.xaml`) | Role |
|---|---|---|---|
| `ColorBg` | `#F4F5F7` | `#13161B` | Primary app canvas & shell backdrop |
| `ColorSurface` | `#FFFFFF` | `#1B1F26` | Cards, panels, top bar, nav rail |
| `ColorSurfaceElevated` | `#EDF0F5` | `#242933` | Modals, secondary buttons, elevated containers |
| `ColorInput` | `#FFFFFF` | `#15181E` | Editable inputs (`TextBox`, `ComboBox`, `SearchBox`) |
| `ColorBorder` | `#D8DFE7` | `#2E3542` | Default strokes & card dividers |
| `ColorBorderSubtle` | `#E7ECF1` | `#242A35` | Hairline separators |
| `ColorBorderHover` | `#B3BECB` | `#414B5C` | Hover stroke elevation |
| `ColorTextPrimary` | `#161E27` | `#F1F5F9` | Headings, body text, amounts |
| `ColorTextSecondary` | `#475569` | `#A3B1C2` | Supporting text & labels |
| `ColorTextMuted` | `#5A6878` | `#8A99AD` | Micro-labels & metadata |
| `ColorTextOnPrimary` | `#FFFFFF` | `#FFFFFF` | Ink on solid emerald fills |
| `ColorTextOnAmber` | `#FFFFFF` | `#FFFFFF` | Ink on solid amber CTAs & badges |
| `ColorTextOnError` | `#FFFFFF` | `#FFFFFF` | Ink on solid destructive fills |
| `ColorPrimary` | `#0E7C5B` | `#0E7C5B` | Calm emerald primary action fill |
| `ColorPrimaryBright` | `#0A664A` | `#34D399` | Readable emerald text/borders on theme surfaces |
| `ColorPrimaryPressed` | `#095D44` | `#0A6147` | Pressed CTA state |
| `ColorPrimaryTint` | `#E7F5EF` | `#132B24` | Soft occupied/active card tint |
| `ColorAmber` | `#B45309` | `#B45309` | Warm amber secondary action & badge fill |
| `ColorAmberBright` | `#9A4806` | `#FBBF24` | Readable amber ink for warnings & notes |
| `ColorAmberTintSoft` | `#FEF6E6` | `#2B2214` | Pre-chek / warning card surface |
| `ColorSuccess` | `#0E7C5B` | `#0E7C5B` | Success indicator |
| `ColorError` | `#DC2626` | `#DC2626` | Destructive button fill |
| `ColorErrorBright` | `#B91C1C` | `#FCA5A5` | Error ink & stop-list highlight |
| `ColorErrorTintSoft` | `#FDECEC` | `#31181C` | Stop-listed card tint |
| `ColorInfo` | `#2563EB` | `#3B82F6` | Info/card payment accents |
| `ColorReserved` | `#7C3AED` | `#8B5CF6` | Reserved (`Bron`) dashed outline |
| `ColorReservedTint` | `#F4EEFF` | `#251E3A` | Reserved card background tint |
| `ColorReservedText` | `#5B21B6` | `#DDD6FE` | Reserved status text |
| `ColorBrandDot` | `#F59E0B` | `#F59E0B` | Monogram saffron dot |

### 1.2 Verified WCAG 2.1 Contrast Ratios (Both Themes >= 4.83:1 AA/AAA)
| Pair | Light Ratio | Dark Ratio |
|---|---:|---:|
| `TextPrimary` on `Bg` | 15.41:1 (AAA) | 16.55:1 (AAA) |
| `TextPrimary` on `Surface` | 16.81:1 (AAA) | 15.09:1 (AAA) |
| `TextSecondary` on `Surface` | 7.58:1 (AAA) | 7.58:1 (AAA) |
| `TextMuted` on `SurfaceElevated` | 4.99:1 (AA) | 5.03:1 (AA) |
| `TextOnPrimary` on `Primary` | 5.18:1 (AA) | 5.18:1 (AA) |
| `PrimaryBright` on `PrimaryTint` | 6.21:1 (AA) | 7.81:1 (AAA) |
| `AmberBright` on `AmberTintSoft` | 5.91:1 (AA) | 9.38:1 (AAA) |
| `TextOnAmber` on `Amber` | 5.02:1 (AA) | 5.02:1 (AA) |
| `TextOnError` on `Error` | 4.83:1 (AA) | 4.83:1 (AA) |
| `ErrorBright` on `ErrorTintSoft` | 5.66:1 (AA) | 8.66:1 (AAA) |
| `ReservedText` on `ReservedTint` | 7.92:1 (AAA) | 11.41:1 (AAA) |

### 1.3 Brand Motifs & Geometry (`Resources/Theme/Tokens.xaml`)
- **Girih Lattice (`BrushGirihLattice`)**: `4%` Light / `2.8%` Dark subtle geometric motif behind the logo plate, empty states, and lock card.
- **Brand Monogram (`DrawingBrandMonogram`)**: Rounded `#0E7C5B` square, white `"D"` (`BrushTextOnPrimary`), and `#F59E0B` status dot (`App.ico` 16/32/48/256 px PNG frames and `Splash.png` daylight splash).
- **Radii & Spacing (`4/8` grid)**: `RadiusXs=6`, `RadiusSm=10`, `RadiusMd=12`, `RadiusLg=16`, `RadiusXl=20`, `RadiusFull=16`; spacing tokens `2..40`.
- **Motion**: `DurationPress=90ms`, `DurationHover=140ms`, `DurationModal=220ms` (`EaseOut` CubicEase).

---

## 2. Typography & ClearType Rendering (`Resources/Theme/Typography.xaml`)

- **Primary Font Stack**: `Segoe UI Variable Text, Segoe UI Variable, Segoe UI, pack://application:,,,/Resources/Fonts/#Inter`
- **Crisp Windows Rendering**: `UseLayoutRounding="True"`, `SnapsToDevicePixels="True"`, `TextOptions.TextFormattingMode="Display"`, and `TextOptions.TextRenderingMode="ClearType"` across all windows and styles.
- **Foreground Inheritance**: Implicit `TextBlock` omits hardcoded `Foreground`, allowing `TextElement.Foreground` inheritance from containers (`MainWindow`, `DialogChrome`) and buttons (`BrushTextOnPrimary`, `BrushTextOnAmber`, `BrushTextOnError`).
- **Balanced Scale**:
  - `TextCaption` / `TextCaptionMuted`: `12px`
  - `TextLabel` / `TextTimer` (`Tabular`): `13px` SemiBold
  - `TextBody` / `TextBodyBold`: `14px` (Regular / SemiBold)
  - `TextAmount` (`Tabular`): `15px` SemiBold (`TextAmountHero` `20px` SemiBold)
  - `TextTitle`: `17px` SemiBold
  - `TextSection`: `20px` Bold
  - `TextKpi` (`Tabular`): `24px` Bold
  - `TextGrandTotal` (`Tabular`): `28px` Bold

---

## 3. Monoline Iconography (`Resources/Theme/Icons.xaml` & `Controls/Icon.cs`)

Zero raster emojis exist anywhere in the desktop UI (`Models/PosModels.cs` and `Services/EscPosPrinterService.cs` remain untouched).  
38 vector `StreamGeometry` paths normalized to `24×24` (`StrokeThickness=1.75`, rounded caps/joins) include all navigation, action, kitchen department, and theme toggle (`IconSun`, `IconMoon`) icons.

---

## 4. Shared Component Catalog (`Controls/` & `Resources/Theme/Controls.xaml`)

- Interactive buttons maintain touch-friendly sizing (`>= 44–48px`), `Stylus.IsTapFeedbackEnabled="False"`, `Stylus.IsPressAndHoldEnabled="False"`, `Stylus.IsFlicksEnabled="False"`, `Stylus.IsTouchFeedbackEnabled="False"`, and `2px` `BrushFocusRing` keyboard focus visuals.
- **Chrome & Feedback**: `DialogChrome` (`ContentControl`), `Field` (`ContentControl`), `ToastHost`/`Toast`, `ConnectionPill`, `StatusPill`, `EmptyState`, `SectionHeader`, `SkeletonBox` (`IsVisible == True` animation lifecycle).
- **Domain Controls**: `TableCard` (`146px` height, 4 visual states), `ProductTile` (`152px` height, `56px` media/tint band), `CartLine` (`64px` min height, compact `44px` `Stepper` & note actions), `OnlineOrderCard`, `PrinterCard` (`226px` centered IP field), `KpiCard`.

---

## 5. Responsive Breakpoints & Viewport Matrix

Validated across `1366×768`, `1600×900`, `1920×1080` (both Light & Calm Slate Dark), `2560×1440`, plus Windows scaling viewports `1536×864` (`1920×1080 @ 125%`) and `1280×720` (`1920×1080 @ 150%`, `MinWidth=1280 MinHeight=720`):

| Metric | `< 1500px` | `1500–1799px` | `1800–2199px` | `>= 2200px` |
|---|---:|---:|---:|---:|
| Left Nav Rail | 84px | 84px | 84px | 84px |
| Right Cart Rail (`>=1550px` wide) | 356px | 356–400px | 400px | 400px |
| Tables Grid Columns | 3 | 4 | 4 | 5 |
| Menu Product Columns | 3 | 4 | 5 | 6 |
| Stop-list Columns | 2 | 3 | 3 | 4 |

---

## 6. Global Keyboard Shortcuts & Lock Safety

- `F1`: Stollar · `F2`: Tezkor savdo · `F4`: Chegirma (`Tezkor savdo`) · `F5`: Onlayn buyurtmalarni yangilash · `F11`: Kiosk rejimi · `F12`: Toʻlov oynasi.
- All shortcut keys are suppressed while `LockOverlay` is active.

---

## 7. Architectural Decisions & Non-Blocking Follow-Ups

1. **Dual Runtime Resource Dictionaries (`ThemeManager`)**: Separating `Tokens.Light.xaml` (default) and `Tokens.Dark.xaml` from structural `Tokens.xaml` enables instant runtime switching (`Kun` / `Tun`) without restart.
2. **Ambient Foreground Inheritance (`TextBlock`)**: Omitting `Foreground` from the implicit `TextBlock` style prevents string `Content` inside `PrimaryButton`, `GoldButton`, `DangerButton`, and `SegmentedItem` from inheriting dark body text instead of `BrushTextOnPrimary` / `BrushTextOnAmber` / `BrushTextOnError`.
3. **Settings Dirty Guard**: `PrinterCard` IP `TextChanged` and Settings inputs verify `IsLoaded` and `IsKeyboardFocusWithin` so lazy tab generation never triggers a false unsaved banner.
4. **Targeted Private Fix in `PosModels.Order.RecalculateTotals()`**: Fixed internal backing-field assignment (`_discountAmount` + `OnPropertyChanged(nameof(DiscountAmount))`) without altering public APIs, schema, sync, or printer bytes.
5. **Follow-ups**: Backend PIN unlock verification on `LockOverlay`, menu photo URLs in `ProductTile`, and live TCP `:9100` port ping in `SyncEngine` for `PrinterCard.IsOnline`.

---

## 8. Commands & Verification

```powershell
# Component Gallery preview
dotnet run --project pos_desktop_csharp/DilkashPos.csproj -c Release -- --gallery

# Offline interactive Demo mode
dotnet run --project pos_desktop_csharp/DilkashPos.csproj -c Release -- --demo

# Automated multi-resolution, DPI & Dark/Light snapshot capture
dotnet run --project pos_desktop_csharp/DilkashPos.csproj -c Release -- --demo --snapshots docs/design/snapshots/after

# Release build & win-x64 publish
dotnet build -c Release pos_desktop_csharp/DilkashPos.csproj
dotnet publish pos_desktop_csharp/DilkashPos.csproj -c Release -r win-x64 --no-self-contained
```
