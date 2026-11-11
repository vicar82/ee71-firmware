@echo off
rem ============================================================
rem  EE71 flash v2 — ПОЛНЫЙ комплект (все разделы)
rem  efs2 НЕ ПРОШИВАЕТСЯ — ни при каких обстоятельствах.
rem  Точки невозврата здесь нет, но шанс ошибиться выше:
rem  прошивай ПОЛНЫЙ комплект только если понимаешь зачем.
rem ============================================================
setlocal
cd /d "%~dp0"

where adb >nul 2>&1 || (echo [ERR] adb не найден в PATH. & pause & exit /b 1)

echo ============================================================
echo  ПОЛНАЯ ПЕРЕПРОШИВКА EE71 (без efs2)
echo  Затрагиваются: sbl, tz, rpm, aboot, boot, modem,
echo                  recoveryfs, system, jrdresource
echo  НЕ затрагивается: efs2 (IMEI/калибровка)
echo ============================================================
set /p CONF=Продолжить? Введи YES: 
if /i not "%CONF%"=="YES" (echo Отменено. & exit /b 0)

echo === Шаг 1/5: устройство ===
adb devices | findstr /R "device$" >nul || (echo [ERR] adb не видит устройство. & pause & exit /b 1)

echo === Шаг 2/5: бэкап EFS ===
if exist efs2-backup.img (move /y efs2-backup.img efs2-backup-old.img >nul)
adb shell dd if=/dev/mtdblock2 of=/tmp/efs2-backup.img bs=65536 2>nul
adb pull /tmp/efs2-backup.img efs2-backup.img >nul 2>&1
adb shell rm -f /tmp/efs2-backup.img >nul 2>&1
if not exist efs2-backup.img (echo [ERR] Бэкап EFS не создан — прерываю. & pause & exit /b 1)
echo Бэкап: efs2-backup.img OK

echo === Шаг 3/5: fastboot ===
adb reboot bootloader
timeout /t 20 /nobreak >nul

echo === Шаг 4/5: прошивка (boot chain — будь уверен в образах!) ===
fastboot erase sbl & fastboot flash sbl images\sbl1.mbn || goto :fb_err
fastboot erase tz   & fastboot flash tz   images\tz.mbn   || goto :fb_err
fastboot erase rpm  & fastboot flash rpm  images\rpm.mbn  || goto :fb_err
fastboot erase aboot & fastboot flash aboot images\appsboot.mbn || goto :fb_err
fastboot erase boot & fastboot flash boot  images\mdm9640-boot.img || goto :fb_err
fastboot erase modem & fastboot flash modem images\NON-HLOS.ubi || goto :fb_err
fastboot erase recoveryfs & fastboot flash recoveryfs images\mdm-recovery-image-mdm9640.ubi || goto :fb_err
fastboot erase system & fastboot flash system images\mdm9640-sysfs-v1.ubi || goto :fb_err
fastboot erase jrdresource & fastboot flash jrdresource images\jrdresource-v1.ubi || goto :fb_err

echo === Шаг 5/5: перезагрузка ===
fastboot reboot
echo Полная перепрошивка завершена. Первая загрузка ~1-2 минуты.
pause
exit /b 0

:fb_err
echo [ERR] fastboot-операция не удалась. Устройство в fastboot живо, повтори шаг.
pause
exit /b 1
