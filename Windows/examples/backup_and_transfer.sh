#!/bin/bash

REMOTE_USER="backupadmin"
REMOTE_HOST="backupserver.dystopia.local"
REMOTE_DIR="/srv/backups"
BACKUP_DIR="/var/backups"
DB_FILE="/var/lib/myapp/database.db"
LOG_FILE="/var/log/backup.log"

TIMESTAMP=$(date +%F_%H-%M-%S)
BACKUP_FILE="$BACKUP_DIR/database_$TIMESTAMP.db"

[ ! -f $LOG_FILE ] && touch $LOG_FILE

echo "[$TIMESTAMP] Starter backup..." >> $LOG_FILE

cp "$DB_FILE" "$BACKUP_FILE"
if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] Backup gennemført: $BACKUP_FILE" >> $LOG_FILE
else
    echo "[$TIMESTAMP] FEJL i backup-processen!" >> $LOG_FILE
    exit 1
fi

scp "$BACKUP_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR" >> $LOG_FILE 2>&1
if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] Backup overført til $REMOTE_HOST:$REMOTE_DIR" >> $LOG_FILE
else
    echo "[$TIMESTAMP] FEJL ved overførsel til $REMOTE_HOST" >> $LOG_FILE
    exit 1
fi