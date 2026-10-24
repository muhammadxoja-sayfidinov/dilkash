import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'kitchen_system.settings')
django.setup()

from kitchen.models import Category, Product, Order, OrderItem
from django.utils import timezone
import random

def create_sample_data():
    print("Namunaviy ma'lumotlar yaratilmoqda...")
    
    # Kategoriyalarni yaratish
    categories_data = [
        {'name': 'Salatlar', 'icon': '🥗'},
        {'name': 'Sho\'rvalar', 'icon': '🍲'},
        {'name': 'Asosiy taomlar', 'icon': '🍖'},
        {'name': 'Ichimliklar', 'icon': '🥤'},
        {'name': 'Shirinliklar', 'icon': '🍰'},
    ]
    
    categories = []
    for cat_data in categories_data:
        category, created = Category.objects.get_or_create(
            name=cat_data['name'],
            defaults={'icon': cat_data['icon']}
        )
        categories.append(category)
        if created:
            print(f"Kategoriya yaratildi: {category.name}")
    
    # Mahsulotlarni yaratish
    products_data = [
        # Salatlar
        {'name': 'Sezar salati', 'category': 'Salatlar', 'price': 25000, 'description': 'Tovuq go\'shti, pomidor, bodring bilan', 'prep_time': 10},
        {'name': 'Yunon salati', 'category': 'Salatlar', 'price': 22000, 'description': 'Pishloq, zaytun, pomidor bilan', 'prep_time': 8},
        {'name': 'Olivye salati', 'category': 'Salatlar', 'price': 18000, 'description': 'An\'anaviy rus salati', 'prep_time': 12},
        
        # Sho'rvalar
        {'name': 'Borsh', 'category': 'Sho\'rvalar', 'price': 20000, 'description': 'Qizil lavlagi bilan tayyorlangan sho\'rva', 'prep_time': 15},
        {'name': 'Solyanka', 'category': 'Sho\'rvalar', 'price': 24000, 'description': 'Go\'sht va kolbasa bilan', 'prep_time': 18},
        {'name': 'Tovuq sho\'rvasi', 'category': 'Sho\'rvalar', 'price': 16000, 'description': 'Sabzavotli tovuq sho\'rvasi', 'prep_time': 20},
        
        # Asosiy taomlar
        {'name': 'Bifshteks', 'category': 'Asosiy taomlar', 'price': 45000, 'description': 'Mol go\'shti bifshteksi', 'prep_time': 25},
        {'name': 'Tovuq kotleti', 'category': 'Asosiy taomlar', 'price': 28000, 'description': 'Qovurilgan tovuq kotleti', 'prep_time': 20},
        {'name': 'Baliq filesi', 'category': 'Asosiy taomlar', 'price': 35000, 'description': 'Dengiz baligi filesi', 'prep_time': 18},
        {'name': 'Palov', 'category': 'Asosiy taomlar', 'price': 30000, 'description': 'O\'zbek milliy taomi', 'prep_time': 40},
        
        # Ichimliklar
        {'name': 'Choy', 'category': 'Ichimliklar', 'price': 5000, 'description': 'Qora yoki ko\'k choy', 'prep_time': 3},
        {'name': 'Kofe', 'category': 'Ichimliklar', 'price': 8000, 'description': 'Amerikano yoki kapuchino', 'prep_time': 5},
        {'name': 'Sharbat', 'category': 'Ichimliklar', 'price': 12000, 'description': 'Tabiiy mevali sharbat', 'prep_time': 2},
        
        # Shirinliklar
        {'name': 'Tiramisu', 'category': 'Shirinliklar', 'price': 18000, 'description': 'Italyan deserti', 'prep_time': 5},
        {'name': 'Cheesecake', 'category': 'Shirinliklar', 'price': 16000, 'description': 'Pishloqli tort', 'prep_time': 5},
        {'name': 'Muzqaymoq', 'category': 'Shirinliklar', 'price': 10000, 'description': 'Turli xil ta\'mlar', 'prep_time': 2},
    ]
    
    products = []
    for prod_data in products_data:
        category = Category.objects.get(name=prod_data['category'])
        product, created = Product.objects.get_or_create(
            name=prod_data['name'],
            category=category,
            defaults={
                'price': prod_data['price'],
                'description': prod_data['description'],
                'preparation_time': prod_data['prep_time'],
                'is_available': random.choice([True, True, True, False])  # 75% mavjud
            }
        )
        products.append(product)
        if created:
            print(f"Mahsulot yaratildi: {product.name}")
    
    # Namunaviy buyurtmalar yaratish
    customers = [
        {'name': 'Alisher Karimov', 'phone': '+998901234567'},
        {'name': 'Malika Tosheva', 'phone': '+998902345678'},
        {'name': 'Bobur Rahimov', 'phone': '+998903456789'},
        {'name': 'Nilufar Saidova', 'phone': '+998904567890'},
        {'name': 'Jasur Umarov', 'phone': '+998905678901'},
    ]
    
    statuses = ['yangi', 'tasdiqlangan', 'tayyorlanmoqda', 'tayyor', 'yetkazildi']
    
    for i in range(10):
        customer = random.choice(customers)
        status = random.choice(statuses)
        
        order = Order.objects.create(
            order_id=f"ORD{1000 + i}",
            customer_name=customer['name'],
            customer_phone=customer['phone'],
            status=status,
            address=f"Toshkent shahar, {i+1}-ko'cha, {random.randint(1, 100)}-uy",
            payment_method=random.choice(['naqd', 'karta']),
            total_amount=0,
            created_at=timezone.now() - timezone.timedelta(hours=random.randint(0, 48))
        )
        
        # Buyurtma elementlarini yaratish
        total_amount = 0
        num_items = random.randint(1, 4)
        selected_products = random.sample(products, num_items)
        
        for product in selected_products:
            quantity = random.randint(1, 3)
            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=quantity,
                price=product.price
            )
            total_amount += product.price * quantity
        
        order.total_amount = total_amount
        order.save()
        
        print(f"Buyurtma yaratildi: #{order.order_id} - {order.customer_name}")
    
    print("Namunaviy ma'lumotlar muvaffaqiyatli yaratildi!")

if __name__ == '__main__':
    create_sample_data()
