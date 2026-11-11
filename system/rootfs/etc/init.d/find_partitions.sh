#!/bin/sh
# Copyright (c) 2014, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of The Linux Foundation nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# find_partitions        init.d script to dynamically find partitions
#
ismounted()
{
  if [ $( mount | grep $1 | wc -l ) -eq 1 ];then
    echo "$1 is mounted"
    return 1
  fi

  return 0
}

mtd_debug_fstype()
{
  mtd_block_number=$1
  fstype=$2

  #for example:
  #addr_block1 is at 0x20000(128KB)
  #addr_block2 is at 0x40000

  #get block size here
  block_size=`cat /proc/mtd | grep mtd$mtd_block_number |awk '{print $3}'`
  block_size=$((0x${block_size}))
  block_index=0

  echo "mtd$mtd_block_number block_size $block_size Bytes" > /dev/kmsg

  if [ $fstype = "ubi" ];then
    addr=0
    length=4
    fshead="UBI#"
  elif [ $fstype = "vfat" ];then
    addr=0x52
    length=5
    fshead="FAT32"
  else
    echo "error, mtd_debug_fstype invalid arguments" > /dev/kmsg
    exit 1
  fi

  mtd_debug read /dev/mtd$mtd_block_number $addr $length /test
  HEAD=`cat /test`
  rm -f /test

  echo "mtd$mtd_block_number head is $HEAD" > /dev/kmsg
  if [ "x${HEAD}" != "x${fshead}" ];then
    if [ $fstype = "ubi" ];then
	for k in $( seq 1 4 )
	do
		block_index=$(($block_index+$block_size))
		echo "mtd$mtd_block_number block_index:$k is at $block_index" > /dev/kmsg

		mtd_debug read /dev/mtd$mtd_block_number $block_index $length /test
		HEAD1=`cat /test`
		rm -f /test

		if [ "x${HEAD1}" != "x${fshead}" ];then
			echo "mtd$mtd_block_number block_index:$k is at $block_index, head is $HEAD1" > /dev/kmsg
		else
			echo "mtd$mtd_block_number has been formatted at block:$k $block_index, head is $HEAD1" > /dev/kmsg
			return 0
		fi
	done

  	echo "mtd$mtd_block_number is not formatted" > /dev/kmsg
	return 1;
    else
	echo "mtd$mtd_block_number is not formatted." > /dev/kmsg
	return 1;
    fi
  else
    echo "mtd$mtd_block_number has been formatted" > /dev/kmsg
    return 0;
  fi
}

FindAndMountUBI () {
  partition=$1
  dir=$2
  ubi_index=$3
  read_only=$4

  if [ $# -eq 5 ];then
    extern_opt=$5
  else
    extern_opt=""
  fi

  mtd_block_number=`cat $mtd_file | grep -i $partition | sed 's/^mtd//' | awk -F ':' '{print $1}'`
  echo "MTD : Detected block device : $dir for $partition"

  device=/dev/ubi${ubi_index}_0
  ismounted $device
  if [ $? -eq 1 ];then
  return 0
  fi
  mkdir -p $dir

  ubiattach -m $mtd_block_number -d $ubi_index /dev/ubi_ctrl $extern_opt
  while [ 1 ]
  do
    if [ -c $device ]
    then
      if [ $read_only = "n" ]
      then
        echo "mount as rw"
        mount -t ubifs $device $dir -o bulk_read
      else
        mount -t ubifs -o ro  $device $dir -o bulk_read
      fi
      break
    else
      sleep 0.010
    fi
  done
}

FindAndMountVolumeUBI ()
{
  volume_name=$1
  dir=$2
  if [ ! -d $dir ]
  then
    mkdir -p $dir
  fi

  ismounted "ubi0:$volume_name"
  if [ $? -eq 1 ];then
    return 0
  fi

  mount -t ubifs ubi0:$volume_name $dir -o bulk_read
}

FindAndFormatAndMkvolumeAndMountUBI ()
{
  partition=$1
  dir=$2
  ubi_index=$3
  read_only=$4

  if [ $# -eq 5 ];then
    extern_opt=$5
  else
    extern_opt=""
  fi

  mtd_block_number=`cat $mtd_file | grep -i $partition | sed 's/^mtd//' | awk -F ':' '{print $1}'`
  echo "MTD : Detected block device : $dir for $partition"
  mkdir -p $dir

  device=/dev/ubi${ubi_index}_0
  ismounted $device
  if [ $? -eq 1 ];then
    return 0
  fi

  mtd_debug_fstype $mtd_block_number ubi
  if [ ! $? = "0" ]
  then
	   if [ -c /dev/ubi$ubi_index ]
	   then
		     echo "detach ubi first"
		     ubidetach -d $ubi_index
		     rm /dev/ubi$ubi_index
	   fi
	   echo "format mtd"$mtd_block_number > /dev/kmsg
	   ubiformat -y /dev/mtd$mtd_block_number
	   #try to attach ubi filesystem. if attach failed, we will format it and try to attach again
	   ubiattach -m $mtd_block_number -d $ubi_index /dev/ubi_ctrl $extern_opt
	   if [ ! "$?" = "0" ]
	   then
			echo "attach ubi"$ubi_index" failed, we will try again" > /dev/kmsg

			ubiattach -m $mtd_block_number -d $ubi_index /dev/ubi_ctrl $extern_opt
			if [ ! "$?" = "0" ]
			then
				echo "attach ubi"$ubi_index" failed, return" > /dev/kmsg
				return 1
			fi
	   fi

	   while [ 1 ]
	    do
	      if [ -c /dev/ubi$ubi_index ]
	      then
		echo "make volume here" > /dev/kmsg
		ubimkvol /dev/ubi$ubi_index -m -N $partition
		break
	      else
	       echo "sleep 0.01 S" > /dev/kmsg
	       sleep 0.010
	      fi
	    done
  else
    ubiattach -m $mtd_block_number -d $ubi_index /dev/ubi_ctrl  $extern_opt
    while [ 1 ]
    do
      if [ -c /dev/ubi$ubi_index ]
      then
        vol_count=`cat /sys/class/ubi/ubi3/volumes_count`
        if [ $vol_count = "0" ]
        then
           echo "make volume here" > /dev/kmsg
           ubimkvol /dev/ubi$ubi_index -m -N $partition
           if [ ! "$?" = "0" ]
           then
             echo "ubimkvol ubi"$ubi_index" failed, return" > /dev/kmsg
             return 1
           fi
        fi
        break
      else
       echo "sleep 0.01 S" > /dev/kmsg
       sleep 0.010
      fi
    done
  fi

  while [ 1 ]
  do
    if [ -c $device ]
    then
      if [ $read_only = "n" ]
      then
        echo "mount as rw"
      mount -t ubifs $device $dir -o bulk_read
      else
        mount -t ubifs -o ro  $device $dir -o bulk_read
       fi
      break
    else
      echo "sleep 0.01 S" > /dev/kmsg
      sleep 0.010
    fi
  done
}

boot_normal()
{
  FindAndMountVolumeUBI usrfs /usr
  FindAndMountUBI modem /firmware 1 y "-b 4"
  FindAndMountUBI jrdresource /jrd-resource 2 n "-b 4"
  FindAndFormatAndMkvolumeAndMountUBI cache /cache 3 n "-b 4"
  FindAndMountUBI recoveryfs /recovery 4 n "-b 4"
}

mtd_file=/proc/mtd

case "$1" in
  start)
    boot_normal
    ;;
  *)
    echo "not support!"
    exit 1
    ;;
esac

exit 0
