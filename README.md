# Dilkash Restaurant Ecosystem (Mijoz & Kuryer Ilovalari)

Ushbu repozitoriy Dilkash restorani uchun yaratilgan production-darajasidagi to'liq ekotizimni o'z ichiga oladi:
1. **Mijoz Ilovasi (`customer_app_flutter`):** Menyu koʻrish, porsiya va qoʻshimchalarni tanlash, xaritada manzil belgilash, promokodlar, Payme/Click/Naqd toʻlov, jonli kuryer harakatini kuzatish.
2. **Kuryer Ilovasi (`courier_app_flutter`):** Smena boshqaruvi, yangi buyurtmalar 30s ogohlantirishi, ochiq buyurtmalar hovuzi, CartoDB Voyager interaktiv xaritasi va marshrut, taktil surib tasdiqlash (`DilkashSwipeButton`), bir bosishda Yandex Navigator/Google Maps ochish.
3. **Umumiy Dizayn Tizimi (`packages/dilkash_design_system`):** Zamonaviy ranglar, 4/8pt panjara, toza lotin tipografiyasi (`oʻ`, `gʻ`), barcha vidjetlar, formatorlar.
4. **Backend REST API & POS (`restaurant_system`):** Django POS, oshxona boshqaruvi, kassa, ESC/POS termal printerlar va toʻlov tizimlari integratsiyasi.

---

## 📂 Loyiha Tuzilmasi (Repository Structure)

```
├── AUDIT.md                          # Boshlang'ich tahlil va muammolar ro'yxati
├── DECISIONS.md                      # Arxitekturaviy va dizayn qarorlari
├── PLAN.md                           # 5 bosqichli reja va bajarilish holati
├── packages/
│   └── dilkash_design_system/        # Umumiy dizayn tizimi (tokens, components, formatters)
├── customer_app_flutter/             # Wolt/Uber Eats darajasidagi Mijoz ilovasi
├── courier_app_flutter/              # Yandex Pro/Wolt Courier darajasidagi Kuryer ilovasi
└── restaurant_system/                # Backend REST API, POS, Kassir va KDS
```

---

## ⚡ Tezkor Ishga Tushirish (Quick Start)

### 1. Backend Serverni Ishga Tushirish:
```bash
python3 start.py
```
*(Server avtomatik ravishda `0.0.0.0:8000` portida ishga tushadi va USB ulangan Android qurilmalar uchun `adb reverse tcp:8000 tcp:8000` ni sozlaydi).*

### 2. Mijoz Ilovasini Ishga Tushirish:
```bash
cd customer_app_flutter
flutter run
```

### 3. Kuryer Ilovasini Ishga Tushirish:
```bash
cd courier_app_flutter
flutter run
```

---

## 🛡 Sifat Standartlari & Testlar (Quality Assurance)

- **`flutter analyze`:** Barcha 3 paketda **0 ta xato, 0 ta ogohlantirish (No issues found!)**
- **Flutter Birlik va Vidjet Testlari:** Barcha testlar muvaffaqiyatli oʻtgan.
- **Backend QA Testlari:** `restaurant_system/qa_engine_test.py` dagi **89 / 89 testlar 100% muvaffaqiyatli oʻtgan**.
