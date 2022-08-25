#!/bin/bash

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

DATE=`date +'%Y%m%d.%H%M'`

# get all running docker container names
containers=$(docker ps -a -f name=sma_ | awk '{if(NR>1) print $NF}')

if [ -z "$1" ]; then
	OUTPUT=sma_CONTAINER_LOGS_${DATE}.out

	echo "----- sma version" |& tee -a $OUTPUT
	sma_version > $OUTPUT 2>&1

	echo "----- sma env" |& tee -a $OUTPUT
	sma_env >> $OUTPUT 2>&1
else
	OUTPUT=$1
fi

echo "----- size docker containers" |& tee -a $OUTPUT
du -sh /var/lib/docker/containers >> $OUTPUT 2>&1

# loop through all containers
for container in $containers
do
	echo "----- $container" |& tee -a $OUTPUT
	sma_logs $container >> $OUTPUT 2>&1
done

if [ -z "$1" ]; then
	echo "DONE: $OUTPUT"
fi

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
