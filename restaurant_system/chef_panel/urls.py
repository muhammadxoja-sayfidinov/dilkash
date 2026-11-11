from django.urls import path
from . import views
from . import payments
from . import pos_api

app_name = 'chef_panel'

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
    path('menu/', views.menu_app, name='menu_app'),
    path('orders/', views.order_list, name='order_list'),
    path('orders/new/', views.new_orders, name='new_orders'),
    path('orders/<int:order_id>/', views.order_detail, name='order_detail'),
    path('orders/<int:order_id>/receipt/', views.thermal_receipt, name='thermal_receipt'),
    path('orders/<int:order_id>/receipt/<str:department>/', views.thermal_receipt, name='thermal_receipt_dept'),
    path('api/orders/<int:order_id>/print/<str:department>/', views.api_print_order_dept, name='api_print_order_dept'),
    path('orders/<int:order_id>/confirm/', views.confirm_order, name='confirm_order'),
    path('orders/<int:order_id>/ready/', views.mark_ready, name='mark_ready'),
    path('orders/<int:order_id>/cancel/', views.cancel_order, name='cancel_order'),
    path('products/', views.product_list, name='product_list'),
    path('products/add/', views.add_product, name='add_product'),
    path('products/<int:product_id>/edit/', views.edit_product, name='edit_product'),
    path('categories/', views.category_list, name='category_list'),
    path('categories/add/', views.add_category, name='add_category'),
    path('tables/qrs/', views.table_qrs_view, name='table_qrs'),
    path('waiter/', views.waiter_app, name='waiter_app'),
    
    # API endpoints
    path('api/waiter/floor-status/', views.waiter_floor_status_api, name='waiter_floor_status_api'),
    path('api/waiter/order/create/', views.waiter_create_order_api, name='waiter_create_order_api'),
    path('api/waiter/call/<int:call_id>/dismiss/', views.waiter_dismiss_call_api, name='waiter_dismiss_call_api'),
    path('api/waiter/order/<int:order_id>/close/', views.waiter_close_table_api, name='waiter_close_table_api'),
    path('api/orders/create/', views.create_order_api, name='create_order_api'),
    path('api/orders/update-status/', views.update_order_status, name='update_order_status'),
    path('api/orders/update-status-legacy/', views.update_order_status_api, name='update_order_status_api'),
    path('api/orders/<int:telegram_id>/user-orders/', views.get_user_orders_api, name='get_user_orders_api'),
    path('api/orders/<int:order_id>/details/', views.get_order_details_api, name='get_order_details_api'),
    path('api/products/<int:product_id>/toggle-availability/', views.toggle_product_availability, name='toggle_product_availability'),
    path('api/waiter/call/', views.call_waiter_api, name='call_waiter_api'),
    path('api/waiter/bill-request/<str:table_number>/', views.waiter_request_bill_api, name='waiter_request_bill_api'),
    path('api/table/<str:table_number>/status/', views.table_order_status_api, name='table_order_status_api'),
    path('api/table/order/item/<int:item_id>/update/', views.table_item_update_api, name='table_item_update_api'),

    # Kassir & Oshxona Yangi Oynalari
    path('cashier/', views.cashier_pos_view, name='cashier_pos'),
    path('cashier/delivery/', views.cashier_delivery_view, name='cashier_delivery'),
    path('kitchen/', views.kitchen_kds_view, name='kitchen_kds'),
    path('table/<str:table_number>/', views.table_guest_bill_view, name='table_guest_bill'),
    path('settings/', views.settings_hub_view, name='settings_hub'),
    path('printer-settings/', views.printer_settings_view, name='printer_settings'),

    # To'lov tizimlari (Click & Payme)
    path('api/payments/click/', payments.click_webhook, name='click_webhook'),
    path('api/payments/payme/', payments.payme_webhook, name='payme_webhook'),
    path('api/payments/simulate/<int:order_id>/', payments.simulate_payment_api, name='simulate_payment'),

    # Kassir API lari
    path('api/cashier/table/<str:table_number>/', views.cashier_table_data_api, name='cashier_table_data_api'),
    path('api/cashier/assign-waiter/', views.cashier_assign_waiter_api, name='cashier_assign_waiter_api'),
    path('api/cashier/assign-courier/', views.cashier_assign_courier_api, name='cashier_assign_courier_api'),
    path('api/cashier/staff/', views.cashier_staff_list_api, name='cashier_staff_list_api'),
    path('api/cashier/staff/create/', views.cashier_staff_create_api, name='cashier_staff_create_api'),
    path('api/cashier/staff/<str:staff_type>/<int:staff_id>/toggle/', views.cashier_staff_toggle_api, name='cashier_staff_toggle_api'),
    path('api/cashier/printer-settings/', views.cashier_printer_settings_api, name='cashier_printer_settings_api'),
    path('api/cashier/printer-settings/save/', views.cashier_save_printer_settings_api, name='cashier_save_printer_settings_api'),
    path('api/cashier/printer-settings/test-print/', views.cashier_test_print_api, name='cashier_test_print_api'),

    # Flutter Mijoz Ilovasi API lari
    path('api/mobile/customer/menu/', views.mobile_customer_menu_api, name='mobile_customer_menu_api'),
    path('api/mobile/customer/order/create/', views.mobile_customer_order_create_api, name='mobile_customer_order_create_api'),
    path('api/mobile/customer/orders/<str:phone>/', views.mobile_customer_orders_api, name='mobile_customer_orders_api'),
    path('api/mobile/customer/order/<int:order_id>/status/', views.mobile_customer_order_status_api, name='mobile_customer_order_status_api'),
    path('api/mobile/customer/auth/', views.mobile_customer_auth_api, name='mobile_customer_auth_api'),
    path('api/mobile/customer/profile/update/', views.mobile_customer_profile_update_api, name='mobile_customer_profile_update_api'),
    path('api/mobile/customer/tip/', views.mobile_customer_tip_api, name='mobile_customer_tip_api'),

    # Flutter Kuryer & Ofitsiant (Yagona Xodim Ilovasi) API lari
    path('api/mobile/staff/login/', views.mobile_staff_login_api, name='mobile_staff_login_api'),
    path('api/mobile/courier/login/', views.mobile_courier_login_api, name='mobile_courier_login_api'),
    path('api/mobile/courier/orders/', views.mobile_courier_orders_api, name='mobile_courier_orders_api'),
    path('api/mobile/courier/order/claim/', views.mobile_courier_claim_order_api, name='mobile_courier_claim_order_api'),
    path('api/mobile/courier/available-orders/', views.mobile_courier_available_orders_api, name='mobile_courier_available_orders_api'),
    path('api/mobile/courier/order/<int:order_id>/update-status/', views.mobile_courier_update_status_api, name='mobile_courier_update_status_api'),
    path('api/mobile/courier/location/update/', views.mobile_courier_location_api, name='mobile_courier_location_api'),
    path('api/waiter/order/<int:order_id>/deliver/', views.waiter_deliver_order_api, name='waiter_deliver_order_api'),
    path('api/waiter/table/<str:table_number>/assign/', views.waiter_assign_table_api, name='waiter_assign_table_api'),
    path('api/waiter/table/<str:table_number>/release/', views.waiter_release_table_api, name='waiter_release_table_api'),

    # C# WPF POS Desktop API lari
    path('api/pos/bootstrap/', pos_api.pos_bootstrap_api, name='pos_bootstrap_api'),
    path('api/pos/tables/', pos_api.pos_tables_api, name='pos_tables_api'),
    path('api/pos/orders/', pos_api.pos_orders_api, name='pos_orders_api'),
    path('api/pos/orders/<int:order_id>/pay/', pos_api.pos_order_pay_api, name='pos_order_pay_api'),
    path('api/pos/stop-list/', pos_api.pos_stop_list_api, name='pos_stop_list_api'),
    path('api/pos/products/<int:product_id>/toggle-stop/', pos_api.pos_toggle_stop_api, name='pos_toggle_stop_api'),
    path('api/pos/online-orders/', pos_api.pos_online_orders_api, name='pos_online_orders_api'),
    path('api/pos/online-orders/<int:order_id>/action/', pos_api.pos_online_order_action_api, name='pos_online_order_action_api'),
    path('api/pos/sync/push/', pos_api.pos_sync_push_api, name='pos_sync_push_api'),
    path('api/pos/waiter-calls/<int:call_id>/dismiss/', views.waiter_dismiss_call_api, name='pos_waiter_dismiss_call_api'),
]

