@echo off
chcp 65001 >nul
title RNG Lands Integrated Launcher
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_launcher\rng_lands_launcher.ps1" %*
if errorlevel 1 pause
