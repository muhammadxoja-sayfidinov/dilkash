from decimal import Decimal
from django.utils import timezone
from .models import (
    Ingredient, Supplier, StockSupply, StockSupplyItem,
    StockWriteOff, StockWriteOffItem, RecipeItem, StockMovementLog,
    Product
)


DEFAULT_SUPPLIERS = [
    {
        "name": "Chorsu Go'sht Markazi (Akrom qassob)",
        "phone": "+998901234567",
        "contact_person": "Akrom aka",
        "address": "Toshkent sh., Chorsu bozori, 4-go'sht rastasi",
        "balance": Decimal("0.00"),
    },
    {
        "name": "Oziq-ovqat va Sabzavotlar Bazasi (Bekzod)",
        "phone": "+998935554433",
        "contact_person": "Bekzod",
        "address": "Qo'yliq qishloq xo'jalik bozori, 12-ombor",
        "balance": Decimal("0.00"),
    },
    {
        "name": "Toshkent Ichimliklar Savdosi (Optom)",
        "phone": "+998971110022",
        "contact_person": "Shavkat",
        "address": "Sergeli sanoat zonasi, 8-baza",
        "balance": Decimal("0.00"),
    },
    {
        "name": "Qandolat va Non Mahsulotlari",
        "phone": "+998912223344",
        "contact_person": "Dilshod",
        "address": "Chilonzor 19-mavze",
        "balance": Decimal("0.00"),
    },
]


DEFAULT_INGREDIENTS = [
    # Go'sht va yog' mahsulotlari
    {"name": "Qoʻy goʻshti (lahm)", "category": "meat", "unit": "kg", "current_stock": Decimal("42.500"), "min_stock_alert": Decimal("10.000"), "cost_price": Decimal("95000.00")},
    {"name": "Mol goʻshti (lahm)", "category": "meat", "unit": "kg", "current_stock": Decimal("58.000"), "min_stock_alert": Decimal("15.000"), "cost_price": Decimal("85000.00")},
    {"name": "Mol goʻshti qiymasi", "category": "meat", "unit": "kg", "current_stock": Decimal("32.000"), "min_stock_alert": Decimal("8.000"), "cost_price": Decimal("78000.00")},
    {"name": "Tovuq goʻshti (fille)", "category": "meat", "unit": "kg", "current_stock": Decimal("28.000"), "min_stock_alert": Decimal("6.000"), "cost_price": Decimal("46000.00")},
    {"name": "Dumba yogʻi", "category": "meat", "unit": "kg", "current_stock": Decimal("18.500"), "min_stock_alert": Decimal("5.000"), "cost_price": Decimal("90000.00")},
    {"name": "Ot goʻshti (qazi)", "category": "meat", "unit": "kg", "current_stock": Decimal("12.000"), "min_stock_alert": Decimal("4.000"), "cost_price": Decimal("110000.00")},

    # Sabzavot va ko'katlar
    {"name": "Piyoz (saralangan)", "category": "vegetables", "unit": "kg", "current_stock": Decimal("85.000"), "min_stock_alert": Decimal("20.000"), "cost_price": Decimal("3500.00")},
    {"name": "Sabzi (sariq)", "category": "vegetables", "unit": "kg", "current_stock": Decimal("75.000"), "min_stock_alert": Decimal("15.000"), "cost_price": Decimal("4000.00")},
    {"name": "Kartoshka (saralangan)", "category": "vegetables", "unit": "kg", "current_stock": Decimal("90.000"), "min_stock_alert": Decimal("20.000"), "cost_price": Decimal("5000.00")},
    {"name": "Pomidor (yozgi/issiqxona)", "category": "vegetables", "unit": "kg", "current_stock": Decimal("22.000"), "min_stock_alert": Decimal("8.000"), "cost_price": Decimal("14000.00")},
    {"name": "Bodring", "category": "vegetables", "unit": "kg", "current_stock": Decimal("18.000"), "min_stock_alert": Decimal("6.000"), "cost_price": Decimal("12000.00")},
    {"name": "Koʻkatlar (shivit, kashnich, rayhon)", "category": "vegetables", "unit": "kg", "current_stock": Decimal("8.500"), "min_stock_alert": Decimal("3.000"), "cost_price": Decimal("16000.00")},

    # Quruq oziq-ovqat va un
    {"name": "Guruch (lazer oliy nav)", "category": "groceries", "unit": "kg", "current_stock": Decimal("80.000"), "min_stock_alert": Decimal("20.000"), "cost_price": Decimal("24000.00")},
    {"name": "Oliy navli un (somsa va non)", "category": "groceries", "unit": "kg", "current_stock": Decimal("125.000"), "min_stock_alert": Decimal("30.000"), "cost_price": Decimal("7500.00")},
    {"name": "Oʻsimlik paxta yogʻi", "category": "groceries", "unit": "l", "current_stock": Decimal("45.000"), "min_stock_alert": Decimal("15.000"), "cost_price": Decimal("18000.00")},
    {"name": "Kungaboqar yogʻi", "category": "groceries", "unit": "l", "current_stock": Decimal("38.000"), "min_stock_alert": Decimal("10.000"), "cost_price": Decimal("19000.00")},
    {"name": "Noʻxat (osh uchun)", "category": "groceries", "unit": "kg", "current_stock": Decimal("16.000"), "min_stock_alert": Decimal("5.000"), "cost_price": Decimal("22000.00")},
    {"name": "Mayiz (qora va sariq)", "category": "groceries", "unit": "kg", "current_stock": Decimal("9.000"), "min_stock_alert": Decimal("3.000"), "cost_price": Decimal("45000.00")},
    {"name": "Shakar", "category": "groceries", "unit": "kg", "current_stock": Decimal("35.000"), "min_stock_alert": Decimal("10.000"), "cost_price": Decimal("11000.00")},

    # Ichimliklar va bar (tayyor tovarlar)
    {"name": "Coca-Cola 1.5L shisha", "category": "beverages", "unit": "pcs", "current_stock": Decimal("44.000"), "min_stock_alert": Decimal("12.000"), "cost_price": Decimal("11500.00")},
    {"name": "Fanta 1.5L shisha", "category": "beverages", "unit": "pcs", "current_stock": Decimal("28.000"), "min_stock_alert": Decimal("10.000"), "cost_price": Decimal("11500.00")},
    {"name": "Koʻk choy (quruq 95-nav)", "category": "beverages", "unit": "kg", "current_stock": Decimal("7.500"), "min_stock_alert": Decimal("2.000"), "cost_price": Decimal("65000.00")},
    {"name": "Qora choy (togʻ giyohlari bilan)", "category": "beverages", "unit": "kg", "current_stock": Decimal("6.000"), "min_stock_alert": Decimal("2.000"), "cost_price": Decimal("72000.00")},
    {"name": "Limon", "category": "beverages", "unit": "kg", "current_stock": Decimal("11.000"), "min_stock_alert": Decimal("3.000"), "cost_price": Decimal("26000.00")},
    {"name": "Apelsin (fresh sharbat uchun)", "category": "beverages", "unit": "kg", "current_stock": Decimal("15.000"), "min_stock_alert": Decimal("5.000"), "cost_price": Decimal("18000.00")},
    {"name": "Qahva donalari (Lavazza espresso)", "category": "beverages", "unit": "kg", "current_stock": Decimal("5.500"), "min_stock_alert": Decimal("2.000"), "cost_price": Decimal("185000.00")},

    # Ziravorlar
    {"name": "Zira (togʻ zirasi)", "category": "spices", "unit": "kg", "current_stock": Decimal("4.200"), "min_stock_alert": Decimal("1.000"), "cost_price": Decimal("95000.00")},
    {"name": "Kashnich urugʻi", "category": "spices", "unit": "kg", "current_stock": Decimal("3.800"), "min_stock_alert": Decimal("1.000"), "cost_price": Decimal("45000.00")},
    {"name": "Qora murch maydalangan", "category": "spices", "unit": "kg", "current_stock": Decimal("3.000"), "min_stock_alert": Decimal("1.000"), "cost_price": Decimal("85000.00")},
    {"name": "Osh tuzi yodlangan", "category": "spices", "unit": "kg", "current_stock": Decimal("45.000"), "min_stock_alert": Decimal("10.000"), "cost_price": Decimal("2200.00")},
]


def ensure_default_inventory():
    """Boshlang'ich ta'minotchilar, xomashyolar va taomlar kalkulyatsiyasi (tex-karta)ni yaratadi."""
    # 1. Ta'minotchilar
    suppliers_map = {}
    for sup_data in DEFAULT_SUPPLIERS:
        sup, _ = Supplier.objects.get_or_create(
            name=sup_data["name"],
            defaults=sup_data,
        )
        suppliers_map[sup.name] = sup

    # 2. Xomashyolar
    ingredients_map = {}
    for ing_data in DEFAULT_INGREDIENTS:
        ing, _ = Ingredient.objects.get_or_create(
            name=ing_data["name"],
            defaults=ing_data,
        )
        ingredients_map[ing.name] = ing

    # 3. Retseptlar (Tex-karta)
    # Osh: Toshkent to'y oshi
    osh = Product.objects.filter(name__icontains="toʻy oshi").first() or Product.objects.filter(name__icontains="osh").first()
    if osh:
        recipe_specs = [
            ("Guruch (lazer oliy nav)", Decimal("0.150"), "kg"),
            ("Mol goʻshti (lahm)", Decimal("0.120"), "kg"),
            ("Sabzi (sariq)", Decimal("0.150"), "kg"),
            ("Piyoz (saralangan)", Decimal("0.040"), "kg"),
            ("Oʻsimlik paxta yogʻi", Decimal("0.035"), "l"),
            ("Noʻxat (osh uchun)", Decimal("0.020"), "kg"),
            ("Mayiz (qora va sariq)", Decimal("0.010"), "kg"),
            ("Zira (togʻ zirasi)", Decimal("0.002"), "kg"),
            ("Osh tuzi yodlangan", Decimal("0.004"), "kg"),
        ]
        for ing_name, qty, unit in recipe_specs:
            ing = ingredients_map.get(ing_name)
            if ing:
                RecipeItem.objects.get_or_create(
                    product=osh,
                    ingredient=ing,
                    defaults={"quantity": qty, "unit": unit, "notes": "Standart 1 porsiya"},
                )

    # Shashlik: Qo'y go'shti shashlik
    shashlik_qoy = Product.objects.filter(name__icontains="Qoʻy goʻshti shashlik").first() or Product.objects.filter(name__icontains="shashlik").first()
    if shashlik_qoy:
        recipe_specs = [
            ("Qoʻy goʻshti (lahm)", Decimal("0.150"), "kg"),
            ("Dumba yogʻi", Decimal("0.030"), "kg"),
            ("Piyoz (saralangan)", Decimal("0.030"), "kg"),
            ("Zira (togʻ zirasi)", Decimal("0.001"), "kg"),
            ("Kashnich urugʻi", Decimal("0.001"), "kg"),
            ("Osh tuzi yodlangan", Decimal("0.003"), "kg"),
        ]
        for ing_name, qty, unit in recipe_specs:
            ing = ingredients_map.get(ing_name)
            if ing:
                RecipeItem.objects.get_or_create(
                    product=shashlik_qoy,
                    ingredient=ing,
                    defaults={"quantity": qty, "unit": unit, "notes": "1 six uchun"},
                )

    # Somsa: Tandir go'shtli somsa
    somsa = Product.objects.filter(name__icontains="somsa").first()
    if somsa:
        recipe_specs = [
            ("Oliy navli un (somsa va non)", Decimal("0.080"), "kg"),
            ("Mol goʻshti qiymasi", Decimal("0.070"), "kg"),
            ("Piyoz (saralangan)", Decimal("0.050"), "kg"),
            ("Dumba yogʻi", Decimal("0.015"), "kg"),
            ("Osh tuzi yodlangan", Decimal("0.003"), "kg"),
        ]
        for ing_name, qty, unit in recipe_specs:
            ing = ingredients_map.get(ing_name)
            if ing:
                RecipeItem.objects.get_or_create(
                    product=somsa,
                    ingredient=ing,
                    defaults={"quantity": qty, "unit": unit, "notes": "1 dona tandir somsa"},
                )

    # Choy: Ko'k choy limon bilan
    choy = Product.objects.filter(name__icontains="Koʻk choy").first()
    if choy:
        recipe_specs = [
            ("Koʻk choy (quruq 95-nav)", Decimal("0.008"), "kg"),
            ("Limon", Decimal("0.040"), "kg"),
            ("Shakar", Decimal("0.020"), "kg"),
        ]
        for ing_name, qty, unit in recipe_specs:
            ing = ingredients_map.get(ing_name)
            if ing:
                RecipeItem.objects.get_or_create(
                    product=choy,
                    ingredient=ing,
                    defaults={"quantity": qty, "unit": unit, "notes": "1 choynak"},
                )

    # Boshlang'ich kirim hujjati (namuna sifatida)
    if not StockSupply.objects.exists():
        sup = suppliers_map.get("Chorsu Go'sht Markazi (Akrom qassob)") or Supplier.objects.first()
        doc_num = f"KIR-{timezone.now():%Y%m%d}-0001"
        supply = StockSupply.objects.create(
            doc_number=doc_num,
            supplier=sup,
            date=timezone.now(),
            total_cost=Decimal("4950000.00"),
            payment_status="paid",
            paid_amount=Decimal("4950000.00"),
            notes="Boshlang'ich partiya go'sht mahsulotlari qabul qilindi",
            created_by="Kassa boshlig'i",
        )
        qoy = ingredients_map.get("Qoʻy goʻshti (lahm)")
        mol = ingredients_map.get("Mol goʻshti (lahm)")
        if qoy:
            StockSupplyItem.objects.create(
                supply=supply,
                ingredient=qoy,
                quantity=Decimal("30.000"),
                unit_price=qoy.cost_price,
                total_price=Decimal("30.000") * qoy.cost_price,
            )
        if mol:
            StockSupplyItem.objects.create(
                supply=supply,
                ingredient=mol,
                quantity=Decimal("25.000"),
                unit_price=mol.cost_price,
                total_price=Decimal("25.000") * mol.cost_price,
            )


def get_inventory_kpi_summary():
    """Omborxona bo'yicha asosiy ko'rsatkichlar (KPI) jamlanmasi"""
    total_ingredients = Ingredient.objects.filter(is_active=True).count()
    low_stock_count = sum(1 for ing in Ingredient.objects.filter(is_active=True) if ing.is_low_stock)

    total_valuation = Decimal("0.00")
    for ing in Ingredient.objects.filter(is_active=True):
        total_valuation += ing.total_valuation

    today = timezone.now().date()
    today_supplies_total = Decimal("0.00")
    today_supplies = StockSupply.objects.filter(date__date=today)
    for s in today_supplies:
        today_supplies_total += s.total_cost

    today_writeoffs_total = Decimal("0.00")
    today_writeoffs = StockWriteOff.objects.filter(date__date=today)
    for w in today_writeoffs:
        today_writeoffs_total += w.total_cost

    return {
        "total_ingredients": total_ingredients,
        "low_stock_count": low_stock_count,
        "total_valuation": float(total_valuation),
        "today_supplies_total": float(today_supplies_total),
        "today_writeoffs_total": float(today_writeoffs_total),
        "suppliers_count": Supplier.objects.filter(is_active=True).count(),
    }
