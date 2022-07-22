#!/bin/bash
# PostgreSQL vacuum script for E2C DB Team
# Prepared by Kalyandeep Bagchi
# version 1.0
# usage <path_to_vacuumdb.sh>
set -x

# rotating vacuumdb logs
vacuumRotate(){
        cd /u05/pgcluster/$pgVer/exp/e2c_vacuumdb_logs/`hostname -f`/
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
        psqlPath=`find /local -type f -name "psql"`
        vacuumdbPath=`find /local -type f -name "vacuumdb"`
        pgVer=`$vacuumdbPath --version | awk '{print $(NF)}' | cut -d '.' -f 1`
        pgPort=`netstat -plunt | grep postgres | egrep -v tcp[6] | awk '{print $4}' | rev  | cut -d ':' -f 1 | rev`
        vacummLog=/u05/pgcluster/$pgVer/exp/e2c_vacuumdb_logs/$host/vacuumLogs-"`date +"%d-%m-%Y"-%H-%M-%S`.log"
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