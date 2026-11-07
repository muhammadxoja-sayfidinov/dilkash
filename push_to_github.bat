@echo off
title GitHub Push - Dilkash (windows branch)
echo ========================================================
echo Dilkash loyihasini GitHub ga push qilish (windows branch)
echo ========================================================
echo.
cd /d "%~dp0"
echo Joriy branch:
git branch --show-current
echo.
echo GitHub ga yuborilmoqda...
git push -u origin windows
echo.
if %ERRORLEVEL% EQU 0 (
    echo [MUVAFFAQINLI] windows branch GitHub ga muvaffaqiyatli push qilindi!
) else (
    echo [XATO] Push jarayonida xatolik yuz berdi.
)
echo.
pause
