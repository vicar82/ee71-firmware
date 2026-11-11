# EE71 Firmware Tree

Рабочее дерево прошивки Alcatel EE71 (EE UK, `EE71_E1_02.00_36`, пакет от 2025-09-12).
Живой юнит обновлён до `_38` — базовые бинарники идентичны, отличия только
в jrdresource/efs2-шаблонах. Источник: `Flash+Firmware-+fastboot-update-EE71.rar`
(ветка 4PDA, тема EE71).

## Разметка дерева

```
flash/         исходные образы пакета (как есть) + скрипт прошивки + config.xml/custom_info.xml
  images/      sbl1/tz/rpm/appsboot/efs/boot/sysfs/recoveryfs/NON-HLOS/jrdresource/partition
system/        mdm9640-sysfs.ubi → ubi0 (rootfs + usrfs) — HLOS rootfs + /usr (webs, core_app)
jrdresource/   jrdresource.ubi → ubi2 — вебморда, JRD-скрипты, APN-профили, NV-шаблоны
modem/         NON-HLOS.ubi — образ модема MDM9640.LE.3.0-00204-STD.PROD-1.147565.3
boot/          mdm9640-boot.img, сплит:
                 zImage        ядро 3.10.49 (QCOM), загрузка с root=ubi0:rootfs, без рамдиска
                 dtb.qcdt      QCDT v3, 60 DTB (платформа 0xEA = MDM9x45)
                 sig.tail      2048 байт — подпись/сертификат (?). ОТКРЫТЫЙ ВОПРОС этапа 4:
                               проверяет ли aboot подпись zImage при загрузке?
recoveryfs/    mdm-recovery-image-mdm9640.ubi → recovery-окружение (mtd9)
```

## Чем распаковано

- UBI → `ubi_reader` (pip). Volumes: ubi0:rootfs, ubi0:usrfs, ubi2_0 → jrd-resource,
  ubi1_0 → /firmware (modem), ubi3_0 → /cache, ubi4_0 → /recovery.
- boot.img → ручной сплит по QCOM-варианту заголовка Android:
  kernel_size@0x08, kernel_addr@0x0C, ramdisk_addr@0x14, tags@0x20, page=2048,
  **ramdisk_size@0x28** (нестандарт!), рамдиска нет — вместо него QCDT.

## Ключевые факты (собраны в работе)

- `efs.mbn` из flash/images НЕ ПРОШИВАТЬ на чужие устройства — шаблон EFS без IMEI/калибровки.
- `fastboot reboot`/`reboot` модем НЕ ресетит; глубокий ресет модема = батарея наружу 30–60 с
  или `AT+CFUN=1,1` (только модем).
- Модем финальный: `MDM9640.LE.3.0-00204-STD.PROD-1.147565.3` (в _36 и _38 одинаковый).
- QMI NAS: get=0x34, set=0x33, структура 376 байт. mode_pref u16@0x0c (valid@0x0a),
  lte_band u64@0x28 (valid@0x20). RAT-маска: GSM=0x04, UMTS=0x08, LTE=0x10.
- 3G/2G: стеки WCDMA/GERAN в прошивке модема есть, но core_app принудительно
  сбрасывает mode_pref=0x3f при каждой инициализации модема — vendor lock (EE).
  Пункт закрыт; переоткрывать только вместе с бинарными патчами core_app.
- Сборка под устройство: zig 0.13 `cc -target arm-linux-musleabi` + патч e_flags
  (clear 0x200 @36); для LD_PRELOAD-библиотек добавлять `-Wl,-z,lazy -Wl,-z,norelro`
  (BIND_NOW ломает интерпозицию в qmi_test).
- busybox 1.36 на устройстве: `timeout` БЕЗ `-t` (ломает старые скрипты).

## Статус модификаций живого юнита (не входят в дерево!)

Текущие правки живого роутера (busybox 1.36.1, dnsmasq 2.90, DNS-слой v2, вебморда
с dns.cgi/bandpref.cgi и т.д.) живут отдельно и будут запечены в дерево поэтапно
(см. план: sysfs.ubi v1 → jrdresource.ubi v1 → boot.img → flash-скрипт).
```

## Сборка образов (проверено 2026-11-09)

Инструменты: Lima-VM `ee71fw` (Debian 13, brew install lima), внутри `apt install mtd-utils`.
Геометрия ubi0: PEB 131072, minIO 2048, LEB 126976, vid_hdr_off 2048.

```
cp -a system/rootfs system/usrfs -> VM; chown -R root:root
mkfs.ubifs -r rootfs -o rootfs.ubifs -m 2048 -e 126976 -c 166 -x lzo
mkfs.ubifs -r usrfs  -o usrfs.ubifs  -m 2048 -e 126976 -c 330 -x lzo
ubinize -o mdm9640-sysfs.ubi -m 2048 -p 131072 -s 2048 ubi.cfg
# rootfs: vol_id=0, vol_size=21076992 (166 LEB); usrfs: vol_id=1, autoresize
```

Артефакты этапа 1 в `build/`: mdm9640-sysfs-v1.ubi (43.1 МБ, rootfs 390 files +
usrfs 681 files, round-trip через ubireader — дифф с деревом пустой).
Прошивка: `fastboot flash system build/mdm9640-sysfs-v1.ubi` (БЕЗ efs2!).

## Этап 2: jrdresource.ubi (ubi2, mtd14)

Геометрия: PEB 131072, LEB 126976, том jrdresource 134 LEB (vol_size=17014016, без autoresize).
Сборка: mkfs.ubifs -r jrdresource -o jrdresource.ubifs -m 2048 -e 126976 -c 134 -x lzo;
ubinize -o jrdresource.ubi -m 2048 -p 131072 -s 2048 ubi-jrd.cfg.
Прошивка: fastboot flash jrdresource build/jrdresource-v1.ubi (10.7 МБ).

Состав v1 (отличия от стока):
- resource/webrc/www — наша вебморда (бандл app.74c6812103, 25 CGI incl. dns.cgi/bandpref.cgi,
  ca.html/ca_monitor.sh, i18n, иконки); бэкапы *.bak/*.prev не шипуются
- bin/: oem_watch (патч: без drop_caches/sysrq/sqlite-check, sleep 60),
  add_redirect_rules.sh / add_connect_redirect_rules.sh (DNS-хайджек вырезан)
- resource/wlan/shell/wifi_improve_tp — governor interactive, частоты 300000-1190400
- bandlock.conf="1" (auto по умолчанию), dns.conf — дефолт 1.1.1.1/8.8.8.8 + router
- speedtest-cli (944K)
- НЕ шипуется: user_info.db3 (создаётся core_app при первом буте), .imei,
  FOTA/профильные runtime-файлы, version-метаданные остаются _36

## Разблокировка LTE-диапазонов (B8/B28/B38/B40) — тема закрыта 2026-11-09

Стоковый набор (mcfg): B1/B3/B7/B20. Три пути проверены и закрыты:
- **QMI 0x36** (Set Band Preference): сообщения НЕТ в таблице NAS (rc=-43).
- **Патч образа модема** (mcfg-оверрайды найдены в modem.b12, три записи
  0x1aac/0x1aad/0x00010061): **образ подписан — MBA отвергает** («MBA returned
  error -19», модем не стартует). Откат выполнен, сток восстановлен.
  Следствие для Этапа 4: boot.img, вероятно, защищён так же (sig.tail).
- **Отключение mcfg autoselect** (segload_config [1,2]->[0,2]): mcfg применяет
  оверрайды диапазонов в любом режиме — NV перезаписывается при каждой загрузке.

Что осталось теоретически: рулетка слотов segload (перебор индексов с батарейкой
на каждый) без гарантии, что в подписанном образе есть конфиг без band-оверрайдов;
рантайм-применение с хоста (efs2 + AT+CFUN=1,1) — UX-мёртво. Оба пути низкоценны.

Страница «LTE-диапазоны» в вебморде показывает реальные диапазоны кэмпинга
(источник правды — signal_ca.json), кастомная блокировка честно отсутствует.

## Восстановление boot (пройдено 2026-11-10)

- **boot.img подписан**: модификация 1 байта cmdline -> aboot/TZ отвергают, устройство
  мёртвое (ни fastboot, ни adb, USB 0xF000 = mass-storage 0 байт).
- **Recovery имеет adb!** ( recoveryfs + adbd; dropbear нет, ssh - нет). Вход: кнопка
  под батареей (Factory Restore) при включении -> поочерёдное мигание LED -> adb shell.
  ВАЖНО: штатный Factory Restore НЕ переписывает boot/system/jrdresource (только
  настройки/NV) - наши файлы в system/jrdresource выживают.
- **dd -> /dev/mtdblockN и /dev/mtdN НЕ работает** для записи образа (частичный блок +
  ECC: запись "успешна", чтение - EIO/мусор). Битых блоков в boot нет (mtdscan).
- Рабочий путь: **mtdwriter** (docs-mtdtools/mtdwriter.c): MEMERASE -> write по
  writesize -> pread+memcmp verify. Собирается zig cc -target arm-linux-musleabi.
  После VERIFY OK: adb reboot - загрузка восстановленного boot.
