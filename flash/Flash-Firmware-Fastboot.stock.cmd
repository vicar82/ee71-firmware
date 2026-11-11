adb reboot bootloader
echo Waiting for fastboot...
pause 
echo Flashing images...
fastboot erase sbl
fastboot flash sbl  sbl1.mbn
fastboot erase tz
fastboot flash tz  tz.mbn
fastboot erase rpm
fastboot flash rpm  rpm.mbn
fastboot erase efs2
fastboot flash efs2 efs.mbn
fastboot erase boot
fastboot flash boot  mdm9640-boot.img
fastboot erase system
fastboot flash system  mdm9640-sysfs.ubi
fastboot erase recoveryfs
fastboot flash recoveryfs  mdm-recovery-image-mdm9640.ubi
fastboot erase modem
fastboot flash modem  NON-HLOS.ubi
fastboot erase jrdresource
fastboot flash jrdresource  jrdresource.ubi
fastboot erase aboot
fastboot flash aboot  appsboot.mbn

fastboot reboot

echo Done. 
pause 