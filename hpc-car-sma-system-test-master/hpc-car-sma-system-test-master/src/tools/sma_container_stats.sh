#!/bin/bash

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

# get all running docker container names
containers=$(docker ps -f name=sma_ | awk '{if(NR>1) print $NF}')
host=$(hostname)

# loop through all containers
for container in $containers
do
	CMD="docker stats $container --no-stream --format \"table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\""
	runit $CMD
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
