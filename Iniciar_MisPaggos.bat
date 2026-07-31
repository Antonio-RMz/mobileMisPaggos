@echo off
title Servidor MisPaggos Dev
echo ===================================================
echo   INICIANDO MISPAGGOS EN MODO ESCRITORIO
echo ===================================================
echo.
echo 1. Levantando servidor local en segundo plano...
start /b flutter run -d web-server -t lib/main_dev.dart --web-port=53354

echo 2. Esperando a que la aplicacion este lista...
:loop
curl -s http://localhost:53354 >nul
if %errorlevel% neq 0 (
    timeout /t 1 /nobreak >nul
    goto loop
)

echo.
echo 3. Abriendo la aplicacion en ventana de escritorio...
start chrome --app=http://localhost:53354
echo Listo.
exit
