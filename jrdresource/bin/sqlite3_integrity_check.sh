#!/bin/sh

user_db_file="/jrd-resource/resource/sqlite3/user_info.db3"
user_db_backup_file="/cache/sqlite3_integrity_check_failed.db3"
factory_db_file="/jrd-resource/resource/sqlite3/factory_info.db3"
check_log_file="/cache/sqlite3_integrity_check.log"
check_failed_log_file="/cache/sqlite3_integrity_check_failed.log"
check_failed_log_tmp_file="/cache/sqlite3_integrity_check_failed_tmp.log"
reset_flag_file="/jrd-resource/resource/force_mode"
reset_file_list="\
    /usr/bin/auto_pin \
    /usr/bin/auto_pin_flag \
    /jrd-resource/resource/profile/create \
    /usr/oem/language_set \
    /usr/oem/sim_language \
    /jrd-resource/resource/wlan/mac_filter_deny_ap0 \
    /jrd-resource/resource/wlan/mac_filter_allow_ap0 \
    /jrd-resource/resource/wlan/mac_filter_deny_ap0_5g \
    /jrd-resource/resource/wlan/mac_filter_allow_ap0_5g \
    /jrd-resource/resource/wlan/mac_filter_deny_ap1 \
    /jrd-resource/resource/wlan/mac_filter_allow_ap1 \
    /jrd-resource/resource/wlan/mac_filter_deny_ap1_5g \
    /jrd-resource/resource/wlan/mac_filter_allow_ap1_5g \
    /jrd-resource/resource/wlan/usb_client_name \
    /jrd-resource/resource/wlan/device_name \
    /jrd-resource/resource/router/status_cover \
    /jrd-resource/resource/router/port_fwding.conf \
    /jrd-resource/resource/router/ip_filter.conf \
    /jrd-resource/resource/router/ip_filter_white.conf \
    /jrd-resource/resource/router/port_filter.conf \
    /jrd-resource/resource/wlan/dis_access_internet \
    /jrd-resource/resource/your_file.txt \
    /jrd-resource/resource/router/resolve.conf \
    /etc/wpa_supplicant.conf"

process_log()
{
    if [ -e "$check_failed_log_file" ]; then
        log_file_size=`ls $check_failed_log_file -l | awk '{print $5}'`
        if [ "$log_file_size" -gt 15000 ]; then
            tail -60 "$check_failed_log_file" > "$check_failed_log_tmp_file"
            sync
            cat "$check_failed_log_tmp_file" > "$check_failed_log_file"
            sync
            rm -f "$check_failed_log_tmp_file" 2>/dev/null
        fi
    fi

    cat "$check_log_file" >> "$check_failed_log_file"
}

create_reset_flag_file()
{
    for i in `seq 3`; do
        touch "$reset_flag_file"
        sync 
        sleep 0.3
        if [ -e "$reset_flag_file" ]; then
            echo "create $reset_flag_file success." >> "$check_log_file"
            break
        fi
        echo "create $reset_flag_file $i failed." >> "$check_log_file"
    done
}

reset_process()
{
    for file in $reset_file_list; do
        rm -rf "$file" 2>/dev/null
    done
    
    create_reset_flag_file
    echo "#####reboot#####" >> "$check_log_file"
    sync
    process_log
    reboot
    sleep 30
}

copy_file()
{
    src_file="$1"
    dest_file="$2"
    
    if [ -e "$src_file" ]; then
        for i in `seq 3`; do
            cp -a "$src_file" "$dest_file"
            sync
            sleep 0.3
            src_file_md5=`md5sum $src_file | awk '{print $1}'`
            dest_file_md5=`md5sum $dest_file | awk '{print $1}'`
            if [ "$src_file_md5" = "$dest_file_md5" ]; then
                echo "cp $src_file to $dest_file success." >> "$check_log_file"
                return 0
            fi
            
            echo "cp $src_file to $dest_file $i times failed" >> "$check_log_file"
        done
        sync
    else
        echo "$src_file not exist" >> "$check_log_file"
    fi
    return 1
}

user_db_restore()
{
    echo "user_db_restore start" >> "$check_log_file"
    
    if [ -e "$user_db_file" ]; then
        copy_file "$user_db_file" "$user_db_backup_file"
    fi
    
    copy_file "$factory_db_file" "$user_db_file"
    if [ "$?" = "0" ]; then
        echo "user_db_restore success" >> "$check_log_file"
        if [ ! -e "$reset_flag_file" ]; then
            reset_process
        fi
    else
        echo "user_db_restore failed" >> "$check_log_file"
    fi

    process_log
}

sqlite3_integrity_check()
{
    local result=""
    local is_err=""
    for i in `seq 3`; do
        #如果返回结果中没有error(忽略大小写)，则认为数据库是
        #完整的，终止检测；如果返回结果中有error，延时1s后继
        #续检测；如果第3次返回结果中还是有error，就执行恢复动作。
        result=`sqlite3 $user_db_file 'PRAGMA integrity_check' 2>&1`
        is_err=`echo $result | grep -i 'Error: database disk image is malformed'`
        echo "integrity_check result:\"$result\"" >> "$check_log_file"
        if [ -z "$is_err" ]; then
            break
        fi
        sleep 1
        echo "integrity_check $i times failed" >> "$check_log_file"
    done
    
    if [ -n "$is_err" ]; then
        echo "integrity_check failed" >> "$check_log_file"
        user_db_restore
    else
        echo "integrity_check success" >> "$check_log_file"
    fi
}

echo "#####$0 start#####" > "$check_log_file"
if [ ! -e "$user_db_file" ]; then
    echo "$user_db_file not exist" >> "$check_log_file"
    user_db_restore
elif [ ! -s "$user_db_file" ]; then
    echo "$user_db_file is zero byte" >> "$check_log_file"
    user_db_restore
else
    sqlite3_integrity_check
fi
echo "#####$0 end#####" >> "$check_log_file"

sync





