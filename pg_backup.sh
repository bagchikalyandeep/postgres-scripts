#!/bin/bash
# PostgreSQL vacuum script for E2C DB Team
# Prepared by Kalyandeep Bagchi
# version 1.0
# usage <path_to_vacuumdb.sh> 2>&1 | tee <path_to_backupLogs>
set -x

# rotating vacuumdb logs
backupRotate(){
        cd $backupDir/..
        find . -type f -name "*.log" -mtime +30 -delete
        exit 0;
}

# check if PostgreSQL process is running
pgProc=`pgrep -u e2cpostgre -fa -- -D`
[[ -z $pgProc ]] && pgState=0 || pgState=1

case $pgState in
  0)
    exit 1;;
  1)
    # Environment details
    host=`hostname -f`
    psqlPath=`find /local -type f -name "psql" -print -quit`
    pg_dumpall=`find /local -type f -name "pg_dumpall" -print -quit`
    pg_dump=`find /local -type f -name "pg_dump" -print -quit`
    pgVer=`$pg_dump --version | awk '{print $(NF)}' | cut -d '.' -f 1`
    pgPort=`netstat -plunt | grep postgres | egrep -v tcp[6] | awk '{print $4}' | rev  | cut -d ':' -f 1 | rev`
    pgPass=`cat ~/.pgpass | grep localhost | rev | cut -d ':' -f 1 | rev`

    # Initiating backup directory...
    now=$(date +"%d-%h-%y")
    backupDir=/u05/pgcluster/$pgVer/exp/e2c_dumps/$host/logical_backup/$now
    [[ ! -d $backupDir ]] && mkdir -p $backupDir 

    # check if Postgres instance is secondary or not
    pgState=`$psqlPath postgresql://$host:$pgPort/postgres -tc "select pg_is_in_recovery();" |head -1`

    if [ $pgState == t ]; then # when PostgreSQL node is Secondary / Read-only
        echo "PG Node not primary, proceesing with backup"

        # backup globals
        $pg_dumpall --host=$host --port=$pgPort --globals-only | gzip > $backupDir/postgres_globals.sql.gz

        # backup individual databases
        for db in `$psqlPath --host=$host --port=$pgPort -d postgres -t -c "select datname from pg_database where not datistemplate" | grep '\S' | awk '{$1=$1};1'`; do
            $pg_dump --host=$host --port=$pgPort $db | gzip > $backupDir/$db.sql.gz
        done

        # calling rotate backup directory function
        backupRotate

    elif [ $pgState == f ];then # when PostgreSQL node is Primary / non-read-only
        echo "PG Node is Primary, Will not backup on this node"
        exit 0;

    else
        echo "Unable to determine state of the PostgreSQL on `hostname -f`, aborting!"
            exit 1;
    fi;;
esac