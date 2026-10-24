# Dilkash Mijoz Ilovasi (Customer App)

Production-grade oziq-ovqat yetkazib berish va olib ketish ilovasi (Wolt, Yandex Eda va Uber Eats darajasidagi UI/UX).

---

## 📱 Asosiy Imkoniyatlar (Features)

1. **Wolt-darajasidagi Bosh Sahifa (Editorial Feed):**
   - Zamonaviy qidiruv satri va restoran reyting nishoni (`⭐ 4.9 • 20-30 daqiqa`).
   - Restoran maxsus takliflari karuseli ("Bugungi taklif", chegirmalar).
   - "Mashhur taomlar" gorizontal slayderi.
   - Yopishqoq (sticky) toifalar paneli va taomlar soni hisoblagichi.
   - 2 ustunli toza menyu setkasi (Food Photography, narxlar, porsiya va tezkor savatchaga qoʻshish).

2. **Taom Tafsilotlari & Moslashtirish (Dish Customization Sheet):**
   - Porsiya tanlash: Standard, 1.5 porsiya (+40%), 2 porsiya (+80%).
   - Qoʻshimchalar: Achichuk, Suzma, Tuxum, Qazi, Non (+5 000 soʻmdan).
   - Oshpaz uchun maxsus istaklar (izoh).
   - Jonli umumiy narx hisoblash va haptik savatchaga qoʻshish animatsiyasi.

3. **Savatcha va Buyurtmani Rasmiylashtirish (Cart & Checkout):**
   - "Yetkazib berish" (Dastavka) va "Olib ketish" (Self-pickup) rejimlari.
   - Interaktiv CartoDB Voyager xaritasi orqali manzil tanlash va OpenStreetMap Nominatim orqali avtomatik manzilni aniqlash (Reverse Geocoding).
   - Promokod dvigateli: `DILKASH5` (5% chegirma), `YANGI` (10 000 soʻm chegirma), `MAZA` (7 000 soʻm chegirma).
   - Kuryer uchun ixtiyoriy choychaqa tugmalari (0 soʻm, 5 000 soʻm, 10 000 soʻm, 15 000 soʻm).
   - Toʻlov usullari: **Payme**, **Click**, va **Naqd pul**.

4. **Jonli Buyurtma Kuzatish (Live Order Tracking):**
   - 4 bosqichli status stepperi: Qabul qilindi -> Oshxonada -> Kuryer yoʻlda -> Yetkazildi.
   - Jonli interaktiv xarita: Restoran nuqtasi, Mijoz manzili va harakatlanayotgan kuryer mototsikl belgisi.
   - Marshrut polilayni va taxminiy yetib borish vaqti (ETA).
   - Kuryerga toʻgʻridan-toʻgʻri telefon qilish tugmasi (`tel:+998...`).

5. **Profil va Sozlamalar:**
   - Keshbek balansi va bonus hisobi.
   - Buyurtmalar tarixi va bitta bosishda qayta buyurtma berish (`Reorder`).
   - Xizmat sifatini 5 yulduzli baholash va sharh qoldirish modal oynasi.
   - Tungi va kunduzgi rejim (Dark / Light Theme).

---

## 🛠 Arxitektura va Tuzilishi (Project Structure)

```
customer_app_flutter/
├── lib/
│   ├── main.dart                      # Ilova kirish nuqtasi va Provider arxitekturasi
│   ├── models/
│   │   ├── dish.dart                  # Taom modeli (porsiyalar, qo'shimchalar, toifalar)
│   │   └── order.dart                 # Buyurtma holati va tafsilotlari
│   ├── screens/
│   │   ├── onboarding_screen.dart     # Xush kelibsiz slayderi
│   │   ├── auth_screen.dart           # SMS OTP kirish va Server IP almashtirgich
│   │   ├── main_navigation_shell.dart # Asosiy pastki navigatsiya
│   │   ├── home_screen.dart           # Wolt uslubidagi bosh sahifa
│   │   ├── dish_detail_sheet.dart     # Taom sozlamalari pastki varag'i
│   │   ├── cart_screen.dart           # Savatcha, xarita manzil tanlash, promokodlar
│   │   ├── order_tracking_screen.dart # Jonli xarita va buyurtma kuzatuvi
│   │   ├── my_orders_screen.dart      # Buyurtmalar tarixi va qayta buyurtma
│   │   ├── account_screen.dart        # Profil, keshbek, mavzu tanlash
│   │   ├── search_screen.dart         # Qidiruv ekrani
│   │   └── tip_review_modal.dart      # Choychaqa va sharh oynasi
│   ├── services/
│   │   ├── api_service.dart           # REST API mijozi (LAN IP avtomatik aniqlash bilan)
│   │   ├── auth_provider.dart         # Foydalanuvchi sessiyasi va profili
│   │   ├── cart_provider.dart         # Savatcha, porsiyalar va chegirma hisoblagichi
│   │   └── theme_provider.dart        # Tungi/kunduzgi mavzu holati
│   └── theme/
│       └── app_theme.dart             # Dilkash dizayn tizimi ko'prigi
└── test/
    ├── cart_test.dart                 # Savatcha narxlari va promokodlar unit testlari
    └── widget_test.dart               # Ilova tutun va komponent testlari
```

---

## 🚀 Qanday Ishga Tushiriladi (How to Run)

### 1. Bogʻliqliklarni oʻrnatish:
```bash
flutter pub get
```

### 2. Statik tahlil va testlarni tekshirish:
```bash
flutter analyze
flutter test
```

### 3. Emulyatorda yoki Haqiqiy Qurilmada ishga tushirish:
```bash
flutter run
```

> **Qurilma bilan ishlash boʻyicha eslatma:**
> Telefoningiz kompyuteringiz bilan bir xil Wi-Fi tarmogʻida boʻlsa, tizimga kirish oynasidagi server IP sozlamasidan `10.40.4.94:8000 (Wi-Fi)` yoki USB orqali ulangan boʻlsa `127.0.0.1:8000 (USB)` tugmasini bosish kifoya.
