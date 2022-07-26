#!/bin/bash
# PostgreSQL Physical Backup script
# Author: Kalyandeep Bagchi
# version 1.14
# usage <path_to_backup.sh> 2>&1 | tee -a <path_to_backupLogs.log>
# example /tmp/pg_backup.sh 2>&1 | tee -a /tmp/backupLogs.log
set -x

# cleaning up old physical backups
physicalBackupRotate(){
        cd $physicalBackupDir/..
        find . -type f -name "*.log" -mtime +30 -delete
        exit 0;
}

# check if PostgreSQL process is running
pgProc=`pgrep -u postgres_user_name -fa -- -D`
[[ -z $pgProc ]] && pgState=0 || pgState=1

case $pgState in
  0)
    exit 1;;
  1)
    # Environment details
    host=`hostname -f`
    psqlPath=`find /local -type f -name "psql" -print -quit`
    pg_basebackup=`find /local -type f -name "pg_basebackup" -print -quit`
    pgVer=`$psqlPath --version | awk '{print $(NF)}' | cut -d '.' -f 1`
    pgPort=`netstat -plunt | grep postgres | egrep -v tcp[6] | awk '{print $4}' | rev  | cut -d ':' -f 1 | rev`

    # Initiating backup directory...
    now=$(date +"%d-%h-%y")
    physicalBackupDir=/u05/pgcluster/$pgVer/exp/dumps/$host/physical_backup/$now # Physical backup dir
    [[ ! -d $physicalBackupDir ]] && mkdir -p $physicalBackupDir

    # check if Postgres instance is secondary or not
    pgState=`$psqlPath postgresql://$host:$pgPort/postgres -tc "select pg_is_in_recovery();" |head -1`

    if [ $pgState == t ]; then # when PostgreSQL node is Secondary / Read-only
        echo "PG Node not primary, proceesing with backup"
        
        # Initiating PostgreSQL Physical Backup
        $pg_basebackup -U repmgr --host=$host --port=$pgPort -w -D ${physicalBackupDir}/pg_basebackup -Ft -z -Xs -P -v
        
        # if using PostgreSQL tablespace, add the below section 
        # TBS_NAME=`$BIN_DIR/psql -d postgres --tuples-only --port=5454  -c "SELECT spcname FROM pg_tablespace where spcname NOT LIKE 'pg_%';" | awk '{print $1}'`
        # -T "${TBS_PATH}=${physicalBackupDir}/pg_basebackup/${TBS_NAME}"

        physicalBackupRotate # calling rotate physical backup directory function

    elif [ $pgState == f ];then # when PostgreSQL node is Primary / non-read-only
        echo "PG Node is Primary, Will not backup on this node"
        exit 0;

    else
        echo "Unable to determine state of the PostgreSQL on `hostname -f`, aborting!"
            exit 1;
    fi;;
esac