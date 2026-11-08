from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

from django.views.generic import RedirectView
from chef_panel import views as chef_views
from chef_panel import pos_api

urlpatterns = [
    path('', RedirectView.as_view(url='/chef_panel/', permanent=False), name='home'),
    path('menu/', chef_views.menu_app, name='menu_direct'),
    path('waiter/', chef_views.waiter_app, name='waiter_direct'),
    path('cashier/', chef_views.cashier_pos_view, name='cashier_direct'),
    path('cashier/delivery/', chef_views.cashier_delivery_view, name='cashier_delivery_direct'),
    path('kitchen/', chef_views.kitchen_kds_view, name='kitchen_direct'),
    path('table/<str:table_number>/', chef_views.table_guest_bill_view, name='table_guest_bill_direct'),
    path('dilkashadmin1234/', admin.site.urls),
    path('chef_panel/', include('chef_panel.urls')),
    # Top-level API endpoints
    path('api/table/<str:table_number>/status/', chef_views.table_order_status_api),
    path('api/table/order/item/<int:item_id>/update/', chef_views.table_item_update_api),
    path('api/waiter/call/', chef_views.call_waiter_api),
    path('api/waiter/bill-request/<str:table_number>/', chef_views.waiter_request_bill_api),
    path('api/waiter/floor-status/', chef_views.waiter_floor_status_api),
    path('api/waiter/order/create/', chef_views.waiter_create_order_api),
    path('api/waiter/call/<int:call_id>/dismiss/', chef_views.waiter_dismiss_call_api),
    path('api/waiter/order/<int:order_id>/deliver/', chef_views.waiter_deliver_order_api),
    path('api/waiter/order/<int:order_id>/close/', chef_views.waiter_close_table_api),
    path('api/orders/create/', chef_views.create_order_api),
    # Top-level Mobile Flutter APIs
    path('api/mobile/customer/menu/', chef_views.mobile_customer_menu_api),
    path('api/mobile/customer/order/create/', chef_views.mobile_customer_order_create_api),
    path('api/mobile/customer/orders/<str:phone>/', chef_views.mobile_customer_orders_api),
    path('api/mobile/customer/order/<int:order_id>/status/', chef_views.mobile_customer_order_status_api),
    path('api/mobile/customer/auth/', chef_views.mobile_customer_auth_api),
    path('api/mobile/customer/profile/update/', chef_views.mobile_customer_profile_update_api),
    path('api/mobile/customer/tip/', chef_views.mobile_customer_tip_api),
    # Top-level Staff Mobile APIs
    path('api/mobile/staff/login/', chef_views.mobile_staff_login_api),
    path('api/mobile/courier/login/', chef_views.mobile_courier_login_api),
    path('api/mobile/courier/orders/', chef_views.mobile_courier_orders_api),
    path('api/mobile/courier/order/claim/', chef_views.mobile_courier_claim_order_api),
    path('api/mobile/courier/available-orders/', chef_views.mobile_courier_available_orders_api),
    path('api/mobile/courier/order/<int:order_id>/update-status/', chef_views.mobile_courier_update_status_api),
    path('api/mobile/courier/location/update/', chef_views.mobile_courier_location_api),
    path('api/waiter/table/<str:table_number>/assign/', chef_views.waiter_assign_table_api),
    path('api/waiter/table/<str:table_number>/release/', chef_views.waiter_release_table_api),
    # Top-level Cashier APIs
    path('api/cashier/table/<str:table_number>/', chef_views.cashier_table_data_api),
    path('api/cashier/assign-waiter/', chef_views.cashier_assign_waiter_api),
    path('api/cashier/assign-courier/', chef_views.cashier_assign_courier_api),
    path('api/cashier/staff/', chef_views.cashier_staff_list_api),
    path('api/cashier/staff/create/', chef_views.cashier_staff_create_api),
    path('api/cashier/staff/<str:staff_type>/<int:staff_id>/toggle/', chef_views.cashier_staff_toggle_api),
    # Top-level POS APIs
    path('api/pos/bootstrap/', pos_api.pos_bootstrap_api),
    path('api/pos/tables/', pos_api.pos_tables_api),
    path('api/pos/orders/', pos_api.pos_orders_api),
    path('api/pos/orders/<int:order_id>/pay/', pos_api.pos_order_pay_api),
    path('api/pos/stop-list/', pos_api.pos_stop_list_api),
    path('api/pos/products/<int:product_id>/toggle-stop/', pos_api.pos_toggle_stop_api),
    path('api/pos/online-orders/', pos_api.pos_online_orders_api),
    path('api/pos/online-orders/<int:order_id>/action/', pos_api.pos_online_order_action_api),
    path('api/pos/sync/push/', pos_api.pos_sync_push_api),
]


if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
