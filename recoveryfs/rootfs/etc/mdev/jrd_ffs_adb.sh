#!/bin/sh
case "${ACTION}" in
add|"")
	if [ ! -d /dev/usb-ffs/adb ]; then
		if [ -d /sys/class/android_usb/android0/f_ffs ]
		then
			echo adb > /sys/class/android_usb/android0/f_ffs/aliases
			mkdir -p /dev/usb-ffs/adb
			mount -o uid=2000,gid=2000 -t functionfs adb /dev/usb-ffs/adb
			mount -o remount,gid=5,mode=620 /dev/pts
			mkdir -p /system/bin
			ln -s /bin/sh  /system/bin/sh
		fi
	fi
	pkill adbd
	#ck add cd / for，adb login /
	cd /
	while true;
	do
		# need wait usrfs mounted 
		if [ ! -f /usr/lib/libcrypto.so.1.1 ]; then
			usleep 100000
		else
			break
		fi
	done

	/etc/init.d/adbd start
	;;
remove)
	pkill adbd
	;;
esac
