from django.urls import path
from . import views

app_name = 'kitchen'

urlpatterns = [
    path('', views.kitchen_dashboard, name='dashboard'),
    path('orders/', views.orders_list, name='orders_list'),
    path('orders/<str:order_id>/', views.order_detail, name='order_detail'),
    path('products/', views.products_list, name='products_list'),
    path('products/add/', views.add_product, name='add_product'),
    path('products/edit/<int:product_id>/', views.edit_product, name='edit_product'),
    path('products/delete/<int:product_id>/', views.delete_product, name='delete_product'),
    path('products/toggle/<int:product_id>/', views.toggle_product_availability, name='toggle_product'),
    path('api/update-order-status/', views.update_order_status, name='update_order_status'),
    path('api/orders/', views.get_orders_api, name='get_orders_api'),
]
