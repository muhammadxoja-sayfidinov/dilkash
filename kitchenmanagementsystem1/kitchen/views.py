from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from django.db.models import Q
from .models import Order, Product, Category, OrderItem
from .forms import ProductForm
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
import json

def kitchen_dashboard(request):
    """Oshxona bosh sahifasi"""
    new_orders_count = Order.objects.filter(status='yangi').count()
    preparing_orders_count = Order.objects.filter(status='tayyorlanmoqda').count()
    ready_orders_count = Order.objects.filter(status='tayyor').count()
    
    recent_orders = Order.objects.filter(
        status__in=['yangi', 'tasdiqlangan', 'tayyorlanmoqda']
    ).order_by('-created_at')[:10]
    
    context = {
        'new_orders_count': new_orders_count,
        'preparing_orders_count': preparing_orders_count,
        'ready_orders_count': ready_orders_count,
        'recent_orders': recent_orders,
    }
    return render(request, 'kitchen/dashboard.html', context)

def orders_list(request):
    """Buyurtmalar ro'yxati"""
    status_filter = request.GET.get('status', 'all')
    
    orders = Order.objects.all().order_by('-created_at')
    
    if status_filter != 'all':
        orders = orders.filter(status=status_filter)
    
    context = {
        'orders': orders,
        'status_filter': status_filter,
        'status_choices': Order.STATUS_CHOICES,
    }
    return render(request, 'kitchen/orders_list.html', context)

def order_detail(request, order_id):
    """Buyurtma tafsilotlari"""
    order = get_object_or_404(Order, order_id=order_id)
    order_items = OrderItem.objects.filter(order=order)
    
    context = {
        'order': order,
        'order_items': order_items,
        'status_choices': Order.STATUS_CHOICES,
    }
    return render(request, 'kitchen/order_detail.html', context)

def products_list(request):
    """Mahsulotlar ro'yxati"""
    category_filter = request.GET.get('category', 'all')
    
    products = Product.objects.all().order_by('category', 'name')
    categories = Category.objects.filter(is_active=True)
    
    if category_filter != 'all':
        products = products.filter(category_id=category_filter)
    
    context = {
        'products': products,
        'categories': categories,
        'category_filter': category_filter,
    }
    return render(request, 'kitchen/products_list.html', context)

def add_product(request):
    """Yangi mahsulot qo'shish"""
    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES)
        if form.is_valid():
            product = form.save()
            messages.success(request, f"{product.name} muvaffaqiyatli qo'shildi!")
            
            # WebSocket orqali yangilanishni yuborish
            channel_layer = get_channel_layer()
            async_to_sync(channel_layer.group_send)(
                'kitchen_orders',
                {
                    'type': 'product_update',
                    'product_id': product.id,
                    'is_available': product.is_available,
                    'message': f"Yangi mahsulot qo'shildi: {product.name}"
                }
            )
            
            return redirect('kitchen:products_list')
    else:
        form = ProductForm()
    
    context = {
        'form': form,
        'title': 'Yangi mahsulot qo\'shish'
    }
    return render(request, 'kitchen/product_form.html', context)

def edit_product(request, product_id):
    """Mahsulotni tahrirlash"""
    product = get_object_or_404(Product, id=product_id)
    
    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES, instance=product)
        if form.is_valid():
            product = form.save()
            messages.success(request, f"{product.name} muvaffaqiyatli yangilandi!")
            
            # WebSocket orqali yangilanishni yuborish
            channel_layer = get_channel_layer()
            async_to_sync(channel_layer.group_send)(
                'kitchen_orders',
                {
                    'type': 'product_update',
                    'product_id': product.id,
                    'is_available': product.is_available,
                    'message': f"Mahsulot yangilandi: {product.name}"
                }
            )
            
            return redirect('kitchen:products_list')
    else:
        form = ProductForm(instance=product)
    
    context = {
        'form': form,
        'product': product,
        'title': 'Mahsulotni tahrirlash'
    }
    return render(request, 'kitchen/product_form.html', context)

def delete_product(request, product_id):
    """Mahsulotni o'chirish"""
    product = get_object_or_404(Product, id=product_id)
    
    if request.method == 'POST':
        product_name = product.name
        product.delete()
        messages.success(request, f"{product_name} muvaffaqiyatli o'chirildi!")
        return redirect('kitchen:products_list')
    
    context = {
        'product': product
    }
    return render(request, 'kitchen/product_confirm_delete.html', context)

@csrf_exempt
def toggle_product_availability(request, product_id):
    """Mahsulot mavjudligini o'zgartirish"""
    if request.method == 'POST':
        product = get_object_or_404(Product, id=product_id)
        product.is_available = not product.is_available
        product.save()
        
        # WebSocket orqali yangilanishni yuborish
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            'kitchen_orders',
            {
                'type': 'product_update',
                'product_id': product.id,
                'is_available': product.is_available,
                'message': f"{product.name} {'mavjud' if product.is_available else 'mavjud emas'}"
            }
        )
        
        return JsonResponse({
            'success': True,
            'is_available': product.is_available,
            'message': f"{product.name} {'mavjud' if product.is_available else 'mavjud emas'}"
        })
    
    return JsonResponse({'success': False})

@csrf_exempt
def update_order_status(request):
    """Buyurtma holatini yangilash"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            order_id = data.get('order_id')
            new_status = data.get('status')
            
            order = get_object_or_404(Order, order_id=order_id)
            old_status = order.status
            order.status = new_status
            order.updated_at = timezone.now()
            
            # Tayyor holatiga o'tganda taxminiy vaqtni belgilash
            if new_status == 'tayyor':
                order.estimated_time = timezone.now()
            
            order.save()
            
            # WebSocket orqali yangilanishni yuborish
            channel_layer = get_channel_layer()
            async_to_sync(channel_layer.group_send)(
                'kitchen_orders',
                {
                    'type': 'order_update',
                    'order_id': order.order_id,
                    'status': order.status,
                    'old_status': old_status,
                    'message': f"Buyurtma #{order.order_id} holati o'zgartirildi"
                }
            )
            
            return JsonResponse({
                'success': True,
                'message': f"Buyurtma #{order_id} holati yangilandi",
                'new_status': order.get_status_display_with_icon()
            })
            
        except Exception as e:
            return JsonResponse({
                'success': False,
                'message': f"Xatolik: {str(e)}"
            })
    
    return JsonResponse({'success': False})

def get_orders_api(request):
    """API orqali buyurtmalarni olish"""
    status_filter = request.GET.get('status', 'all')
    
    orders = Order.objects.all().order_by('-created_at')
    
    if status_filter != 'all':
        orders = orders.filter(status=status_filter)
    
    orders_data = []
    for order in orders:
        orders_data.append({
            'id': order.id,
            'order_id': order.order_id,
            'customer_name': order.customer_name,
            'status': order.status,
            'status_display': order.get_status_display_with_icon(),
            'total_amount': float(order.total_amount),
            'created_at': order.created_at.strftime('%H:%M'),
            'items_count': order.items.count(),
        })
    
    return JsonResponse({'orders': orders_data})
