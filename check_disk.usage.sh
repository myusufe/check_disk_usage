#!/bin/sh
#
# Muhammad Y Efendi
# myusufe@gmail.com
# v 1.0
#

# set -x
# Shell script to monitor or watch the disk space
# It will send an email to $ADMIN, if the (free available) percentage of space is >= ALERT%.
# -------------------------------------------------------------------------
# Set admin email so that you can get email.
ADMIN="myemail@mydomain.com"
# set alert level 70% is default
ALERT=70
SEND_EMAIL=0
PARTITION="/"
# Exclude list of unwanted monitoring, if several partions then use "|" to separate the partitions.
# An example: EXCLUDE_LIST="/dev/hdd1|/dev/hdc5"
EXCLUDE_LIST="/mnt"

NFS_SERVER="10.0.1.1" #NFS server IP address
HOSTNAME=`hostname`
DIST_DIR="/backup2/contrail/"
SOURCE_DIR="/var/crashes/"
FILE_NAME="core.contrail-vroute*"
MOUNT_DIR="/mnt"
LOG_FILE="/var/log/contrail_disk_monitoring.log"
TIMEOUT=20

function add_log() {
 echo "$(date) $1" >> $LOG_FILE
}

function create_dir() {
  if [ -d $MOUNT_DIR/$HOSTNAME ]
  then
    echo "Directory already existing"
    add_log "No create $MOUNT_DIR/$HOSTNAME directory, since its already exist"
  else
    mkdir $MOUNT_DIR/$HOSTNAME
    add_log "Create $MOUNT_DIR/$HOSTNAME directory"
  fi
}

function move_file() {

 for file_move in `ls -tlr $SOURCE_DIR$FILE_NAME| awk '{if ($5 != 0) print $9}' | head -n -1`
 do
     echo "Processing $file_move"
     cd $SOURCE_DIR
     cp $file_move $MOUNT_DIR/$HOSTNAME	
     cp /dev/null $file_move
     add_log "Copy $file_move to $MOUNT_DIR/$HOSTNAME directory"
 done  

}

function umount_nfs() {
 umount /mnt
 add_log "Make umount NFS"
}

function mount_nfs() {
  
# NFS file system appear to be mounted - lets check if we can access it ..
if mount | grep  $MOUNT_DIR ; then
	echo "/mnt already mounted now"
	add_log "/mnt already mounted now"

else
  # While we haven't used up all the attempts
  while [ $TIMEOUT -gt 0 ]; do
    # this will be true if 'ping' gets a response
    if ping -c 1 -W 1 $NFS_SERVER > /dev/null ; then
        mount -t nfs $NFS_SERVER:$DIST_DIR $MOUNT_DIR
        echo "NFS mounted"
	add_log "Make mount NFS /mnt"
        TIMEOUT=0
 
    # and if there's no response...
    else
        sleep 1
        TIMEOUT=$((TIMEOUT - 1))
        if [ $TIMEOUT -eq 0 ]; then
            echo "NFS Failed to mount - no response to server pings"
  	    add_log "NFS Failed to mount - no response to server pings"
        fi
    fi
  done

fi

}

function main_prog() {

  add_log "--- Start backup ---"

  while read output;
  do
#echo $output
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1)
  partition=$(echo $output | awk '{print $2}')
  if [ $usep -ge $ALERT ] ; then
     echo "Running out of space \"$partition ($usep%)\" on server $(hostname), $(date)" 
	add_log "Running out of space \"$partition ($usep%)\" on server $(hostname), $(date)"
	#Send alert
	if [ $SEND_EMAIL -eq 1 ] ; then
      		mail -s "Alert: Almost out of disk space $usep%" $ADMIN
		add_log "Send alert : Almost out of disk space $usep%"
	fi
	#Check and Make mounting
	mount_nfs
	create_dir
        move_file
        sleep 3
        umount_nfs
  fi
done

   add_log "--- Finished backup ---"
}


if [ "$EXCLUDE_LIST" != "" ] ; then
  df -H $PARTITION | grep -vE "^Filesystem|tmpfs|cdrom|${EXCLUDE_LIST}" | awk '{print $5 " " $6}' | main_prog
else
  df -H $PARTITION | grep -vE "^Filesystem|tmpfs|cdrom" | awk '{print $5 " " $6}' | main_prog
fi
