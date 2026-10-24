# Dilkash Restaurant Ecosystem (Mijoz & Yagona Xodimlar Ilovasi)

Ushbu repozitoriy Dilkash restorani uchun yaratilgan production-darajasidagi toʻliq ekotizimni oʻz ichiga oladi:
1. **Mijoz Ilovasi (`customer_app_flutter`):** Menyu koʻrish, porsiya va qoʻshimchalarni tanlash, xaritada manzil belgilash, promokodlar, Payme/Click/Naqd toʻlov, jonli kuryer harakatini kuzatish.
2. **Yagona Xodimlar Ilovasi (`courier_app_flutter`):** Kuryer va Ofitsiant rollarini birlashtirgan, bitta oshxona, bitta menyu va bitta zalga ega boʻlgan Dilkash restorani xodimlar ilovasi. PIN/telefon orqali kirish, server tasdiqlagan rollar, chiqmasdan rolni almashtirish (zero-logout switching), smena hisoblagichi, 6 bosqichli kuryerlik sikli, zallar va stollar boshqaruvi, hisobni boʻlish (split bill), va menejer PIN tasdigʻi.
3. **Umumiy Dizayn Tizimi (`packages/dilkash_design_system`):** Zamonaviy ranglar, 4/8pt panjara, toza lotin tipografiyasi (`oʻ`, `gʻ`), barcha vidjetlar, formatorlar.
4. **Backend REST API & POS (`restaurant_system`):** Django POS, oshxona boshqaruvi, kassa, ESC/POS termal printerlar va toʻlov tizimlari integratsiyasi.

---

## 📂 Loyiha Tuzilmasi (Repository Structure)

```
├── AUDIT.md                          # Tizim auditi va aniqlangan barcha kamchiliklar tahlili
├── DECISIONS.md                      # Arxitektura, dizayn va xavfsizlik qarorlari jurnali
├── packages/
│   └── dilkash_design_system/        # Umumiy dizayn tizimi (tokens, components, formatters)
├── customer_app_flutter/             # Wolt/Uber Eats darajasidagi Mijoz ilovasi
├── courier_app_flutter/              # Kuryer va Ofitsiant yagona xodimlar ilovasi
│   └── lib/
│       ├── core/                     # Arxitektura yadrosi
│       │   ├── auth/                 # Sessiya, biometriya va Auth Notifier
│       │   ├── audit/                # Muhim amallar auditi (AuditLogger)
│       │   ├── navigation/           # GoRouter va rolga asoslangan qoʻriqchilar
│       │   ├── network/              # StaffRepository interfeysi va MockStaffRepository
│       │   ├── shift/                # Smena modeli va Shift Notifier (tanaffus, taymer)
│       │   └── state_machine/        # Buyurtma holatlari chekli avtomati (OrderStateMachine)
│       └── features/                 # Funksional modullar
│           ├── auth/                 # Yagona login va rol tanlash ekranlari
│           ├── courier/              # Kuryer ekrani, 6-bosqichli yetkazish, xarita, naqd topshirish
│           ├── waiter/               # Zallar (Zal, Terrasa, VIP), stol ochish/birlashtirish, buyurtma, hisob/split
│           ├── shift/                # Doimiy koʻrinadigan smena paneli
│           └── common/               # Xodim profili, rolni chiqmasdan oʻzgartirish, bildirishnomalar
└── restaurant_system/                # Backend REST API, POS, Kassir va KDS
```

---

## 🚀 Xodimlar Ilovasi Imkoniyatlari (Staff App Features)

### 1. Autentifikatsiya va Rollar
- **Telefon yoki Xodim kodi + 4 xonali PIN:** Xodim oʻz shaxsiy kodi (masalan, `DIL-101`) yoki telefoni orqali kiradi.
- **Biometrik kirish (Face ID / Barmoq izi):** Birinchi kirishdan soʻng sozlamalardan faollashtiriladi.
- **Server orqali tekshiriladigan rollar:** Xodimga qaysi rollar berilgani backend tomonidan tasdiqlanadi (`assigned_roles: ['courier', 'waiter']`).
- **Chiqmasdan rolni almashtirish (Zero-Logout Switching):** Ikkala rolga ega xodim (masalan, Jasur Rahimov) profil ekranidan birgina bosish orqali Kuryerdan Ofitsiantga yoki aksincha oʻtishi mumkin.

### 2. Smena Boshqaruvi (Shift Management)
- **Doimiy smena paneli (Sticky Shift Bar):** Barcha asosiy ekranlarning yuqori qismida smena vaqti (soat:daqiqa:soniya), tanaffus tugmasi va smenani yakunlash koʻrinib turadi.
- **Smenadan tashqari xizmat cheklovi:** Xodim smenaga kirmagan yoki tanaffusda boʻlgan holatda yangi buyurtma olish yoki yangi stol ochish taqiqlanadi.

### 3. Kuryer Rejimi (Courier Mode)
- **30 soniyali yangi buyurtma ogohlantirishi:** Ovozli signal va tebranish bilan birga 30 soniyalik aylanuvchi taymer.
- **Navbat va ketma-ketlik:** Bir nechta buyurtma boʻlganda eng qulay yetkazib berish tartibi taklif qilinadi.
- **Jonli oshxona holati:** Kuryer restoranga qachon borishni bilishi uchun oshxona taomni pishirayotgani yoki tayyorlab boʻlgani kartada aks etadi.
- **6 bosqichli yetkazish jarayoni:**
  1. *Biriktirildi (Assigned)*
  2. *Restoranga yoʻlda (Heading to café)*
  3. *Olib ketildi (Picked up)* — 4 bandlik nazorat roʻyxati (taomlar, ichimliklar, souslar, termopaket muhrlanganligi).
  4. *Yetkazishda (On the way)* — In-app xarita va Yandex/Google/2GIS ga havola.
  5. *Yetib kelindi (Arrived)*
  6. *Topshirildi (Delivered)* — Mijoz tasdiqlash kodi yoki rasm orqali.
- **Muammolarni xabar qilish:** Mijoz telefonini koʻtarmasa 5 daqiqalik hisoblagich ishga tushadi va menejerga eskalatsiya qilinadi.
- **Kassaga naqd pul topshirish:** Yigʻilgan restoran pullari va kuryerning sof daromadi ajratilgan, kamomad/ortiqchalik hisoblanadi va kassir PIN-kodi orqali tasdiqlanadi.

### 4. Ofitsiant Rejimi (Waiter Mode)
- **Zallar va Stollar rejasi:** 3 ta zona (Asosiy Zal, Ochiq Terrasa, VIP Xonalar) yuqori kontrastli ranglar bilan (Boʻsh, Band, Oshxonada, Dasturxonga tayyor, Hisob soʻralgan, Bron).
- **Stol amallari:** Stol ochish (mehmon sonini 1–12 kishigacha tanlash), stolni boshqa ofitsiantga oʻtkazish, stollarni birlashtirish.
- **Buyurtma olish:** Qidiruv, toifalar, modifikatorlar (porsiya hajmi, qoʻshimchalar, tarkibdan olib tashlash), taom tortilish tartibi (birga yoki oldin), mehmonlar boʻyicha taqsimlash, allergen belgilari.
- **Chiptalarni yoʻnaltirish:** Issiq/sovuq taomlar oshxonaga, ichimliklar esa barga avtomatik yuboriladi.
- **Hisob-kitob va boʻlish (Split Bill):**
  - Umumiy toʻlov (Barchasi bitta).
  - Teng boʻlish (2–6 kishi orasida teng taqsimlash).
  - Mehmonlar boʻyicha alohida toʻlash.
  - 10% xizmat haqi va menejer PIN-kodi bilan chegirma berish.
  - Naqd, Bank kartasi, Click, Payme toʻlov usullari.
- **Chaqiruv va Bronlar:** Stol QR kodi orqali chaqiruvlar ekranning tepasida darhol qizil ogohlantirish sifatida chiqadi; kunlik bronlar roʻyxati boshqariladi.

---

## ⚡ Ishga Tushirish (Quick Start)

### 1. Flutter dependencies oʻrnatish:
```bash
flutter pub get
```

### 2. Kuryer va Ofitsiant Ilovasini ishga tushirish:
```bash
cd courier_app_flutter
flutter run
```

### 3. Sinov hisoblari (Demo Accounts):
- **Jasur Rahimov:** Tel: `+998 90 123 45 67`, PIN: `1234` *(Ikkala rol: Kuryer + Ofitsiant)*
- **Bobur Mirzayev:** Tel: `+998 93 555 11 22`, PIN: `1234` *(Faqat Kuryer)*
- **Malika Karimova:** Tel: `+998 97 777 88 99`, PIN: `1234` *(Faqat Ofitsiant)*

---

## 🛡 Sifat Kafolati (Quality Assurance)

- **`flutter analyze`:** Workspace boʻyicha **0 ta xato, 0 ta ogohlantirish (No issues found!)**
- **Unit & Widget Testlar:** 17 ta test toʻliq muvaffaqiyatli oʻtgan (`order_state_machine_test.dart`, `cash_bill_calculations_test.dart`, `unified_auth_flow_test.dart`, `widget_test.dart`).
- **Dizayn Tizimi Testlari:** 6 ta test toʻliq muvaffaqiyatli oʻtgan (`formatters_test.dart`, `colors_test.dart`).
- **Staff-UX Standarti:** Asosiy bosish elementlari >= 56dp, xavfsiz amallar uchun 4 soniyalik qaytarish (undo) snackbarlari, oʻzbek lotin imlosi (`oʻ`, `gʻ`, `soʻm`, `+998`).
