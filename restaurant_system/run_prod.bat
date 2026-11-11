@echo off
cd /d "%~dp0"
set DJANGO_DEBUG=False
..\venv\Scripts\python.exe manage.py migrate --noinput
..\venv\Scripts\python.exe manage.py seed_pos_defaults
..\venv\Scripts\python.exe manage.py collectstatic --noinput
..\venv\Scripts\waitress-serve.exe --host=0.0.0.0 --port=8000 --threads=8 restaurant_system.wsgi:application
