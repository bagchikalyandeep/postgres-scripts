#!/bin/bash
# PostgreSQL vacuum script
# Prepared by Kalyandeep Bagchi
# version 1.14
# usage <path_to_vacuumdb.sh>
# use your own <vacummLog_path> to store vacuumdb logs. I have used my own.
set -x

# rotating vacuumdb logs
vacuumRotate(){
        cd /u05/pgcluster/$pgVer/exp/vacuumdb_logs/`hostname -f`/
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
        vacuumdbPath=`find /local -type f -name "vacuumdb" -print -quit`
        pgVer=`$vacuumdbPath --version | awk '{print $(NF)}' | cut -d '.' -f 1`
        pgPort=`netstat -plunt | grep postgres | egrep -v tcp[6] | awk '{print $4}' | rev  | cut -d ':' -f 1 | rev`
        vacummLog=/u05/pgcluster/$pgVer/exp/vacuumdb_logs/$host/vacuumLogs-"`date +"%d-%m-%Y"-%H-%M-%S`.log"
        touch $vacummLog

        # check if Postgres instance is primary or not
        pgState=`$psqlPath postgresql://$host:$pgPort/postgres -tc "select pg_is_in_recovery();" |head -1`

        if [ $pgState == t ]; then # when PostgreSQL node is Secondary / Read-only
                echo "PG Node not primary, aborting!"
                exit 0;

        elif [ $pgState == f ];then # when PostgreSQL node is Primary / non-read-only
                $vacuumdbPath -azv --host=$host --port=$pgPort 2>&1 | tee $vacummLog
                # calling vacuumdb logrotate function
                vacuumRotate
        else
                echo "Unable to determine state of the PostgreSQL on `hostname -f`, aborting!"
                exit 1;
        fi;;
esac