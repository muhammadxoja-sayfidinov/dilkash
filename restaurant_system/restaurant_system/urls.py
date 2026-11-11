from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.views.static import serve
from django.views.generic import RedirectView

from chef_panel import views as chef_views
from chef_panel import pos_api
from chef_panel import urls as chef_urls

urlpatterns = [
    path('', RedirectView.as_view(url='/chef_panel/', permanent=False), name='home'),
    path('health/', pos_api.health_check_api, name='health_check'),
    path('api/health/', pos_api.health_check_api, name='api_health_check'),
    path('menu/', chef_views.menu_app, name='menu_direct'),
    path('waiter/', chef_views.waiter_app, name='waiter_direct'),
    path('cashier/', chef_views.cashier_pos_view, name='cashier_direct'),
    path('cashier/delivery/', chef_views.cashier_delivery_view, name='cashier_delivery_direct'),
    path('kitchen/', chef_views.kitchen_kds_view, name='kitchen_direct'),
    path('table/<str:table_number>/', chef_views.table_guest_bill_view, name='table_guest_bill_direct'),
    path('dilkashadmin1234/', admin.site.urls),
    path('chef_panel/', include('chef_panel.urls')),
    *chef_urls.api_urlpatterns,
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
else:
    urlpatterns += [
        re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
    ]
