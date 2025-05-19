#!/bin/bash

# --- Configuration ---
LINUX_SOURCE_DIR="/var/named"         # folder to back up
WINDOWS_SHARE="//10.14.2.87/BackupShare"     #Windows server IP and share
MOUNT_POINT="/mnt/windows_backup"
USERNAME="xxxxxxx"                         # Windows username
PASSWORD="xxxxxxx"                        # Windows password
LOG_FILE="/var/log/linux-to-windows-backup.log"

# --- Create mount point if it doesn't exist ---
mkdir -p "$MOUNT_POINT"

# --- Mount the Windows share ---
echo "Mounting Windows share..." | tee -a "$LOG_FILE"
mount -t cifs "$WINDOWS_SHARE" "$MOUNT_POINT" -o username=$USERNAME,password=$PASSWORD,vers=3.0
if [ $? -ne 0 ]; then
  echo "❌ Failed to mount Windows share. Exiting." | tee -a "$LOG_FILE"
  exit 1
fi

# --- Perform the backup ---
echo "Starting rsync backup..." | tee -a "$LOG_FILE"
rsync -av --delete "$LINUX_SOURCE_DIR/" "$MOUNT_POINT/" | tee -a "$LOG_FILE"

# --- Unmount the share ---
echo "Unmounting Windows share..." | tee -a "$LOG_FILE"
umount "$MOUNT_POINT"

echo " Backup completed at $(date)" | tee -a "$LOG_FILE"
