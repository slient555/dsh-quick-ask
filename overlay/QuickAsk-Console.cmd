@echo off
chcp 65001 >nul
echo 正在启动 DSH 快速问答（控制台模式，便于看报错）...
echo 热键：Ctrl+Alt+A  框选一块 → 自动识别 → 问 DSH
echo 关闭这个黑窗口即退出。
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0QuickAsk.ps1"
pause
