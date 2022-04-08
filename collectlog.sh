#!/bin/bash

'''
Script for collecting log files for Linux OS.
The script is used to collect diagnostic information for the day the problem was reproduced and the previous day.
The script must be run as root. Completion of work.
'''

input()
{
        #User entry of the date the problem occured in "YYYY-MM-DD" format.
        echo Enter the date of the problem occured. Input example - 2022-03-20
        read to
        #Checking the correctness of the entered date
        if (echo $to | grep -Eo '([[:digit:]]{4}-)([[:digit:]]{2}-)[[:digit:]]{2}'); then s=0; echo $to; else s=1; fi
        if [ "$s" -eq 1 ]
        then
                echo The date was entered icorrectly. Try again? y/n
                read choose
                case "$choose" in
                        [y]     ) input;;
                        [n]     ) exit;;
                        *       ) echo An invalid value was entered; input;;
                esac
        fi
        #Determining the start date for collecting logs.
        if [ ${to:8} -eq 01 ]
        then
                from=$(date -d "-$(date +%d) days" +%Y-%m-%d)
        else
                from=$(echo $to | cut -c1-8)$((${a:8}-1))
        fi
        #Formation of the list of archived files and the list of exclusions.
        array=($(cat $1))
        declare -a a
        declare -a b
        s=-1
        k=0
        for i in ${array[@]}
        do
                if [[ "${array[k]}" != "---" && $s -lt $k ]]; then
                        a[k]=$i
                        k=$(($k+1))
                        continue
                elif [ "${array[k]}" == "---" ]; then
                        s=${#array[@]}
                        k=$(($k+1))
                        continue
                elif [[ "${array[k]}" != "---" && $s -ge $k ]]; then
                        b[k]=$i
                        k=$(($k+1))
                        continue
                fi
        done
        #Search for files, matching a list and date range.
        files=($(find ${a[@]} -not -path ${b[@]} -newermt $from ! -newermt $to | tr '\n' ' ') $(find /var/log/syslog* /var/log/auth.log* /var/log/messages* /var/log/kern.log* /var/log/user.log* /var/log/debug* /var/log/postgresql/* /var/log/corosync/* /var/log/pacemaker.log* /var/log/daemon.log* -not -path "/var/log/debug/*" -newermt $to | tr '\n' ' '))
        count=${#files[@]}
        if [ $count -gt 0 ]
        then
                echo Files exists
                collectlogs ${files[*]}
        else
                echo The files don't exist. Try again? y/n
                read choose
                case "$choose" in
                        [y]     ) input;;
                        [n]     ) exit;;
                        *       ) echo An invalid value was entered; input;;
                esac
        fi
}
collectlogs()
{
        logdir=/var/log/debug/
        #Checking of the required free disk space.
        if [ $(df -h $(echo $logdir | cut -c 1-5) | awk 'NR==2{print $5}' | cut -c 1-2) -eq 100 ]; then
                echo -------------------------------------------------------------------
                echo No free disk space $(df -h $logdir | awk 'NR==2{print $1}'). Need to remove extra files on the mount point $(df -h $logdir | awk 'NR==2{print $6}'}) .
                echo -------------------------------------------------------------------
                exit
        elif [ $(df -h $(echo $logdir | cut -c 1-5) | awk 'NR==2{print $4}' | cut -c 1-2) -lt 10 ]; then
                echo -------------------------------------------------------------------
                echo Less than 10 GB of free disk space left $(df -h $logdir | awk 'NR==2{print $1}'). Need to remove extra files on the mount point $(df -h $logdir | awk 'NR==2{print $6}'}) .
                echo -------------------------------------------------------------------
                exit
        fi
        #Checking, if the archive directory exists.
        if [[ ! -d $logdir ]]; then mkdir $logdir; fi
        arch=$(uname -n)-$(date +"%Y%m%d-%H%M%S").zip
        #Archiving files/directories
        zip -9 -r -q -v $logdir$arch ${files[*]} -x "/var/log/debug/*"
        #Assigning permissions to a directory.
        chmod -R 755 $logdir
        #Checking the correctness of the collected archive.
        $(unzip -l $logdir$arch > /dev/null 2>&1)
        if [ $? -eq 0 ]
        then
                echo --------------------------------------------------------------------
                echo The log $arch is complited and located in the directory $logdir.
                echo After transferring the archive $arch, he must be deleted.
                echo --------------------------------------------------------------------
        else
                echo --------------------------------------------------------------------
                echo The log $arch is complited incorrectly.
                echo Please repeat the collection of the log.
                echo --------------------------------------------------------------------
                rm -f $logdir$arch
                input
        fi
}
#Checking, if a script is run with "sudo" privileges.
if [[ $EUID -ne 0 ]]; then
        echo --------------------------------------------------------------------
        echo The script ${0##*/} must be run with the root privileges. Completion of work.
        echo --------------------------------------------------------------------
        exit
fi
input $1
