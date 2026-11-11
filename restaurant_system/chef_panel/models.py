from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from django.core.validators import MinValueValidator, MaxValueValidator
import datetime

class Category(models.Model):
    """Mahsulot kategoriyalari"""
    DEPARTMENT_CHOICES = [
        ('kitchen', "Issiq oshxona (Milliy va birinchi taomlar)"),
        ('shashlik', "Shashlikxona / Mangal (Kaboblar va Gril)"),
        ('somsa', "Somsaxona / Tandir (Somsalar va nonlar)"),
        ('fastfood', "Fast-Food & Burgerlar"),
        ('bar', "Bar & Desertxona (Desertlar va Ichimliklar)"),
        ('kassa', "Kassa (Umumiy hisob)"),
    ]

    name = models.CharField(max_length=100, verbose_name="Kategoriya nomi")
    department = models.CharField(
        max_length=20,
        choices=DEPARTMENT_CHOICES,
        default='kitchen',
        blank=True,
        verbose_name="Chiqish bo'limi (Printer)",
        help_text="Ushbu kategoriya taomlari qaysi chek printeriga chiqishi kerak"
    )
    description = models.TextField(blank=True, verbose_name="Tavsif")
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True, verbose_name="Faol")

    class Meta:
        verbose_name = "Kategoriya"
        verbose_name_plural = "Kategoriyalar"
        ordering = ['name']

    def __str__(self):
        return self.name

    @classmethod
    def infer_department(cls, name):
        name_lower = (name or '').lower()
        if any(w in name_lower for w in ['somsa', 'tandir somsa', 'patir', 'tandir non', 'non']):
            return 'somsa'
        if any(w in name_lower for w in ['burger', 'sendvich', 'sandwich', 'fri', 'lavash', 'doner', 'hot dog', 'hotdog', 'fast food', 'fastfood', 'derevenski']):
            return 'fastfood'
        if any(k in name_lower for k in ['kabob', 'gril', 'shashlik', 'mangal', 'qiyma', 'kuskovoy', 'jigar', 'kofta']):
            return 'shashlik'
        elif any(k in name_lower for k in [
            'desert', 'ichimlik', 'sharbat', 'kofe', 'qahva', 
            'chizkeyk', 'medovik', 'brauni', 'paxlava', 'limonad', 'mojito', 
            'shirinlik', 'tort', 'pirog', 'muzqaymoq', 'suv', 'kola', 'cola', 
            'fanta', 'sprite', 'pepsi', 'flesh', 'red bull', 'sok', 'kompot'
        ]) or ('choy' in name_lower and 'choyxona' not in name_lower):
            return 'bar'
        elif any(k in name_lower for k in ['hisob', 'kassa']):
            return 'kassa'
        return 'kitchen'

    def get_department(self):
        if self.department and self.department != 'kitchen':
            return self.department
        inferred = self.infer_department(self.name)
        if inferred != 'kitchen':
            return inferred
        return self.department or 'kitchen'

class Product(models.Model):
    """Mahsulotlar"""
    category = models.ForeignKey(Category, on_delete=models.CASCADE, verbose_name="Kategoriya")
    name = models.CharField(max_length=200, verbose_name="Mahsulot nomi")
    description = models.TextField(blank=True, verbose_name="Tavsif")
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Narxi (so'm)")
    image = models.ImageField(upload_to='products/', blank=True, null=True, verbose_name="Rasm")
    is_available = models.BooleanField(default=True, verbose_name="Mavjud")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Mahsulot"
        verbose_name_plural = "Mahsulotlar"
        ordering = ['category', 'name']

    def __str__(self):
        return f"{self.name} - {self.price:,} so'm"

    def get_department(self):
        # 1. Asosiy: Menyudagi Kategoriya bo'limi
        if self.category:
            cat_dept = self.category.get_department()
            if cat_dept in ['kitchen', 'shashlik', 'somsa', 'fastfood', 'bar', 'kassa']:
                return cat_dept
        # 2. Agar kategoriya bo'lmasa, nomidan aniqlash
        return Category.infer_department(self.name)

class Customer(models.Model):
    """Mijozlar"""
    telegram_id = models.BigIntegerField(unique=True, verbose_name="Telegram ID")
    full_name = models.CharField(max_length=200, verbose_name="To'liq ismi")
    phone_number = models.CharField(max_length=20, verbose_name="Telefon raqami")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Mijoz"
        verbose_name_plural = "Mijozlar"

    def __str__(self):
        return f"{self.full_name} ({self.phone_number})"

class Order(models.Model):
    """Buyurtmalar"""
    STATUS_CHOICES = [
        ('yangi', 'Yangi'),
        ('tasdiqlangan', 'Tasdiqlangan'),
        ('tayor', 'Tayor'),
        ('yolda', 'Yo\'lda'),
        ('yetkazildi', 'Yetkazildi'),
        ('olib_ketildi', 'Olib ketildi'),
        ('bekor_qilingan', 'Bekor qilingan'),
    ]

    PAYMENT_CHOICES = [
        ('naqd', 'Naqd'),
        ('karta', 'Karta'),
        ('click', 'Click'),
        ('payme', 'Payme'),
        ('online', 'Online to\'lov'),
    ]

    SERVICE_TYPE_CHOICES = [
        ('delivery', 'Yetkazib berish'),
        ('pickup', 'Olib ketish'),
        ('dine_in', 'Stolda (Restoranda)'),
    ]

    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, verbose_name="Mijoz")
    telegram_user_id = models.BigIntegerField(verbose_name="Telegram User ID", null=True, blank=True)
    order_number = models.CharField(max_length=20, unique=True, verbose_name="Buyurtma raqami")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='yangi', verbose_name="Holati")
    payment_method = models.CharField(max_length=20, choices=PAYMENT_CHOICES, default='naqd', verbose_name="To'lov usuli")
    service_type = models.CharField(max_length=20, choices=SERVICE_TYPE_CHOICES, default='delivery', verbose_name="Xizmat turi")
    table_number = models.CharField(max_length=20, blank=True, null=True, verbose_name="Stol raqami")
    waiter = models.ForeignKey('WaiterProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders', verbose_name="Ofitsiant")
    waiter_name = models.CharField(max_length=150, blank=True, null=True, verbose_name="Ofitsiant ismi")
    courier = models.ForeignKey('CourierProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders', verbose_name="Kuryer")
    courier_name = models.CharField(max_length=150, blank=True, null=True, verbose_name="Kuryer ismi")
    notes = models.TextField(blank=True, null=True, verbose_name="Izoh / Qo'shimcha talablar")
    is_paid = models.BooleanField(default=False, verbose_name="To'langan")
    payment_id = models.CharField(max_length=100, blank=True, null=True, verbose_name="Tranzaksiya ID")
    
    # Manzil ma'lumotlari (faqat delivery uchun)
    latitude = models.FloatField(verbose_name="Kenglik", null=True, blank=True)
    longitude = models.FloatField(verbose_name="Uzunlik", null=True, blank=True)
    address = models.TextField(blank=True, null=True, verbose_name="Manzil")
    
    # Narxlar
    products_total = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Mahsulotlar summasi")
    delivery_cost = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Yetkazib berish narxi", default=0)
    service_fee_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name="Xizmat haqi summasi")
    discount_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0, verbose_name="Chegirma (%)")
    discount_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name="Chegirma summasi")
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Umumiy summa")
    
    # Kassa va Mehmonlar ma'lumotlari
    guests_count = models.PositiveIntegerField(default=1, verbose_name="Mehmonlar soni")
    offline_id = models.CharField(max_length=64, blank=True, null=True, unique=True, db_index=True, verbose_name="Lokal Kassa ID (Offline)")
    is_synced = models.BooleanField(default=True, verbose_name="Sinxronlangan")
    
    # Vaqt ma'lumotlari
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Yaratilgan vaqti")
    confirmed_at = models.DateTimeField(null=True, blank=True, verbose_name="Tasdiqlangan vaqti")
    ready_at = models.DateTimeField(null=True, blank=True, verbose_name="Tayor bo'lgan vaqti")
    delivered_at = models.DateTimeField(null=True, blank=True, verbose_name="Yetkazilgan vaqti")
    picked_up_at = models.DateTimeField(null=True, blank=True, verbose_name="Olib ketilgan vaqti")
    
    # Telegram message ID'lar
    chef_message_id = models.BigIntegerField(null=True, blank=True)
    user_message_id = models.BigIntegerField(null=True, blank=True)
    courier_message_id = models.BigIntegerField(null=True, blank=True)

    class Meta:
        verbose_name = "Buyurtma"
        verbose_name_plural = "Buyurtmalar"
        ordering = ['-created_at']

    def __str__(self):
        return f"Buyurtma #{self.order_number} - {self.customer.full_name}"

    def save(self, *args, **kwargs):
        if not self.order_number:
            # Buyurtma raqamini avtomatik generatsiya qilish
            last_order = Order.objects.order_by('-id').first()
            if last_order:
                self.order_number = str(int(last_order.order_number) + 1)
            else:
                self.order_number = "1"
        super().save(*args, **kwargs)

class OrderItem(models.Model):
    """Buyurtma elementlari"""
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items', verbose_name="Buyurtma")
    product = models.ForeignKey(Product, on_delete=models.CASCADE, verbose_name="Mahsulot")
    quantity = models.PositiveIntegerField(verbose_name="Miqdori")
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Narxi")
    total = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Jami")

    class Meta:
        verbose_name = "Buyurtma elementi"
        verbose_name_plural = "Buyurtma elementlari"

    def __str__(self):
        return f"{self.quantity} x {self.product.name}"

    def save(self, *args, **kwargs):
        self.total = self.quantity * self.price
        super().save(*args, **kwargs)

class OrderStatusHistory(models.Model):
    """Buyurtma holati tarixi"""
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='status_history')
    old_status = models.CharField(max_length=20, verbose_name="Eski holat")
    new_status = models.CharField(max_length=20, verbose_name="Yangi holat")
    changed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="O'zgartirgan")
    changed_at = models.DateTimeField(auto_now_add=True, verbose_name="O'zgartirilgan vaqt")
    notes = models.TextField(blank=True, verbose_name="Izohlar")

    class Meta:
        verbose_name = "Holat tarixi"
        verbose_name_plural = "Holat tarixi"
        ordering = ['-changed_at']

    def __str__(self):
        return f"{self.order.order_number}: {self.old_status} -> {self.new_status}"

class BotSettings(models.Model):
    """Telegram bot sozlamalari"""
    service_start_time = models.TimeField(
        verbose_name="Xizmat boshlanish vaqti",
        default=datetime.time(10, 0),
        help_text="Bot qaysi vaqtdan buyurtma qabul qilishni boshlaydi"
    )
    service_end_time = models.TimeField(
        verbose_name="Xizmat tugash vaqti",
        default=datetime.time(22, 0),
        help_text="Bot qaysi vaqtgacha buyurtma qabul qiladi"
    )
    delivery_base_cost = models.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        default=5000,
        verbose_name="Yetkazib berish boshlang'ich narxi (so'm)",
        help_text="Har qanday masofada minimal yetkazib berish narxi",
        validators=[MinValueValidator(0)]
    )
    delivery_cost_per_extra_km_block = models.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        default=6000,
        verbose_name="Har km uchun qo'shimcha narx (so'm)",
        help_text="Birinchi kilometrdan keyin har km uchun qo'shimcha to'lov",
        validators=[MinValueValidator(0)]
    )
    delivery_max_radius_km = models.FloatField(
        default=10.0,
        verbose_name="Maksimal yetkazib berish radiusi (km)",
        help_text="Bu masofadan uzoqroqqa yetkazib berish yo'q",
        validators=[MinValueValidator(1.0), MaxValueValidator(100.0)]
    )
    broadcast_message_text = models.TextField(
        blank=True, 
        null=True,
        verbose_name="E'lon matni",
        help_text="Barcha foydalanuvchilarga yuborilishi mumkin bo'lgan e'lon matni"
    )
    last_broadcast_sent_at = models.DateTimeField(
        null=True, 
        blank=True,
        verbose_name="Oxirgi e'lon yuborilgan vaqt"
    )
    # Click to'lov sozlamalari
    click_service_id = models.CharField(max_length=50, blank=True, null=True, verbose_name="Click Service ID")
    click_merchant_id = models.CharField(max_length=50, blank=True, null=True, verbose_name="Click Merchant ID")
    click_secret_key = models.CharField(max_length=100, blank=True, null=True, verbose_name="Click Secret Key")
    # Payme to'lov sozlamalari
    payme_merchant_id = models.CharField(max_length=50, blank=True, null=True, verbose_name="Payme Merchant ID")
    payme_secret_key = models.CharField(max_length=100, blank=True, null=True, verbose_name="Payme Secret Key")

    # Bo'limlar bo'yicha Chek Printerlari Sozlamalari (IP:Port, masalan: 192.168.1.100:9100)
    printer_kassa_ip = models.CharField(max_length=60, blank=True, null=True, default="192.168.1.100:9100", verbose_name="Kassa Printeri IP", help_text="Masalan: 192.168.1.100:9100")
    printer_shashlik_ip = models.CharField(max_length=60, blank=True, null=True, default="192.168.1.101:9100", verbose_name="Shashlikchi Printeri IP", help_text="Masalan: 192.168.1.101:9100")
    printer_somsa_ip = models.CharField(max_length=60, blank=True, null=True, default="192.168.1.102:9100", verbose_name="Somsaxona Printeri IP", help_text="Masalan: 192.168.1.102:9100")
    printer_kitchen_ip = models.CharField(max_length=60, blank=True, null=True, default="192.168.1.103:9100", verbose_name="Oshxona Printeri IP", help_text="Masalan: 192.168.1.103:9100")
    printer_fastfood_ip = models.CharField(max_length=60, blank=True, null=True, default="192.168.1.104:9100", verbose_name="Fast-Food Printeri IP", help_text="Masalan: 192.168.1.104:9100")
    printer_bar_ip = models.CharField(max_length=60, blank=True, null=True, default="192.168.1.105:9100", verbose_name="Desert & Bar Printeri IP", help_text="Masalan: 192.168.1.105:9100")
    auto_print_network = models.BooleanField(default=False, verbose_name="Avtomatik tarmoq printerlariga chiqarish", help_text="Ofitsiant yoki kassa buyurtma olganda printerlarga avtomatik chek yuborish")

    # Xizmat haqi sozlamalari
    SERVICE_FEE_TYPE_CHOICES = [
        ('percent', 'Foizli (%)'),
        ('per_person', 'Odam boshiga (soʻm)'),
        ('none', 'Xizmat haqi yoʻq (0%)'),
    ]
    service_fee_type = models.CharField(max_length=20, choices=SERVICE_FEE_TYPE_CHOICES, default='percent', verbose_name="Xizmat haqi turi")
    service_fee_percent = models.DecimalField(max_digits=5, decimal_places=2, default=10.0, verbose_name="Xizmat haqi foizi (%)")
    service_fee_per_person = models.DecimalField(max_digits=10, decimal_places=2, default=5000.0, verbose_name="Odam boshiga xizmat haqi (soʻm)")

    class Meta:
        verbose_name = "Bot Sozlamalari"
        verbose_name_plural = "Bot Sozlamalari"

    def __str__(self):
        return f"Bot Sozlamalari ({self.service_start_time.strftime('%H:%M')} - {self.service_end_time.strftime('%H:%M')})"

    def save(self, *args, **kwargs):
        # Ensure only one instance exists
        if not self.pk and BotSettings.objects.exists():
            raise ValueError("Faqat bitta Bot Sozlamalari obyekti bo'lishi mumkin!")
        super().save(*args, **kwargs)

    @classmethod
    def get_settings(cls):
        """Get or create the single settings instance"""
        settings, created = cls.objects.get_or_create(
            pk=1,
            defaults={
                'service_start_time': datetime.time(10, 0),
                'service_end_time': datetime.time(22, 0),
                'delivery_base_cost': 5000,
                'delivery_cost_per_extra_km_block': 6000,
                'delivery_max_radius_km': 10.0
            }
        )
        return settings


class RestaurantTable(models.Model):
    """Restoran stollari - QR kodli elektron menyu uchun"""
    number = models.PositiveIntegerField(unique=True, verbose_name="Stol raqami")
    name = models.CharField(max_length=50, blank=True, verbose_name="Stol nomi/zali")
    capacity = models.PositiveIntegerField(default=4, verbose_name="O'rinlar soni")
    guests_count = models.PositiveIntegerField(default=0, verbose_name="Hozirgi mehmonlar")
    opened_at = models.DateTimeField(null=True, blank=True, verbose_name="Ochilgan vaqti")
    assigned_waiter = models.ForeignKey('WaiterProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_tables', verbose_name="Biriktirilgan ofitsiant")
    is_active = models.BooleanField(default=True, verbose_name="Faol")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Stol"
        verbose_name_plural = "Stollar"
        ordering = ['number']

    def __str__(self):
        return f"Stol #{self.number}" + (f" ({self.name})" if self.name else "")


class PaymentTransaction(models.Model):
    """Click / Payme to'lov tranzaksiyalari"""
    PROVIDER_CHOICES = [
        ('click', 'Click'),
        ('payme', 'Payme'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Kutilmoqda'),
        ('completed', 'Muvaffaqiyatli to\'langan'),
        ('failed', 'Xatolik'),
        ('cancelled', 'Bekor qilingan'),
    ]

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='payments', verbose_name="Buyurtma")
    provider = models.CharField(max_length=20, choices=PROVIDER_CHOICES, verbose_name="To'lov tizimi")
    transaction_id = models.CharField(max_length=100, unique=True, verbose_name="Tranzaksiya ID")
    amount = models.DecimalField(max_digits=12, decimal_places=2, verbose_name="Summa (so'm)")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending', verbose_name="Holati")
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    raw_response = models.TextField(blank=True, null=True, verbose_name="Texnik ma'lumotlar")

    class Meta:
        verbose_name = "To'lov tranzaksiyasi"
        verbose_name_plural = "To'lov tranzaksiyalari"
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.provider.upper()} #{self.transaction_id} - {self.order.order_number}: {self.status}"


class WaiterCall(models.Model):
    """Mijozlar tomonidan ofitsiant chaqirish xabarnomalari"""
    table_number = models.CharField(max_length=20, verbose_name="Stol raqami")
    reason = models.CharField(max_length=100, default="Ofitsiant kerak", verbose_name="Sabab")
    is_resolved = models.BooleanField(default=False, verbose_name="Qabul qilingan")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Vaqt")
    resolved_at = models.DateTimeField(null=True, blank=True, verbose_name="Hal qilingan vaqt")

    class Meta:
        verbose_name = "Ofitsiant chaqiruvi"
        verbose_name_plural = "Ofitsiant chaqiruvlari"
        ordering = ['-created_at']

    def __str__(self):
        return f"Stol #{self.table_number}: {self.reason} ({'Hal qilingan' if self.is_resolved else 'Kutilmoqda'})"


class WaiterProfile(models.Model):
    """Restoran ofitsiantlari profili va Telegram bot integratsiyasi"""
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="Foydalanuvchi")
    name = models.CharField(max_length=150, verbose_name="Ofitsiant ismi")
    phone = models.CharField(max_length=30, blank=True, verbose_name="Telefon raqami")
    pin_code = models.CharField(max_length=10, default="1234", verbose_name="Kirish PIN-kodi")
    telegram_id = models.BigIntegerField(null=True, blank=True, unique=True, verbose_name="Telegram Chat ID")
    auth_token = models.CharField(max_length=64, blank=True, null=True, unique=True, verbose_name="Auth Token")
    is_active = models.BooleanField(default=True, verbose_name="Smenada faol")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Ro'yxatdan o'tgan vaqt")

    class Meta:
        verbose_name = "Ofitsiant profili"
        verbose_name_plural = "Ofitsiantlar"
        ordering = ['name']

    def __str__(self):
        return f"{self.name} (ID: {self.telegram_id or 'biriktirilmagan'})"


class CourierProfile(models.Model):
    """Restoran kuryerlari profili va mobil ilova integratsiyasi"""
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="Foydalanuvchi")
    name = models.CharField(max_length=150, verbose_name="Kuryer ismi")
    phone = models.CharField(max_length=30, unique=True, verbose_name="Telefon raqami")
    pin_code = models.CharField(max_length=10, default="1234", verbose_name="Kirish PIN-kodi")
    vehicle_info = models.CharField(max_length=100, blank=True, verbose_name="Transport (Masalan: Matiz 01A123BC, Skuter)")
    is_active = models.BooleanField(default=True, verbose_name="Smenada faol")
    current_lat = models.FloatField(null=True, blank=True, verbose_name="Joriy kenglik")
    current_lng = models.FloatField(null=True, blank=True, verbose_name="Joriy uzunlik")
    auth_token = models.CharField(max_length=64, blank=True, null=True, unique=True, verbose_name="Auth Token")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Ro'yxatdan o'tgan vaqt")

    class Meta:
        verbose_name = "Kuryer profili"
        verbose_name_plural = "Kuryerlar"
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.phone}) - {'Faol' if self.is_active else 'Nofaol'}"



