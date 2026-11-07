@echo off
title Cloudflare Tunnel - Eggova Backend Port 3000
echo ========================================================
echo Starting Cloudflare Tunnel for Eggova Backend (port 3000)
echo ========================================================
echo.
echo Look for the line below starting with:
echo    https://......trycloudflare.com
echo.
echo Copy that URL and use it to test from your mobile data!
echo Press Ctrl+C anytime to stop.
echo --------------------------------------------------------
"%~dp0tools\cloudflared.exe" tunnel --url http://localhost:3000
pause

