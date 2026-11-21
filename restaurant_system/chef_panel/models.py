from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from django.core.validators import MinValueValidator, MaxValueValidator
from decimal import Decimal
import datetime
import hashlib
import mimetypes

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
    parent = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='subcategories',
        verbose_name="Yuqori kategoriya",
    )
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
    image_blob = models.BinaryField(blank=True, null=True, editable=False, verbose_name="Rasm (Baza kesh)")
    image_mime = models.CharField(max_length=50, blank=True, default='', editable=False)
    image_hash = models.CharField(max_length=32, blank=True, default='', editable=False)
    is_available = models.BooleanField(default=True, verbose_name="Mavjud")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Mahsulot"
        verbose_name_plural = "Mahsulotlar"
        ordering = ['category', 'name']

    def __str__(self):
        return f"{self.name} - {self.price:,} so'm"

    def set_image_bytes(self, raw_bytes: bytes, filename: str = "dish.jpg"):
        if not raw_bytes:
            self.image_blob = None
            self.image_mime = ''
            self.image_hash = ''
            return
        mime, _ = mimetypes.guess_type(filename or "dish.jpg")
        self.image_blob = raw_bytes
        self.image_mime = mime or 'image/jpeg'
        self.image_hash = hashlib.md5(raw_bytes).hexdigest()

    def clear_image_data(self):
        if self.image:
            try:
                self.image.delete(save=False)
            except Exception:
                pass
        self.image = None
        self.image_blob = None
        self.image_mime = ''
        self.image_hash = ''

    def sync_image_blob_from_field(self):
        if not self.image:
            return False
        try:
            if not self.image.storage.exists(self.image.name):
                return False
            with self.image.storage.open(self.image.name, 'rb') as f:
                raw = f.read()
            if raw:
                new_hash = hashlib.md5(raw).hexdigest()
                if new_hash != self.image_hash or not self.image_blob:
                    self.set_image_bytes(raw, self.image.name)
                    return True
        except Exception:
            pass
        return False

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        if self.image:
            if self.sync_image_blob_from_field():
                Product.objects.filter(pk=self.pk).update(
                    image_blob=self.image_blob,
                    image_mime=self.image_mime,
                    image_hash=self.image_hash,
                )

    def get_department(self):
        # 1. Asosiy: Menyudagi Kategoriya bo'limi
        if self.category:
            cat_dept = self.category.get_department()
            if cat_dept in ['kitchen', 'shashlik', 'somsa', 'fastfood', 'bar', 'kassa']:
                return cat_dept
        # 2. Agar kategoriya bo'lmasa, nomidan aniqlash
        return Category.infer_department(self.name)

    def get_recipe_cost(self):
        """Tex-karta bo'yicha 1 porsiya taomning hisoblangan tannarxi"""
        total = Decimal('0.00')
        for item in self.recipe_items.select_related('ingredient').all():
            total += item.get_cost()
        return total

    def get_profit_margin(self):
        """1 porsiya taomdan olinadigan yalpi foyda (so'mda)"""
        cost = self.get_recipe_cost()
        return max(Decimal('0.00'), (self.price or Decimal('0.00')) - cost)

    def get_margin_percent(self):
        """Foyda marjasi (foizda)"""
        cost = self.get_recipe_cost()
        if not self.price or self.price <= 0:
            return 0.0
        return round(float((self.price - cost) / self.price * 100), 1)

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


class Hall(models.Model):
    """Restoran zallari (Asosiy zal, Terrasa, VIP va boshqalar)"""
    name = models.CharField(max_length=100, unique=True, verbose_name="Zal nomi")
    description = models.TextField(blank=True, verbose_name="Tavsif")
    sort_order = models.PositiveIntegerField(default=0, verbose_name="Tartib raqami")
    is_active = models.BooleanField(default=True, verbose_name="Faol")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Zal"
        verbose_name_plural = "Zallar"
        ordering = ['sort_order', 'id']

    def __str__(self):
        return self.name


class RestaurantTable(models.Model):
    """Restoran stollari - QR kodli elektron menyu uchun"""
    number = models.PositiveIntegerField(unique=True, verbose_name="Stol raqami")
    name = models.CharField(max_length=50, blank=True, verbose_name="Stol nomi/zali")
    hall = models.ForeignKey(Hall, on_delete=models.SET_NULL, null=True, blank=True, related_name='tables', verbose_name="Zal")
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


class PrinterDevice(models.Model):
    """Tarmoq chek printerlari (bo'limlar va kassa uchun qo'shish/tahrirlash/o'chirish)"""
    name = models.CharField(max_length=100, verbose_name="Printer nomi")
    department = models.CharField(max_length=30, default='kitchen', verbose_name="Bo'lim kodi")
    ip_address = models.CharField(max_length=100, blank=True, verbose_name="IP manzili")
    port = models.PositiveIntegerField(default=9100, verbose_name="Port")
    paper_width = models.PositiveIntegerField(default=80, verbose_name="Qog'oz kengligi (mm)")
    subtitle = models.CharField(max_length=150, blank=True, verbose_name="Tavsif")
    is_active = models.BooleanField(default=True, verbose_name="Faol")
    sort_order = models.PositiveIntegerField(default=0, verbose_name="Tartib")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Printer"
        verbose_name_plural = "Printerlar"
        ordering = ['sort_order', 'id']

    def effective_address(self):
        ip = (self.ip_address or '').strip()
        if not ip:
            return ''
        if ':' in ip:
            return ip
        return f"{ip}:{self.port or 9100}"

    def __str__(self):
        return f"{self.name} ({self.department}) - {self.effective_address()}"


class CashierProfile(models.Model):
    """Kassir profili va shaxsiy kassa sozlamalari"""
    name = models.CharField(max_length=150, default="Jasur Rahimov", verbose_name="Kassir ismi")
    phone = models.CharField(max_length=30, blank=True, default="", verbose_name="Telefon raqami")
    role_title = models.CharField(max_length=80, default="Bosh kassir", verbose_name="Lavozim")
    pin_code = models.CharField(max_length=20, default="1234", verbose_name="PIN-kod")
    avatar_color = models.CharField(max_length=20, default="#10B981", verbose_name="Avatar rangi")
    require_pin_on_unlock = models.BooleanField(default=False, verbose_name="Qulfdan chiqishda PIN so'rash")
    notification_sound = models.BooleanField(default=True, verbose_name="Ovozli bildirishnoma")
    is_active = models.BooleanField(default=True, verbose_name="Faol")
    is_primary = models.BooleanField(default=True, verbose_name="Asosiy kassir")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Kassir profili"
        verbose_name_plural = "Kassir profillari"
        ordering = ['-is_primary', 'id']

    @classmethod
    def get_primary(cls):
        obj = cls.objects.filter(is_active=True).order_by('-is_primary', 'id').first()
        if obj:
            return obj
        return cls.objects.create(
            name="Jasur Rahimov",
            phone="+998901112233",
            role_title="Bosh kassir",
            pin_code="1234",
            is_primary=True,
            is_active=True,
        )

    def __str__(self):
        return f"{self.name} ({self.role_title})"


# ==============================================================================
# OMBORXONA VA KALKULYATSIYA MODELLARI (INVENTORY & RECIPE MANAGEMENT)
# ==============================================================================

def convert_unit_quantity(qty: Decimal, from_unit: str, to_unit: str) -> Decimal:
    """O'lchov birliklari o'rtasida miqdorni konvertatsiya qilish (g <-> kg, ml <-> l)."""
    if from_unit == to_unit:
        return qty
    if from_unit == 'g' and to_unit == 'kg':
        return qty / Decimal('1000')
    if from_unit == 'kg' and to_unit == 'g':
        return qty * Decimal('1000')
    if from_unit == 'ml' and to_unit == 'l':
        return qty / Decimal('1000')
    if from_unit == 'l' and to_unit == 'ml':
        return qty * Decimal('1000')
    return qty


class Ingredient(models.Model):
    """Ombordagi xomashyo va mahsulotlar"""
    CATEGORY_CHOICES = [
        ('meat', "Goʻsht va parranda"),
        ('vegetables', "Sabzavot va koʻkatlar"),
        ('groceries', "Quruq oziq-ovqat va un"),
        ('beverages', "Ichimliklar va bar"),
        ('spices', "Ziravorlar va souslar"),
        ('dairy', "Sut va yogʻ mahsulotlari"),
        ('packaging', "Qadoq va bir martalik idishlar"),
        ('other', "Boshqa"),
    ]

    UNIT_CHOICES = [
        ('kg', "Kilogramm (kg)"),
        ('g', "Gramm (g)"),
        ('l', "Litr (l)"),
        ('ml', "Millilitr (ml)"),
        ('pcs', "Dona (dona)"),
        ('portion', "Porsiya (por)"),
    ]

    name = models.CharField(max_length=150, verbose_name="Xomashyo / Mahsulot nomi")
    category = models.CharField(max_length=40, choices=CATEGORY_CHOICES, default='groceries', verbose_name="Toifasi")
    unit = models.CharField(max_length=20, choices=UNIT_CHOICES, default='kg', verbose_name="Oʻlchov birligi")
    current_stock = models.DecimalField(max_digits=12, decimal_places=3, default=Decimal('0.000'), verbose_name="Joriy qoldiq")
    min_stock_alert = models.DecimalField(max_digits=12, decimal_places=3, default=Decimal('5.000'), verbose_name="Minimal qoldiq chegarasi")
    cost_price = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), verbose_name="1 birlik tannarxi (soʻm)")
    description = models.TextField(blank=True, default="", verbose_name="Tavsif")
    is_active = models.BooleanField(default=True, verbose_name="Faol")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Xomashyo / Mahsulot"
        verbose_name_plural = "Ombor: Xomashyolar"
        ordering = ['category', 'name']

    def __str__(self):
        return f"{self.name} ({self.current_stock:g} {self.unit})"

    @property
    def is_low_stock(self) -> bool:
        """Qoldiq xavfsiz minimal miqdordan kam qolganmi"""
        return self.current_stock <= self.min_stock_alert

    @property
    def total_valuation(self) -> Decimal:
        """Ushbu mahsulot qoldigʻining umumiy qiymati (soʻmda)"""
        if self.current_stock <= 0:
            return Decimal('0.00')
        return round(self.current_stock * self.cost_price, 2)


class Supplier(models.Model):
    """Yetkazib beruvchilar (Ta'minotchilar)"""
    name = models.CharField(max_length=150, verbose_name="Taʼminotchi / Korxona nomi")
    phone = models.CharField(max_length=40, blank=True, default="", verbose_name="Telefon raqami")
    contact_person = models.CharField(max_length=100, blank=True, default="", verbose_name="Masʼul shaxs")
    address = models.CharField(max_length=255, blank=True, default="", verbose_name="Manzil")
    balance = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'), verbose_name="Balans (soʻm)", help_text="Musbat: bizning qarzimiz, Manfiy: ularning qarzi")
    notes = models.TextField(blank=True, default="", verbose_name="Izohlar")
    is_active = models.BooleanField(default=True, verbose_name="Faol")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Yetkazib beruvchi"
        verbose_name_plural = "Ombor: Yetkazib beruvchilar"
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.phone or 'Tel yoʻq'})"


class StockSupply(models.Model):
    """Kirim hujjati (Приход)"""
    PAYMENT_CHOICES = [
        ('paid', "Toʻlangan"),
        ('partial', "Qisman toʻlangan"),
        ('debt', "Nasiya / Qarz"),
    ]

    doc_number = models.CharField(max_length=40, unique=True, verbose_name="Hujjat raqami")
    supplier = models.ForeignKey(Supplier, on_delete=models.SET_NULL, null=True, blank=True, related_name='supplies', verbose_name="Taʼminotchi")
    date = models.DateTimeField(default=timezone.now, verbose_name="Kirim sanasi")
    total_cost = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'), verbose_name="Jami summa (soʻm)")
    payment_status = models.CharField(max_length=20, choices=PAYMENT_CHOICES, default='paid', verbose_name="Toʻlov holati")
    paid_amount = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'), verbose_name="Toʻlangan summa (soʻm)")
    notes = models.TextField(blank=True, default="", verbose_name="Izoh")
    created_by = models.CharField(max_length=100, default="Kassir", verbose_name="Kiritgan xodim")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Kirim hujjati"
        verbose_name_plural = "Ombor: Kirim hujjatlari"
        ordering = ['-date', '-id']

    def __str__(self):
        return f"{self.doc_number} ({self.total_cost:,} soʻm)"


class StockSupplyItem(models.Model):
    """Kirim hujjati tarkibidagi tovarlar"""
    supply = models.ForeignKey(StockSupply, on_delete=models.CASCADE, related_name='items', verbose_name="Kirim hujjati")
    ingredient = models.ForeignKey(Ingredient, on_delete=models.PROTECT, related_name='supply_items', verbose_name="Xomashyo")
    quantity = models.DecimalField(max_digits=12, decimal_places=3, verbose_name="Kirim miqdori")
    unit_price = models.DecimalField(max_digits=12, decimal_places=2, verbose_name="1 birlik narxi (soʻm)")
    total_price = models.DecimalField(max_digits=14, decimal_places=2, verbose_name="Jami narxi (soʻm)")

    class Meta:
        verbose_name = "Kirim tovari"
        verbose_name_plural = "Kirim tovarlari"

    def __str__(self):
        return f"{self.ingredient.name}: {self.quantity:g} x {self.unit_price:,} = {self.total_price:,} soʻm"


class StockWriteOff(models.Model):
    """Chiqim hujjati (Списание)"""
    REASON_CHOICES = [
        ('spoilage', "Yaroqsiz / Aynigan"),
        ('staff_meal', "Xodimlar tushligi"),
        ('loss', "Yoʻqotish / Kamomad"),
        ('cooking_loss', "Ishlov berishdagi yoʻqotish"),
        ('other', "Boshqa"),
    ]

    doc_number = models.CharField(max_length=40, unique=True, verbose_name="Chiqim raqami")
    date = models.DateTimeField(default=timezone.now, verbose_name="Chiqim sanasi")
    reason = models.CharField(max_length=30, choices=REASON_CHOICES, default='spoilage', verbose_name="Chiqim sababi")
    total_cost = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'), verbose_name="Jami chiqim tannarxi")
    notes = models.TextField(blank=True, default="", verbose_name="Izoh")
    created_by = models.CharField(max_length=100, default="Kassir", verbose_name="Kiritgan xodim")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Chiqim hujjati"
        verbose_name_plural = "Ombor: Chiqim hujjatlari"
        ordering = ['-date', '-id']

    def __str__(self):
        return f"{self.doc_number} ({self.get_reason_display()})"


class StockWriteOffItem(models.Model):
    """Chiqim hujjati tarkibi"""
    write_off = models.ForeignKey(StockWriteOff, on_delete=models.CASCADE, related_name='items', verbose_name="Chiqim hujjati")
    ingredient = models.ForeignKey(Ingredient, on_delete=models.PROTECT, related_name='write_off_items', verbose_name="Xomashyo")
    quantity = models.DecimalField(max_digits=12, decimal_places=3, verbose_name="Chiqim miqdori")
    unit_cost = models.DecimalField(max_digits=12, decimal_places=2, verbose_name="1 birlik tannarxi")
    total_cost = models.DecimalField(max_digits=14, decimal_places=2, verbose_name="Jami tannarx")

    class Meta:
        verbose_name = "Chiqim tovari"
        verbose_name_plural = "Chiqim tovarlari"

    def __str__(self):
        return f"{self.ingredient.name}: {self.quantity:g} ({self.total_cost:,} soʻm)"


class RecipeItem(models.Model):
    """Taomning texnologik xaritasi (Kalkulyatsiya tarkibi)"""
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='recipe_items', verbose_name="Taom")
    ingredient = models.ForeignKey(Ingredient, on_delete=models.PROTECT, related_name='recipe_usages', verbose_name="Xomashyo")
    quantity = models.DecimalField(max_digits=12, decimal_places=3, verbose_name="Miqdori (1 porsiya uchun)")
    unit = models.CharField(max_length=20, choices=Ingredient.UNIT_CHOICES, default='kg', verbose_name="Oʻlchov birligi")
    notes = models.CharField(max_length=255, blank=True, default="", verbose_name="Izoh / Tayyorlash eslatmasi")

    class Meta:
        verbose_name = "Tex-karta moddasi"
        verbose_name_plural = "Tex-karta moddalari"
        unique_together = ['product', 'ingredient']
        ordering = ['product', 'ingredient']

    def __str__(self):
        return f"{self.product.name} <- {self.ingredient.name} ({self.quantity:g} {self.unit})"

    def get_ingredient_quantity(self) -> Decimal:
        """Retsept miqdorini ingredientning asosiy oʻlchov birligiga oʻtkazish"""
        return convert_unit_quantity(self.quantity, self.unit, self.ingredient.unit)

    def get_cost(self) -> Decimal:
        """1 porsiya taomga ketadigan ushbu xomashyo tannarxi"""
        needed_qty = self.get_ingredient_quantity()
        return round(needed_qty * (self.ingredient.cost_price or Decimal('0.00')), 2)


class StockMovementLog(models.Model):
    """Ombor harakatlari jurnali (Audit trail)"""
    MOVEMENT_CHOICES = [
        ('supply', "Kirim (Приход)"),
        ('sale_deduction', "Sotuv chiqimi (Avtomatik)"),
        ('write_off', "Qoʻlda chiqim (Списание)"),
        ('adjustment', "Qayta hisob (Inventarizatsiya)"),
    ]

    ingredient = models.ForeignKey(Ingredient, on_delete=models.CASCADE, related_name='movements', verbose_name="Xomashyo")
    movement_type = models.CharField(max_length=30, choices=MOVEMENT_CHOICES, verbose_name="Harakat turi")
    quantity_delta = models.DecimalField(max_digits=12, decimal_places=3, verbose_name="Oʻzgarish (+ kirim / - chiqim)")
    stock_before = models.DecimalField(max_digits=12, decimal_places=3, verbose_name="Harakatdan oldingi qoldiq")
    stock_after = models.DecimalField(max_digits=12, decimal_places=3, verbose_name="Harakatdan keyingi qoldiq")
    unit_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), verbose_name="Birlik tannarxi")
    related_order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True, related_name='stock_deductions', verbose_name="Bogʻlangan buyurtma")
    related_supply = models.ForeignKey(StockSupply, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="Bogʻlangan kirim")
    related_write_off = models.ForeignKey(StockWriteOff, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="Bogʻlangan chiqim")
    notes = models.CharField(max_length=255, blank=True, default="", verbose_name="Tafsilot")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Vaqti")

    class Meta:
        verbose_name = "Harakat jurnali yozuvi"
        verbose_name_plural = "Ombor: Harakatlar jurnali"
        ordering = ['-created_at', '-id']

    def __str__(self):
        return f"{self.created_at:%Y-%m-%d %H:%M} | {self.ingredient.name} | {self.quantity_delta:+g} ({self.get_movement_type_display()})"


def process_order_inventory_deduction(order, cashier_name: str = "POS"):
    """
    Buyurtma boʻyicha taomlarning retseptlariga koʻra ombordan xomashyolarni avtomatik hisobdan chiqarish.
    Bir xil buyurtma uchun takroran chiqim qilinmasligi tekshiriladi.
    """
    if not order or not getattr(order, 'id', None):
        return []

    # Bir xil buyurtma uchun avval chiqim qilinganmi?
    if StockMovementLog.objects.filter(related_order=order).exists():
        return []

    logs = []
    for item in order.items.select_related('product').all():
        product = item.product
        order_qty = Decimal(str(item.quantity))
        recipe_items = product.recipe_items.select_related('ingredient').all()

        if recipe_items.exists():
            for r_item in recipe_items:
                ingredient = r_item.ingredient
                needed_qty = r_item.get_ingredient_quantity() * order_qty

                stock_before = ingredient.current_stock
                stock_after = stock_before - needed_qty

                ingredient.current_stock = stock_after
                ingredient.save(update_fields=['current_stock', 'updated_at'])

                log = StockMovementLog.objects.create(
                    ingredient=ingredient,
                    movement_type='sale_deduction',
                    quantity_delta=-needed_qty,
                    stock_before=stock_before,
                    stock_after=stock_after,
                    unit_cost=ingredient.cost_price,
                    related_order=order,
                    notes=f"Sotuv: {item.quantity} x {product.name} (Retsept)",
                )
                logs.append(log)
        else:
            # Agar alohida tex-karta bo'lmasa, lekin to'g'ridan-to'g'ri nomdosh ingredient bo'lsa (masalan: Coca-Cola 1.5L)
            direct_ing = Ingredient.objects.filter(name__iexact=product.name, is_active=True).first()
            if direct_ing:
                stock_before = direct_ing.current_stock
                stock_after = stock_before - order_qty

                direct_ing.current_stock = stock_after
                direct_ing.save(update_fields=['current_stock', 'updated_at'])

                log = StockMovementLog.objects.create(
                    ingredient=direct_ing,
                    movement_type='sale_deduction',
                    quantity_delta=-order_qty,
                    stock_before=stock_before,
                    stock_after=stock_after,
                    unit_cost=direct_ing.cost_price,
                    related_order=order,
                    notes=f"Sotuv: {item.quantity} x {product.name} (1:1 tovar)",
                )
                logs.append(log)

    return logs


class WaiterFeedback(models.Model):
    """Mijoz tomonidan QR chek/stol orqali ofitsiantga berilgan maxfiy baho (faqat POS va ma'muriyat ko'radi)"""
    waiter = models.ForeignKey('WaiterProfile', on_delete=models.CASCADE, related_name='feedbacks', verbose_name="Ofitsiant")
    waiter_name = models.CharField(max_length=150, blank=True, verbose_name="Ofitsiant ismi")
    table_number = models.CharField(max_length=20, verbose_name="Stol raqami")
    order = models.ForeignKey('Order', on_delete=models.SET_NULL, null=True, blank=True, related_name='waiter_feedbacks', verbose_name="Buyurtma")
    rating = models.PositiveSmallIntegerField(default=5, verbose_name="Baho (1-5 yulduz)")
    comment = models.TextField(blank=True, default="", verbose_name="Mijoz izohi / fikri")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Baholangan vaqt")

    class Meta:
        verbose_name = "Ofitsiant bahosi (Maxfiy)"
        verbose_name_plural = "Ofitsiantlar baholari (Maxfiy)"
        ordering = ['-created_at', '-id']

    def __str__(self):
        return f"Stol #{self.table_number} | {self.waiter_name} | {self.rating}★"


class DishFeedback(models.Model):
    """Mijoz tomonidan QR chek/stol orqali aytilgan taomga berilgan baho"""
    product = models.ForeignKey('Product', on_delete=models.CASCADE, related_name='feedbacks', verbose_name="Taom")
    product_name = models.CharField(max_length=150, blank=True, verbose_name="Taom nomi")
    table_number = models.CharField(max_length=20, verbose_name="Stol raqami")
    order = models.ForeignKey('Order', on_delete=models.SET_NULL, null=True, blank=True, related_name='dish_feedbacks', verbose_name="Buyurtma")
    rating = models.PositiveSmallIntegerField(default=5, verbose_name="Baho (1-5 yulduz)")
    comment = models.TextField(blank=True, default="", verbose_name="Mijoz izohi")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Baholangan vaqt")

    class Meta:
        verbose_name = "Taom bahosi"
        verbose_name_plural = "Taomlar baholari"
        ordering = ['-created_at', '-id']

    def __str__(self):
        return f"Stol #{self.table_number} | {self.product_name} | {self.rating}★"


class StaffNotification(models.Model):
    """Xodimlar (Kuryer va Ofitsiantlar) uchun tizim va buyurtma xabarnomalari / DeepLinklar"""
    NOTIFICATION_TYPES = [
        ('delivery_offer', "Dastavka buyurtmasi taklifi"),
        ('order_assigned', "Buyurtma biriktirildi"),
        ('waiter_call', "Ofitsiant chaqiruvi"),
        ('system_alert', "Tizim xabari"),
    ]

    phone = models.CharField(max_length=30, db_index=True, verbose_name="Xodim telefoni")
    waiter = models.ForeignKey('WaiterProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='notifications', verbose_name="Ofitsiant")
    courier = models.ForeignKey('CourierProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='notifications', verbose_name="Kuryer")
    order = models.ForeignKey('Order', on_delete=models.CASCADE, null=True, blank=True, related_name='staff_notifications', verbose_name="Buyurtma")

    title = models.CharField(max_length=200, verbose_name="Sarlavha")
    message = models.TextField(verbose_name="Xabar matni")
    notification_type = models.CharField(max_length=30, choices=NOTIFICATION_TYPES, default='delivery_offer', verbose_name="Turi")
    deeplink = models.CharField(max_length=255, blank=True, default="", verbose_name="DeepLink URL")

    is_dual_role_prompt = models.BooleanField(default=False, verbose_name="2 rollik ofitsiant uchun taklif")
    is_read = models.BooleanField(default=False, verbose_name="O'qilgan")
    is_accepted = models.BooleanField(null=True, blank=True, verbose_name="Qabul qilinganmi (True/False/None)")

    created_at = models.DateTimeField(auto_now_add=True, db_index=True, verbose_name="Yaratilgan vaqt")
    expires_at = models.DateTimeField(null=True, blank=True, verbose_name="Amal qilish muddati")

    class Meta:
        verbose_name = "Xodim xabarnomasi"
        verbose_name_plural = "Xodimlar xabarnomalari"
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.phone} - {self.title} ({self.created_at.strftime('%H:%M')})"






