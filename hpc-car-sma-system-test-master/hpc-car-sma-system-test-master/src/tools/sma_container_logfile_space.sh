#!/bin/bash

du -hs /var/lib/docker/containers/*/*-json.log | sort -rh | head -10
du -hs /var/log/sma/*
echo

# get all running docker container names
containers=$(docker ps -f name=sma_ | awk '{if(NR>1) print $NF}')
host=$(hostname)

# loop through all containers
for container in $containers
do
	echo "----- $container"
	docker inspect $container --format='{{.LogPath}}' | xargs ls -hl
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
