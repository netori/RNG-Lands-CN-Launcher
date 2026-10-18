@echo off
chcp 65001 >nul
title RNG Lands Random (Enemy Randomized)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_launcher\rng_lands_launcher.ps1" -Action rand
if errorlevel 1 pause
