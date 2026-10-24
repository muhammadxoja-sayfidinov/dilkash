# Dilkash Kuryer Ilovasi (Courier App)

Professional kuryerlar uchun buyurtmalarni qabul qilish, marshrut chizish va yetkazib berish ilovasi (Yandex Pro va Wolt Courier standartlari darajasida).

---

## 🛵 Asosiy Imkoniyatlar (Features)

1. **Smena va Navbatchilik Boshqaruvi (Duty Toggle):**
   - Bir tugma bilan "Smenada / Faol" yoki "Dam olishda" holatiga oʻtish.
   - Smena davomidagi yetkazilgan buyurtmalar soni va kesh tushumi statistikasi.
   - Tezkor server IP sozlamasi (`10.40.4.94:8000` Wi-Fi va `127.0.0.1:8000` USB).

2. **Yangi Buyurtma Ogohlantirishi (Incoming Order Alert):**
   - Yangi buyurtma tushganda 30 soniyalik teskari hisob (countdown timer) bilan chiquvchi modal oyna.
   - Buyurtma manzili, taomlar soni, umumiy summasi va kuryer haqqini darhol koʻrsatish.
   - Qabul qilish yoki rad etish imkoniyati.

3. **Buyurtmalar Hovuzi va Qabul Qilish (Orders Pool):**
   - "Faol buyurtmalar" (kuryerga biriktirilgan) va "Ochiq buyurtmalar" (erkin buyurtmalar hovuzi) yorliqlari.
   - Buyurtma raqami boʻyicha qidirib topish va oʻziga biriktirib olish (`Claim order`) funksiyasi.

4. **Bosqichma-bosqich Yetkazish Jarayoni (Active Delivery Flow):**
   - **1-bosqich: Restorandan olib ketish** (`Qabul qilindi` -> `Oshxonada tayyor`).
   - **2-bosqich: Mijoz tomon yoʻlga chiqish** (`Yoʻlda`).
   - **3-bosqich: Yetkazib berildi va hisob yopildi** (`Yetkazildi`).
   - ⚡ **Taktil surish tugmasi (`DilkashSwipeButton`):** Velosiped yoki mototsiklda qoʻlqop bilan harakatlanayotganda notoʻgʻri bosib yuborishning oldini oluvchi xavfsiz surib tasdiqlash mexanizmi.

5. **Interaktiv Xarita va Navigatsiya (Map & Route Engine):**
   - Sof Dart asosidagi **CartoDB Voyager** xaritasi (hech qanday tashqi Google Maps kalitisiz, billing yoki FFI xatolarisiz ishlaydi).
   - Restorandan mijozgacha boʻlgan marshrut polilayni, masofa (km) va taxminiy yetib borish vaqti (ETA).
   - Butun ekranni egallovchi toʻliq xarita rejimi (Fullscreen toggle).
   - Bitta bosishda **Yandex Navigator** (`yandexnavi://`) yoki **Google Maps** ilovasida ovozli yoʻl koʻrsatuvchi marshrut ochish.
   - Mijozga bir bosishda qoʻngʻiroq qilish tugmasi (`tel:+998...`).

6. **Kuryer Daromadi va Hisoboti (Earnings Dashboard):**
   - Bugungi yetkazib berishlar soni.
   - Qoʻlga olingan naqd pul balansi.
   - Mijozlar qoldirgan choychaqalar hisobi.

---

## 🛠 Arxitektura va Tuzilishi (Project Structure)

```
courier_app_flutter/
├── lib/
│   ├── main.dart                          # Ilova kirish nuqtasi va mavzu sozlamalari
│   ├── models/
│   │   ├── courier_order.dart             # Kuryer buyurtma modeli va parsirovkasi
│   │   ├── staff_user.dart                # Xodim sessiyasi modeli
│   │   └── waiter_models.dart             # Zaldagi xizmat modellari
│   ├── screens/
│   │   ├── staff_login_screen.dart        # PIN orqali tezkor kirish va IP almashtirgich
│   │   ├── courier_orders_screen.dart     # Smena boshqaruvi, hovuz va buyurtmalar ro'yxati
│   │   ├── courier_delivery_screen.dart   # Navigatsiya xaritasi, marshrut va surish tugmasi
│   │   └── waiter_floor_screen.dart       # Ofitsiant stollar rejasi
│   ├── services/
│   │   ├── courier_api_service.dart       # Kuryer buyurtmalari va GPS sinxronizatsiyasi
│   │   └── staff_api_service.dart         # Xodimlar autentifikatsiyasi
│   ├── theme/
│   │   └── staff_theme.dart               # Dilkash dizayn tizimi ko'prigi
│   └── widgets/
│       └── order_stations_sheet.dart      # Sexlar bo'yicha buyurtma tafsilotlari
└── test/
    ├── courier_test.dart                  # Kuryer modeli va status o'zgarishlari testlari
    └── widget_test.dart                   # Ilova tutun va komponent testlari
```

---

## 🚀 Qanday Ishga Tushiriladi (How to Run)

### 1. Bogʻliqliklarni oʻrnatish:
```bash
flutter pub get
```

### 2. Tahlil va testlarni tekshirish:
```bash
flutter analyze
flutter test
```

### 3. Emulyatorda yoki Qurilmada ishga tushirish:
```bash
flutter run
```

> **Kuryer PIN kodlari (Backend orqali):**
> - Kuryer Bobur: PIN `7788`
> - Kuryer Jasur: PIN `1122`
