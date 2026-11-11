"""
Django settings for restaurant_system project.
"""

from pathlib import Path
import os

BASE_DIR = Path(__file__).resolve().parent.parent

try:
    from dotenv import load_dotenv
    load_dotenv(BASE_DIR / '.env')
except ImportError:
    pass

try:
    import dj_database_url
except ImportError:
    dj_database_url = None

try:
    import whitenoise  # noqa: F401
    HAS_WHITENOISE = True
except ImportError:
    HAS_WHITENOISE = False

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'django-insecure-your-secret-key-here')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DJANGO_DEBUG', 'True') == 'True'

_raw_hosts = os.environ.get('ALLOWED_HOSTS', '*')
ALLOWED_HOSTS = [h.strip() for h in _raw_hosts.split(',') if h.strip()] or ['*']

CSRF_TRUSTED_ORIGINS = [
    'https://*.up.railway.app',
    'https://*.onrender.com',
    'https://*.fly.dev',
    'https://*.trycloudflare.com',
    'https://*.ngrok-free.app',
    'https://*.ngrok.io',
    'https://*.loca.lt',
    'http://127.0.0.1:8000',
    'http://localhost:8000',
]
for _extra_origin in os.environ.get('CSRF_TRUSTED_ORIGINS', '').split(','):
    _extra_origin = _extra_origin.strip()
    if _extra_origin and _extra_origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(_extra_origin)
for _host_env in ('RENDER_EXTERNAL_HOSTNAME', 'RAILWAY_PUBLIC_DOMAIN'):
    _host_val = os.environ.get(_host_env, '').strip()
    if _host_val:
        _origin = f"https://{_host_val}"
        if _origin not in CSRF_TRUSTED_ORIGINS:
            CSRF_TRUSTED_ORIGINS.append(_origin)
        if '*' not in ALLOWED_HOSTS and _host_val not in ALLOWED_HOSTS:
            ALLOWED_HOSTS.append(_host_val)

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'chef_panel',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    *( ['whitenoise.middleware.WhiteNoiseMiddleware'] if HAS_WHITENOISE else [] ),
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'restaurant_system.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'restaurant_system.wsgi.application'

# Database (DATABASE_URL bo'lsa PostgreSQL/cloud DB, aks holda SQLite)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
if dj_database_url and os.environ.get('DATABASE_URL'):
    DATABASES['default'] = dj_database_url.config(
        default=os.environ['DATABASE_URL'],
        conn_max_age=600,
        conn_health_checks=True,
    )

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
LANGUAGE_CODE = 'uz-uz'
TIME_ZONE = 'Asia/Tashkent'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATICFILES_DIRS = [
    BASE_DIR / "static",
]
STATIC_ROOT = BASE_DIR / 'staticfiles'
if HAS_WHITENOISE:
    STORAGES = {
        'default': {
            'BACKEND': 'django.core.files.storage.FileSystemStorage',
        },
        'staticfiles': {
            'BACKEND': 'whitenoise.storage.CompressedStaticFilesStorage',
        },
    }

# Reverse-proxy & Cloud HTTPS security
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
_use_secure_ssl = (not DEBUG) and (
    os.environ.get('DJANGO_SECURE_SSL', 'False') == 'True'
    or bool(os.environ.get('RAILWAY_ENVIRONMENT'))
    or bool(os.environ.get('RENDER'))
)
if _use_secure_ssl:
    SECURE_SSL_REDIRECT = True
    SECURE_REDIRECT_EXEMPT = [r'^health/$', r'^api/health/$']
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Media files
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Telegram Bot Settings
TELEGRAM_BOT_TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN', '1574987467:AAFvXaSfQBjagl4LmcY171Kw-gDiHco2v8Y') # BotFather dan olingan token
TELEGRAM_API_BASE_URL = "https://api.telegram.org/bot"
CHEF_CHAT_ID = int(os.environ.get('CHEF_CHAT_ID', '7557043455'))   # Oshpaz chat ID - O'ZGARTIRING!
ADMIN_CHAT_ID = int(os.environ.get('ADMIN_CHAT_ID', '1517715653')) # Kuryer/Admin chat ID - O'ZGARTIRING!

# Restoran koordinatalari
STORE_LAT = float(os.environ.get('STORE_LAT', '40.665236'))
STORE_LON = float(os.environ.get('STORE_LON', '72.563908'))

# Telegram Mini App (Web App) URL
WEB_APP_URL = os.environ.get('WEB_APP_URL', 'http://127.0.0.1:8000/menu/')

# Click to'lov tizimi sozlamalari
CLICK_SERVICE_ID = os.environ.get('CLICK_SERVICE_ID', '')
CLICK_MERCHANT_ID = os.environ.get('CLICK_MERCHANT_ID', '')
CLICK_SECRET_KEY = os.environ.get('CLICK_SECRET_KEY', '')

# Payme to'lov tizimi sozlamalari
PAYME_MERCHANT_ID = os.environ.get('PAYME_MERCHANT_ID', '')
PAYME_SECRET_KEY = os.environ.get('PAYME_SECRET_KEY', '')