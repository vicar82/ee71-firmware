#!/bin/sh

mtd_file=/proc/mtd
ubi_device_number=1

FindAndAttachUBI() {
   partition=$1

   mtd_block_number=`cat $mtd_file | grep -i $partition | sed 's/^mtd//' | awk -F ':' '{print $1}'`
   if [ -z "$mtd_block_number" ]; then
      echo "MTD : Partition $partition not found"
   else
      echo "MTD : Attaching UBI device /dev/mtdblock$mtd_bloc_number for $partition @$ubi_device_number"

      ubiattach -m $mtd_block_number -d $ubi_device_number /dev/ubi_ctrl
      while [ 1 ]; do
         if [ -c /dev/ubi$ubi_device_number ]; then
            break
         else
            sleep 0.010
         fi
      done
      ubi_device_number=$(($ubi_device_number + 1))
   fi
}

FindAndMountUBI () {
   volume=$1
   dir=$2
   fstab_only="$3"

   echo "MTD : Looking for UBI volume : $dir for $volume"
   mkdir -p $dir

   # Skip ubi0 for recoveryfs
   for ubidev in /dev/ubi[1-99]_*; do
      volname=`ubinfo $ubidev | grep Name\: | awk '{print $2}'`
      if [ "$volname" == "$volume" ]; then
         if [ "$fstab_only" != "1" ]; then
            mount -t ubifs $ubidev $dir -o bulk_read
            echo "MTD : Mounting of $ubidev on $dir done"
         fi
         break
      fi
   done
}

case "$1" in
  start)
    fstype="UBI"
    eval FindAndAttachUBI system
    eval FindAndMountUBI rootfs /system  0
    eval FindAndMountUBI usrfs  /system/usr 0

    eval FindAndAttachUBI modem
    eval FindAndMountUBI modem /system/firmware

    eval FindAndAttachUBI cache
    #eval FindAndMountUBI cache /cache 0
    mount -t ubifs /dev/ubi3_0 /cache -o bulk_read
	
    eval FindAndAttachUBI jrdresource
    eval FindAndMountUBI jrdresource /system/jrd-resource 0
    ;;
  stop)
    umount /system/jrd-resource
    umount /system/firmware
    umount /system/usr
    umount /system
    ;;
  *)
    echo "Usage find_recovery_partitions { start | stop }" >&2
    exit 1
    ;;
esac

exit 0
