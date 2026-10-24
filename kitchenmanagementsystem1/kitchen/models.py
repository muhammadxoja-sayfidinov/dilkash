from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone

class Category(models.Model):
  name = models.CharField(max_length=100, verbose_name="Kategoriya nomi")
  icon = models.CharField(max_length=50, default="🍽️", verbose_name="Ikonka")
  is_active = models.BooleanField(default=True, verbose_name="Faol")
  created_at = models.DateTimeField(auto_now_add=True)
  
  class Meta:
      verbose_name = "Kategoriya"
      verbose_name_plural = "Kategoriyalar"
      ordering = ['name']
  
  def __str__(self):
      return self.name

class Product(models.Model):
  name = models.CharField(max_length=200, verbose_name="Mahsulot nomi")
  category = models.ForeignKey(Category, on_delete=models.CASCADE, verbose_name="Kategoriya")
  price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Narxi")
  description = models.TextField(blank=True, verbose_name="Tavsif")
  image = models.ImageField(upload_to='products/', blank=True, verbose_name="Rasm")
  is_available = models.BooleanField(default=True, verbose_name="Mavjud")
  preparation_time = models.IntegerField(default=15, verbose_name="Tayyorlash vaqti (daqiqa)")
  created_at = models.DateTimeField(auto_now_add=True)
  
  class Meta:
      verbose_name = "Mahsulot"
      verbose_name_plural = "Mahsulotlar"
      ordering = ['category', 'name']
  
  def __str__(self):
      return f"{self.name} - {self.price} so'm"

class Order(models.Model):
  STATUS_CHOICES = [
      ('yangi', '🆕 Yangi'),
      ('tasdiqlangan', '✅ Tasdiqlangan'),
      ('tayyorlanmoqda', '👨‍🍳 Tayyorlanmoqda'),
      ('tayyor', '🍽️ Tayyor'),
      ('yetkazildi', '🚚 Yetkazildi'),
      ('bekor', '❌ Bekor qilingan'),
  ]
  
  order_id = models.CharField(max_length=20, unique=True, verbose_name="Buyurtma ID")
  customer_name = models.CharField(max_length=200, verbose_name="Mijoz ismi")
  customer_phone = models.CharField(max_length=20, verbose_name="Telefon")
  total_amount = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Umumiy summa")
  status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='yangi', verbose_name="Holat")
  address = models.TextField(blank=True, null=True, verbose_name="Manzil")
  payment_method = models.CharField(max_length=50, default='naqd', verbose_name="To'lov usuli")
  created_at = models.DateTimeField(auto_now_add=True, verbose_name="Yaratilgan vaqt")
  updated_at = models.DateTimeField(auto_now=True, verbose_name="Yangilangan vaqt")
  estimated_time = models.DateTimeField(null=True, blank=True, verbose_name="Taxminiy vaqt")
  telegram_user_id = models.CharField(max_length=50, blank=True, null=True, verbose_name="Telegram User ID")
  
  class Meta:
      verbose_name = "Buyurtma"
      verbose_name_plural = "Buyurtmalar"
      ordering = ['-created_at']
  
  def __str__(self):
      return f"Buyurtma #{self.order_id} - {self.customer_name}"
  
  def get_status_display_with_icon(self):
      return dict(self.STATUS_CHOICES)[self.status]

class OrderItem(models.Model):
  order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items', verbose_name="Buyurtma")
  product = models.ForeignKey(Product, on_delete=models.CASCADE, verbose_name="Mahsulot")
  quantity = models.PositiveIntegerField(verbose_name="Miqdor")
  price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Narx")
  
  class Meta:
      verbose_name = "Buyurtma elementi"
      verbose_name_plural = "Buyurtma elementlari"
  
  def __str__(self):
      return f"{self.product.name} x {self.quantity}"
  
  @property
  def total_price(self):
      return self.quantity * self.price
