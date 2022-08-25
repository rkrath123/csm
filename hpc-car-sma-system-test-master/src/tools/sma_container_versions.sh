#!/bin/bash

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

# get all running docker container names
containers=$(docker ps -f name=sma_ | awk '{if(NR>1) print $NF}')
host=$(hostname)

# show_version

# loop through all containers
for container in $containers
do
	echo "Container: $container"
	echo ------------------------------------
	CMD="docker exec -i $container sh -c 'date;hostname'"
	runit $CMD
	echo ------------------------------------
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
