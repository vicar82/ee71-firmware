#!/bin/sh

echo `date '+%d/%m/%y %H:%M'` "4GEE WiFi Mini started." >> /jrd-resource/resource/webrc/system_log
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

