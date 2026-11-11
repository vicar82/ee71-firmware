#!/bin/bash
# ============================================================
#  EE71 flash v2 (macOS/Linux) — обновление system + jrdresource
#  efs2 НЕ ТРОГАЕТСЯ (IMEI/калибровка в безопасности)
#  Требования: adb и fastboot в PATH (brew install android-platform-tools)
# ============================================================
set -u
cd "$(dirname "$0")"

die() { echo "[ERR] $*" >&2; exit 1; }
command -v adb >/dev/null || die "adb не найден (brew install android-platform-tools)"
command -v fastboot >/dev/null || die "fastboot не найден"

echo "=== Шаг 1/4: проверка устройства ==="
adb devices | grep -q $'device$' || die "adb не видит устройство. Если USB в режиме CD-ROM — сначала переключи композицию (usbcomp.cgi на вебморде / EE71_Fix.ps1 на Windows)."

echo "=== Шаг 2/4: бэкап EFS (обязателен) ==="
[ -f efs2-backup.img ] && mv -f efs2-backup.img efs2-backup-old.img
adb shell dd if=/dev/mtdblock2 of=/tmp/efs2-backup.img bs=65536 2>/dev/null
adb pull /tmp/efs2-backup.img efs2-backup.img >/dev/null 2>&1
adb shell rm -f /tmp/efs2-backup.img >/dev/null 2>&1
[ -s efs2-backup.img ] || die "бэкап EFS не создан — прерываю."
echo "Бэкап: $(pwd)/efs2-backup.img ($(du -h efs2-backup.img | cut -f1))"

echo "=== Шаг 3/4: fastboot ==="
adb reboot bootloader
echo "Ждём fastboot (до 30 с)..."
for i in $(seq 1 15); do sleep 2; fastboot devices | grep -q . && break; done
fastboot devices | grep -q . || die "устройство не появилось в fastboot"

echo "=== Шаг 4/4: прошивка system + jrdresource ===
"
fastboot erase system         || die "erase system"
fastboot flash system images/mdm9640-sysfs-v1.ubi    || die "flash system"
fastboot erase jrdresource    || die "erase jrdresource"
fastboot flash jrdresource images/jrdresource-v1.ubi || die "flash jrdresource"

fastboot reboot
echo
echo "Готово. Первая загрузка ~1 минута. Вебморда: http://192.168.8.1"
echo "Откат при необходимости: fastboot flash system images/mdm9640-sysfs.ubi (сток лежит в ../build и в исходном пакете)"
