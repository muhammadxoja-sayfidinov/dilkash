# Dilkash Dizayn Tizimi (Shared Design System)

Dilkash restorani ekotizimidagi barcha Flutter ilovalari (Mijoz va Kuryer) uchun yagona, professional dizayn tizimi to'plami.

---

## 🎨 Dizayn Tokenlari (Design Tokens)

1. **Ranglar Palitrasi (`DilkashColors`):**
   - **Asosiy (Primary):** O'zbek mehmondo'stligi va toza tabiiy taomlarni aks ettiruvchi Zangori Zumrad (`Emerald #0D6B4E`, silliq 50..900 gradatsiyasi).
   - **Urgʻu (Accent):** Tandir noni va toʻy oshi jilosi boʻlgan Zaʼfaron / Qahrabo (`Saffron Amber #D97706`).
   - **Neytral yuzalar:** Toza engil fon (`#F8FAF8`), qorongʻu chuqur fon (`#070D0A`), kartochkalar va chegaralar.
   - **Semantik ranglar:** Muvaffaqiyat (Success), Ogohlantirish (Warning), Xato (Error), Maʼlumot (Info).

2. **Tipografiya (`DilkashTypography`):**
   - Toʻliq lotin va kirill alifbosi qoʻllab-quvvatlovi.
   - Oʻzbek tilidagi `oʻ` va `gʻ` harflari xalqaro tipografik standartdagi U+02BB modifikator belgisi bilan toʻgʻri formatlangan.

3. **Masshtab va Oʻlchamlar:**
   - **Panjara (Spacing):** 4pt va 8pt qatʼiy panjara tizimi (`DilkashSpacing`).
   - **Burchak radiuslari (Radii):** 4, 8, 12, 16, 20, 24 va pill (`DilkashRadii`).
   - **Soyalar (Shadows):** Silliq, sunʼiy koʻrinmaydigan tabiiy yorugʻlik soyalari (`DilkashShadows`).

---

## 🧩 Qayta Ishlatiluvchi Komponentlar (Components)

- **`DilkashButton`:** Barcha holatlarga ega (normal, hover, pressed, disabled, loading). Barcha tugmalar kamida 48x48dp bosish maydoniga ega.
- **`DilkashTextField`:** Telefon raqami formatori (+998), qidiruv paneli, PIN va maxsus belgilar.
- **`DilkashDishCard` & `DilkashHorizontalDishCard`:** Restoran taomlari kartochkalari, maxsus badge va tezkor savatchaga qoʻshish.
- **`DilkashQuantityStepper`:** Haptik hisoblagich (+ / -).
- **`DilkashStatusStepper`:** 4 bosqichli buyurtma holati indikatori.
- **`DilkashSwipeButton`:** Kuryerlar uchun taktil surib tasdiqlash tugmasi.
- **`DilkashBottomSheet`:** Zamonaviy modal oyna.
- **`DilkashSkeleton`:** Shimmer animatsiyali yuklanish holatlari.
- **`DilkashEmptyState` & `DilkashErrorState`:** Boʻsh va xatolik holatlari.
- **`UzbekFormatters`:** Valyuta (`45 000 soʻm`), telefon raqami (`+998 90 123 45 67`), masofa (`1.4 km`).

---

## 🧪 Sinovlar (Tests)

Ushbu toʻplam toʻliq birlik (unit) va vidjet testlari bilan qoplangan:
```bash
flutter test
flutter analyze
```
Zero errors, zero warnings.
