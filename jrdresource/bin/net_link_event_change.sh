#!/bin/sh



jrd_os_type=`cat /sys/class/android_usb/android0/jrd_os_type`
if [ ${jrd_os_type} -eq 2 ];then
  echo "" > /sys/class/android_usb/f_mass_storage/ipq/file
  echo "" > /sys/class/android_usb/f_mass_storage/lun/file
else
  echo "/dev/mtdblock14" > /sys/class/android_usb/f_mass_storage/ipq/file
  echo "/dev/mtdblock16" > /sys/class/android_usb/f_mass_storage/lun/file
fi

