import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
import kitchen.routing

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'kitchen_system.settings')

application = ProtocolTypeRouter({
    "http": get_asgi_application(),
    "websocket": AuthMiddlewareStack(
        URLRouter(
            kitchen.routing.websocket_urlpatterns
        )
    ),
})
