#!/bin/bash

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

DATE=`date +'%Y%m%d.%H%M'`
OUTPUT=sma_SNAPSHOT_${DATE}.out

echo "----- uname" |& tee -a $OUTPUT
uname -a >> $OUTPUT 2>&1

echo "----- cpu" |& tee -a $OUTPUT
lscpu >> $OUTPUT 2>&1

echo "----- uptime" |& tee -a $REPORT
uptime >> $OUTPUT 2>&1

echo "----- sma version" |& tee -a $OUTPUT
sma_version >> $OUTPUT 2>&1

echo "----- sma env" |& tee -a $OUTPUT
sma_env >> $OUTPUT 2>&1

echo "----- sma status" |& tee -a $OUTPUT
sma_status.sh >> $OUTPUT 2>&1

echo "----- sma ps" |& tee -a $OUTPUT
sma_ps >> $OUTPUT 2>&1

echo "----- sma config" |& tee -a $OUTPUT
ls -lh /var/sma/data >> $OUTPUT 2>&1
cat /var/sma/data/etc/site_config.yaml >> $OUTPUT 2>&1

echo "----- database stats" |& tee -a $OUTPUT
sma_database_stats.sh >> $OUTPUT 2>&1

sma_alarms.sh $OUTPUT

echo "DONE: $OUTPUT"
