@echo off
title Dilkash Restaurant Backend
echo ========================================================
echo Dilkash Restoran Backend (Django Server) ishga tushmoqda
echo Manzil: http://127.0.0.1:8000/
echo Admin panel: http://127.0.0.1:8000/admin/ (admin / admin123)
echo ========================================================
cd /d "%~dp0restaurant_system"
"%~dp0venv\Scripts\python.exe" manage.py runserver 127.0.0.1:8000
pause

