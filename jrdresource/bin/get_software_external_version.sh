#!/bin/sh

version=`grep 'External_Ver' /jrd-resource/resource/jrdcfg/config.xml | cut -d '>' -f 2 | cut -d '<' -f 1`

echo `date '+%d/%m/%y %H:%M'` "Firmware updated to $version ." >> /jrd-resource/resource/webrc/system_log

lines=`wc -l /jrd-resource/resource/webrc/system_log | awk '{print $1}'`
if [ $lines -gt 100 ];then
diffline=`expr $lines - 100`
while read log
do
	diffline=`expr $diffline - 1`
	if [ $diffline -lt 0 ];then
		echo $log >>/jrd-resource/resource/webrc/system_log_tmp
	fi
done < /jrd-resource/resource/webrc/system_log
rm -rf /jrd-resource/resource/webrc/system_log
mv /jrd-resource/resource/webrc/system_log_tmp /jrd-resource/resource/webrc/system_log
fi
