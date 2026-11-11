import os
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import BaseCommand
from django.core.management.color import no_style
from django.db import connection
from chef_panel.models import BotSettings, Category, CourierProfile, Product, RestaurantTable, WaiterProfile


DEFAULT_TABLES = [
    (1, "Stol #1", 4),
    (2, "Stol #2", 4),
    (3, "Stol #3", 4),
    (4, "Stol #4", 6),
    (5, "Stol #5", 6),
    (6, "Stol #6", 8),
    (7, "Terrasa #7", 4),
    (8, "Terrasa #8", 4),
    (9, "Terrasa #9", 6),
    (10, "VIP #10", 8),
    (11, "VIP #11", 10),
    (12, "VIP #12", 12),
]

DEFAULT_WAITERS = [
    ("Jasur Rahimov", "+998901112233", "1234"),
    ("Sardor Alimov", "+998902223344", "2345"),
    ("Nodir Karimov", "+998903334455", "3456"),
]


class Command(BaseCommand):
    help = "Dilkash POS va backend uchun boshlang'ich stol, ofitsiant va sozlamalarni yaratadi (idempotent)."

    def handle(self, *args, **options):
        BotSettings.get_settings()

        loaded_menu = False
        if Category.objects.count() == 0 and Product.objects.count() == 0:
            call_command("loaddata", "initial_menu.json", verbosity=0)
            loaded_menu = True
            sql_statements = connection.ops.sequence_reset_sql(no_style(), [Category, Product])
            if sql_statements:
                with connection.cursor() as cursor:
                    for sql in sql_statements:
                        cursor.execute(sql)

        created_tables = 0
        for number, name, capacity in DEFAULT_TABLES:
            _, created = RestaurantTable.objects.get_or_create(
                number=number,
                defaults={"name": name, "capacity": capacity, "is_active": True},
            )
            if created:
                created_tables += 1

        created_waiters = 0
        if not WaiterProfile.objects.exists():
            for name, phone, pin_code in DEFAULT_WAITERS:
                WaiterProfile.objects.create(
                    name=name,
                    phone=phone,
                    pin_code=pin_code,
                    is_active=True,
                )
                created_waiters += 1

        if not CourierProfile.objects.exists():
            CourierProfile.objects.create(
                name="Jasur Rahimov",
                phone="+998901112233",
                pin_code="1234",
                vehicle_info="Honda Dio Scooter (Oq)",
                is_active=True,
            )

        admin_password = os.environ.get("DJANGO_ADMIN_PASSWORD", "").strip()
        admin_username = os.environ.get("DJANGO_ADMIN_USERNAME", "admin").strip() or "admin"
        User = get_user_model()
        if admin_password and not User.objects.filter(username=admin_username).exists():
            User.objects.create_superuser(username=admin_username, email="", password=admin_password)

        self.stdout.write(
            self.style.SUCCESS(
                f"POS defaults tayyor: menyu yuklandi={loaded_menu} "
                f"(kategoriyalar={Category.objects.count()}, mahsulotlar={Product.objects.count()}), "
                f"{created_tables} ta stol qo'shildi (jami {RestaurantTable.objects.count()}), "
                f"{created_waiters} ta ofitsiant qo'shildi (jami {WaiterProfile.objects.count()})."
            )
        )
