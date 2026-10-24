import os
import ssl
import urllib.request
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_system.settings')
django.setup()

from chef_panel.models import Category, Product

# SSL context for downloading images without cert errors on local mac
ssl_ctx = ssl.create_default_context()
ssl_ctx.check_hostname = False
ssl_ctx.verify_mode = ssl.CERT_NONE

MEDIA_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'media', 'products')
os.makedirs(MEDIA_ROOT, exist_ok=True)

def download_image(url, filename):
    dest_path = os.path.join(MEDIA_ROOT, filename)
    if os.path.exists(dest_path) and os.path.getsize(dest_path) > 1000:
        return f"products/{filename}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'})
        with urllib.request.urlopen(req, context=ssl_ctx, timeout=12) as response:
            with open(dest_path, 'wb') as f:
                f.write(response.read())
        print(f"  [OK] Yuklandi: {filename}")
        return f"products/{filename}"
    except Exception as e:
        print(f"  [XATO] Yuklashda xatolik ({filename}): {e}")
        return ""

MENU_DATA = [
    {
        "category": "Milliy Taomlar",
        "description": "An'anaviy o'zbek milliy taomlari, o'choqda pishirilgan oshlar, tandir go'shtlari",
        "items": [
            {
                "name": "To'y Oshi (Maxsus Dilkash Palovi)",
                "price": 45000,
                "description": "Lazer guruch, mayin lahm mol go'shti, sariq va qizil sabzi, bedana tuxumi, kazy va no'xat bilan damlangan maxsus to'y oshi.",
                "image_file": "toy_oshi.jpg",
                "image_url": "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=700&q=80"
            },
            {
                "name": "Choyxona Oshi (Qo'y go'shti)",
                "price": 48000,
                "description": "Devzira guruch, shirador qo'y go'shti, dumba yog'i va achchiq qalampir bilan o'choqda pishirilgan haqiqiy choyxona palovi.",
                "image_file": "choyxona_oshi.jpg",
                "image_url": "https://images.unsplash.com/photo-1633964913295-ceb43826e7c9?w=700&q=80"
            },
            {
                "name": "Samarqandcha Qozon Kabob",
                "price": 68000,
                "description": "Tilla rang qilib qovurilgan yosh buzoqcha go'shti, qizarib pishgan kartoshkalar va ziravorli piyoz bilan.",
                "image_file": "qozon_kabob.jpg",
                "image_url": "https://images.unsplash.com/photo-1544025162-d76694265947?w=700&q=80"
            },
            {
                "name": "Toshkentcha Manti (5 dona)",
                "price": 38000,
                "description": "Yupqa xamir ichida mayda to'g'ralgan shirador lahm go'sht va piyoz, qaymoq va ko'katlar bilan tortiladi.",
                "image_file": "manti.jpg",
                "image_url": "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=700&q=80"
            },
            {
                "name": "Tandir Jiz (Qo'zi go'shti)",
                "price": 75000,
                "description": "Tandirda maxsus giyohlar va archa dudida pishgan mayin, erib ketuvchi qo'zi go'shti.",
                "image_file": "tandir_jiz.jpg",
                "image_url": "https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=700&q=80"
            },
            {
                "name": "Uyg'urcha Qovurma Lag'mon",
                "price": 44000,
                "description": "Qo'lda cho'zilgan cho'ziq xamir, barra sabzavotlar, mol go'shti va dungan qalampirli maxsus qayla.",
                "image_file": "lagmon.jpg",
                "image_url": "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=700&q=80"
            },
            {
                "name": "Toshkentcha Norin (Qazi bilan)",
                "price": 42000,
                "description": "Yupqa mayin xamir, ot va mol go'shti, qazi parraklari va issiq shaffof bulyon.",
                "image_file": "norin.jpg",
                "image_url": "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=700&q=80"
            }
        ]
    },
    {
        "category": "Kaboblar & Gril",
        "description": "Olovda pishirilgan shirador shashliklar, lulya va mayin go'shtli kaboblar",
        "items": [
            {
                "name": "Shirador Qiyma Lyulya Kabob",
                "price": 22000,
                "description": "Mayin mol go'shti va dumba qiyma, maxsus ziravorlar va marinadlangan piyoz bilan cho'g'da pishgan.",
                "image_file": "lyulya_kabob.jpg",
                "image_url": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=700&q=80"
            },
            {
                "name": "Kuskovoy Qo'zi Go'shti Kabobi",
                "price": 26000,
                "description": "Yumshoq qo'zi go'shti laxtalari, zira va kashnich urug'i bilan xushbo'y pishirilgan shashlik.",
                "image_file": "kuskovoy_shashlik.jpg",
                "image_url": "https://images.unsplash.com/photo-1544025162-d76694265947?w=700&q=80"
            },
            {
                "name": "Maxsus Napoleon Kabob",
                "price": 28000,
                "description": "Go'sht va dumba qatlamlaridan iborat shirador shohona kabob.",
                "image_file": "napoleon_kabob.jpg",
                "image_url": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=700&q=80"
            },
            {
                "name": "Tovuq Filesi Kabobi",
                "price": 20000,
                "description": "Smetana va limon marinadida ivitilgan barra tovuq go'shti, o'ta mayin va parhezbop.",
                "image_file": "tovuq_kabob.jpg",
                "image_url": "https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=700&q=80"
            },
            {
                "name": "Gril Qovurg'alar (Mol qovurg'asi)",
                "price": 65000,
                "description": "BBQ sousi va archa o'tlarida cho'g'da qovurilgan mazali qovurg'alar.",
                "image_file": "gril_qovurga.jpg",
                "image_url": "https://images.unsplash.com/photo-1544025162-d76694265947?w=700&q=80"
            },
            {
                "name": "Sabzavotli Gril Kabob",
                "price": 18000,
                "description": "Cho'g'da pishirilgan pomidor, baqlajon, shirin qalampir va qo'ziqorinlar.",
                "image_file": "sabzavot_gril.jpg",
                "image_url": "https://images.unsplash.com/photo-1592417817098-8f3d6910985c?w=700&q=80"
            }
        ]
    },
    {
        "category": "Birinchi Taomlar",
        "description": "To'yimli, issiq va lazzatli milliy hamda yevropa sho'rvalari",
        "items": [
            {
                "name": "Dilkash Maxsus Sho'rva",
                "price": 35000,
                "description": "Suyakli barra qo'zi go'shti, butun kartoshka, no'xat va xushbo'y rayhonli shaffof sho'rva.",
                "image_file": "dilkash_shorva.jpg",
                "image_url": "https://images.unsplash.com/photo-1547592166-23ac45744acd?w=700&q=80"
            },
            {
                "name": "Chuchvara Sho'rva",
                "price": 32000,
                "description": "Mittivoy chuchvaralar, to'yimli go'shtli bulyon, yangi uzilgan kashnich va smetana.",
                "image_file": "chuchvara_shorva.jpg",
                "image_url": "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=700&q=80"
            },
            {
                "name": "Mastava (Suzmali)",
                "price": 30000,
                "description": "Qovurma sho'rva, mayda to'g'ralgan go'sht, guruch, sabzavotlar va suzma bilan.",
                "image_file": "mastava.jpg",
                "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=700&q=80"
            },
            {
                "name": "Tom Yum Go'shtli va Dengizcha",
                "price": 55000,
                "description": "Tay uslubidagi nordon-achchiq kokos sutli sho'rva, krevetkalar va qo'ziqorin bilan.",
                "image_file": "tom_yum.jpg",
                "image_url": "https://images.unsplash.com/photo-1548943487-a2e4e43b4853?w=700&q=80"
            },
            {
                "name": "Qo'ziqorinli Qaymoqli Krem Sho'rva",
                "price": 28000,
                "description": "Mayin qaymoq, yangi shampinyonlar va sarimsoqli qarsildoq suxariklar bilan.",
                "image_file": "krem_shorva.jpg",
                "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=700&q=80"
            }
        ]
    },
    {
        "category": "Salatlar & Gazaklar",
        "description": "Yangi barra sabzavotlar, qazi, nozik pishloqlar va xushxo'r salatlar",
        "items": [
            {
                "name": "Achchiq-Chuchuk Salati",
                "price": 15000,
                "description": "Yupqa parrak qilingan Yulduz pomidori, shirin piyoz, rayhon va qora murch.",
                "image_file": "achchiq_chuchuk.jpg",
                "image_url": "https://images.unsplash.com/photo-1592417817098-8f3d6910985c?w=700&q=80"
            },
            {
                "name": "Sezar Salati (Gril Tovuq bilan)",
                "price": 36000,
                "description": "Aysberg barglari, parmezan pishlog'i, cherri pomidori, qarsildoq krutonlar va maxsus Sezar sousi.",
                "image_file": "sezar_salat.jpg",
                "image_url": "https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=700&q=80"
            },
            {
                "name": "Grekcha Salat",
                "price": 32000,
                "description": "Yangi bodring, pomidor, bolgar qalampiri, Kalamata zaytunlari va Feta pishlog'i, zaytun moyi bilan.",
                "image_file": "grekcha_salat.jpg",
                "image_url": "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=700&q=80"
            },
            {
                "name": "Mujskoy Kapriz Salati",
                "price": 38000,
                "description": "Qaynatilgan mol tili, dudlangan lahm go'sht, qattiq pishloq, yong'oq va yengil sous.",
                "image_file": "mujskoy_kapriz.jpg",
                "image_url": "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=700&q=80"
            },
            {
                "name": "Go'shtli Assorti (Qazi, Til, Rulet)",
                "price": 65000,
                "description": "Haqiqiy ot go'shtidan qazi, nozik pishirilgan mol tili, go'shtli rulet va xantal (gorchitsa).",
                "image_file": "goshtli_assorti.jpg",
                "image_url": "https://images.unsplash.com/photo-1544025162-d76694265947?w=700&q=80"
            }
        ]
    },
    {
        "category": "Fast Food & Burgerlar",
        "description": "Shirador bifshteksli burgerlar, sendvichlar va tillarang fri",
        "items": [
            {
                "name": "Dilkash Black Burger",
                "price": 45000,
                "description": "Black Angus mol go'shtidan shirador kotlet, erigan Cheddar, karamellangan piyoz va maxsus sous.",
                "image_file": "dilkash_burger.jpg",
                "image_url": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=700&q=80"
            },
            {
                "name": "Double Cheese Burger",
                "price": 48000,
                "description": "Ikkita yirik bifshteks, qo'shaloq cheddar pishlog'i, tuzlangan bodring va fri sousi.",
                "image_file": "double_cheese_burger.jpg",
                "image_url": "https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=700&q=80"
            },
            {
                "name": "Crispy Chicken Sendvich",
                "price": 34000,
                "description": "Qarsildoq tovuq filesi, yangi aysberg salati, pomidor va shirin xantal sousi brioche bulochkasida.",
                "image_file": "chicken_sandwich.jpg",
                "image_url": "https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?w=700&q=80"
            },
            {
                "name": "Kartoshka Fri (Katta)",
                "price": 18000,
                "description": "Oltin rang, qarsildoq qovurilgan kartoshka fri va ketchup/mayonez sousi.",
                "image_file": "kartoshka_fri.jpg",
                "image_url": "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=700&q=80"
            },
            {
                "name": "Qishloqcha Kartoshka (Po-Derevenski)",
                "price": 20000,
                "description": "Rozmarin va sarimsoq bilan pechda pishirilgan xushbo'y kartoshka bo'laklari.",
                "image_file": "kartoshka_po_derevenski.jpg",
                "image_url": "https://images.unsplash.com/photo-1518013034458-30b0ee243591?w=700&q=80"
            }
        ]
    },
    {
        "category": "Desertlar",
        "description": "Restoran qandolatchilari tomonidan tayyorlangan mayin shirinliklar",
        "items": [
            {
                "name": "San Sebastian Chizkeyki",
                "price": 32000,
                "description": "Ustki qismi karamellangan, ichi o'ta mayin ispan chizkeyki, issiq shokolad quyilishi bilan.",
                "image_file": "san_sebastian.jpg",
                "image_url": "https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=700&q=80"
            },
            {
                "name": "Asalli Medovik",
                "price": 25000,
                "description": "Klassik retsept bo'yicha tabiiy tog' asali va smetana kremli nozik qatlamli tort.",
                "image_file": "medovik.jpg",
                "image_url": "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=700&q=80"
            },
            {
                "name": "Shokoladli Brauni & Muzqaymoq",
                "price": 28000,
                "description": "Issiq qora shokoladli biskvit va vanilli muzqaymoq shari.",
                "image_file": "brauni.jpg",
                "image_url": "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=700&q=80"
            },
            {
                "name": "Turk Paxlavasi (Fistashkali)",
                "price": 30000,
                "description": "40 qatlamli yupqa xamir, maydalangan pista va asal qiyomi bilan to'yintirilgan.",
                "image_file": "paxlava.jpg",
                "image_url": "https://images.unsplash.com/photo-1519676867240-f03562e64548?w=700&q=80"
            }
        ]
    },
    {
        "category": "Ichimliklar & Choylar",
        "description": "Choylar, tabiiy sharbatlar, maxsus limonadlar va xushbo'y kofe",
        "items": [
            {
                "name": "Maxsus Dilkash Limonadi (1L)",
                "price": 28000,
                "description": "Yangi siqilgan limon, yalpiz, laym va qulupnay mevalari bilan tetiklantiruvchi mualliflik ichimligi.",
                "image_file": "dilkash_limonad.jpg",
                "image_url": "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=700&q=80"
            },
            {
                "name": "Klassik Mojito (Muzli)",
                "price": 22000,
                "description": "Yalpiz barglari, yangi laym sharbati, shakar qiyomi va gazlangan suv.",
                "image_file": "mojito.jpg",
                "image_url": "https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=700&q=80"
            },
            {
                "name": "Choyxona Choyi (Choynakda)",
                "price": 10000,
                "description": "№95 ko'k choy yoki xushbo'y qora choy, yangi limon va tog' yalpizi barglari bilan.",
                "image_file": "choyxona_choyi.jpg",
                "image_url": "https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=700&q=80"
            },
            {
                "name": "Yangi Siqilgan Apelsin Sharbati (Fresh 300ml)",
                "price": 25000,
                "description": "100% tabiiy, shakar qo'shilmagan toza apelsin sharbati.",
                "image_file": "fresh_apelsin.jpg",
                "image_url": "https://images.unsplash.com/photo-1613478223719-2ab802602423?w=700&q=80"
            },
            {
                "name": "Qahva Kapuchino / Latte",
                "price": 18000,
                "description": "Yangi tortilgan arabika donalaridan tayyorlangan xushbo'y espresso va mayin sut ko'pigi.",
                "image_file": "cappuccino.jpg",
                "image_url": "https://images.unsplash.com/photo-1534778101976-62847782c213?w=700&q=80"
            }
        ]
    },
    {
        "category": "Nonlar & Qo'shimchalar",
        "description": "Tandir nonlar, qarsildoq somsalar va maxsus souslar",
        "items": [
            {
                "name": "Issiq Tandir Non (Patir)",
                "price": 7000,
                "description": "Sut va sariyog' qo'shib tandirda qizartirib yopilgan xushbo'y patir non.",
                "image_file": "tandir_patir.jpg",
                "image_url": "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=700&q=80"
            },
            {
                "name": "Go'shtli Tandir Somsa (Dona)",
                "price": 12000,
                "description": "Qarsildoq qatlama xamir, mayin mol go'shti va dumba, qora sedana sepilgan.",
                "image_file": "tandir_somsa.jpg",
                "image_url": "https://images.unsplash.com/photo-1601050690117-94f5f6fa8bd7?w=700&q=80"
            },
            {
                "name": "Maxsus Oq va Qizil Souslar",
                "price": 8000,
                "description": "Sarimsoqli suzma sousi va achchiq pomidorli shashlik sousi to'plami.",
                "image_file": "souslar.jpg",
                "image_url": "https://images.unsplash.com/photo-1472476443507-c7a5948772fc?w=700&q=80"
            }
        ]
    }
]

def main():
    print("=" * 60)
    print("Dilkash Restoran Menyu Bazasini To'ldirish Boshlandi...")
    print("=" * 60)

    # Clean up garbage test entries
    garbage_cats = Category.objects.filter(name__in=["moo", "jyguyg", "qwerty"])
    if garbage_cats.exists():
        print(f"Eski test kategoriyalar tozalanmoqda: {list(garbage_cats.values_list('name', flat=True))}")
        garbage_cats.delete()

    garbage_prods = Product.objects.filter(name__in=["jyguyg", "qwerty"])
    if garbage_prods.exists():
        print(f"Eski test mahsulotlar tozalanmoqda: {list(garbage_prods.values_list('name', flat=True))}")
        garbage_prods.delete()

    # If "MIlliy" exists, rename to "Milliy Taomlar"
    old_milliy = Category.objects.filter(name__iexact="milliy").first()
    if old_milliy:
        old_milliy.name = "Milliy Taomlar"
        old_milliy.description = "An'anaviy o'zbek milliy taomlari, o'choqda pishirilgan oshlar, tandir go'shtlari"
        old_milliy.save()

    total_created_cats = 0
    total_created_prods = 0

    for section in MENU_DATA:
        cat_name = section["category"]
        cat_desc = section["description"]
        cat, created = Category.objects.get_or_create(
            name=cat_name,
            defaults={"description": cat_desc, "is_active": True}
        )
        if not created and not cat.description:
            cat.description = cat_desc
            cat.save()

        if created:
            total_created_cats += 1
            print(f"\n[+] Yangi kategoriya: {cat_name}")
        else:
            print(f"\n[*] Mavjud kategoriya: {cat_name}")

        for item in section["items"]:
            # Download image
            img_rel_path = download_image(item["image_url"], item["image_file"])

            prod, p_created = Product.objects.get_or_create(
                category=cat,
                name=item["name"],
                defaults={
                    "price": item["price"],
                    "description": item["description"],
                    "image": img_rel_path,
                    "is_available": True
                }
            )
            if not p_created:
                # Update details and ensure image is set
                prod.price = item["price"]
                prod.description = item["description"]
                if img_rel_path and (not prod.image or not os.path.exists(prod.image.path)):
                    prod.image = img_rel_path
                prod.is_available = True
                prod.save()
                print(f"  ~ Yangilandi: {item['name']} ({item['price']:,} so'm)")
            else:
                total_created_prods += 1
                print(f"  + Qo'shildi: {item['name']} ({item['price']:,} so'm)")

    print("\n" + "=" * 60)
    print("MUVAFFAQINLI YAKUNLANDI!")
    print(f"Jami kategoriyalar: {Category.objects.count()} ta")
    print(f"Jami mahsulotlar: {Product.objects.count()} ta")
    print("=" * 60)

if __name__ == '__main__':
    main()
