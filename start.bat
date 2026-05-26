@echo off
title GastroVoyage Dev Server

echo.
echo  ================================================
echo   GASTRO VOYAGE - Dev Server
echo  ================================================
echo.
echo  Backend URL: http://192.168.10.126:8000
echo.

echo  Starting FastAPI backend...
echo  Press Ctrl+C to stop
echo.

cd /d "%~dp0backend"
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
