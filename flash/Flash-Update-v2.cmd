@echo off
rem ============================================================
rem  EE71 flash v2 — ОБНОВЛЕНИЕ system + jrdresource (наши сборки)
rem  efs2 НЕ ТРОГАЕТСЯ (IMEI/калибровка в безопасности)
rem  Предусловие: устройство загружено, adb видит его.
rem  Если adb не видит устройство — сначала запусти EE71_Fix.ps1
rem  (переключение USB-композиции), затем этот скрипт.
rem ============================================================
setlocal
cd /d "%~dp0"

where adb >nul 2>&1 || (echo [ERR] adb не найден в PATH. Положи adb.exe рядом или пропиши PATH. & pause & exit /b 1)

echo === Шаг 1/4: проверка устройства ===
adb devices | findstr /R "device$" >nul || (echo [ERR] Устройство не видно через adb. Запусти сначала EE71_Fix.ps1. & pause & exit /b 1)

echo === Шаг 2/4: бэкап EFS (IMEI, калибровка) — ОБЯЗАТЕЛЕН ===
if exist efs2-backup.img (
    echo Найден старый efs2-backup.img — переименовываю в efs2-backup-old.img
    move /y efs2-backup.img efs2-backup-old.img >nul
)
adb shell dd if=/dev/mtdblock2 of=/tmp/efs2-backup.img bs=65536 2>nul
adb pull /tmp/efs2-backup.img efs2-backup.img >nul 2>&1
adb shell rm -f /tmp/efs2-backup.img >nul 2>&1
if not exist efs2-backup.img (echo [ERR] Бэкап EFS не создан — прерываю, прошивать не буду. & pause & exit /b 1)
echo Бэкап создан: efs2-backup.img (%~dp0efs2-backup.img)

echo === Шаг 3/4: перезагрузка в fastboot ===
adb reboot bootloader
echo Дождись появления устройства в fastboot (может занять 10-20 с)...
timeout /t 20 /nobreak >nul

echo === Шаг 4/4: прошивка system + jrdresource ===
fastboot erase system  || goto :fb_err
fastboot flash system images\mdm9640-sysfs-v1.ubi    || goto :fb_err
fastboot erase jrdresource || goto :fb_err
fastboot flash jrdresource images\jrdresource-v1.ubi || goto :fb_err

fastboot reboot
echo.
echo Готово. Роутер перезагружается (~1 минута до рабочего состояния).
echo Вебморда: http://192.168.8.1  (WiFi: ALCATEL-EE71-5G / пароль с наклейки)
pause
exit /b 0

:fb_err
echo [ERR] fastboot-операция не удалась. Проверь кабель/драйверы и повтори.
echo Устройство в fastboot осталось живым — сценарий безопасен для повтора.
pause
exit /b 1
