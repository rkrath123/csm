#!/bin/bash

# get all running docker container names
containers=$(docker ps -f name=sma_ | awk '{if(NR>1) print $NF}')
host=$(hostname)

# loop through all containers
for container in $containers
do
	echo "Container: $container"
	echo ------------------------------------
	docker top $container
	echo ------------------------------------
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
