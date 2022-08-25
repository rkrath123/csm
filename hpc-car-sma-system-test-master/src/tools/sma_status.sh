#!/bin/bash
# set -o xtrace
# set -o errexit
set -o nounset
set -o pipefail

numof_expected_containers=31
init_containers=( "sma_influxdb-init_1" "sma_thresh_1" "sma_grafana-init_1" "sma_mysql-init_1" "sma_alarms_1" )
ib_container=( "sma_infiniband_1" )
optional_containers=( "sma_ldms_1" "sma_system_test_1")

docker info > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "unable to talk to the docker daemon"
  exit 3
fi

errs=0
numof_containers=0

# get all docker container names
containers=$(docker ps -a -f name=sma_ | awk '{if(NR>1) print $NF}')
if [ -z "$containers" ]; then
	echo "SMA not running"
	exit 1
fi

# loop through all containers
for container in $containers
do
	numof_containers=$((numof_containers+1)) 
	for optional_container in $optional_containers
	do
		if [ "$container" == "$optional_container" ]; then
				numof_expected_containers=$((numof_expected_containers+1)) 
		fi
	done

	running=$(docker inspect --format="{{.State.Running}}" $container 2> /dev/null)
	if [ "$running" == "false" ]; then
		exitcode=$(docker inspect --format="{{.State.ExitCode}}" $container 2> /dev/null)
		echo "$container...stopped (exitcode=$exitcode)"

		# error if non-zero exit, ignore IB container error
		if [ "$exitcode" -gt 0 ] && [ "$container" != "$ib_container" ]; then
			errs=$((errs+1)) 
		fi
		continue
	else
		# error if init containers are still running
		exitcode=0
		for init_container in $init_containers
		do
			if [ "$container" == "$init_container" ]; then
				echo "$container...running (should be stopped)"
				exitcode=1
			fi
		done
		if [ "$exitcode" -gt 0 ]; then
			errs=$((errs+1)) 
			continue
		fi
	fi

	restarting=$(docker inspect --format="{{.State.Restarting}}" $container)

	if [ "$restarting" == "true" ]; then
		echo "$container...restarting"
		errs=$((errs+1)) 
		continue
	fi

	health=$(docker inspect --format "{{.State.Health.Status}}" $container 2> /dev/null)
	if [ $? -eq 0 ]; then
		if [ "$health" == "unhealthy" ]; then
			echo "$container...unhealthy"
			errs=$((errs+1)) 
			continue
		fi
	fi

	echo "$container...ok"
done

echo
# Uncle.  Gave up trying to validate all expected containers are running.
# if [ "$numof_containers" -ne "$numof_expected_containers" ]; then
#	echo "numof containers...not ok (expected=$numof_expected_containers got=$numof_containers)"
#	errs=$((errs+1)) 
# else
#	echo "numof containers...ok"
# fi

if [ "$(ls -A /etc/sma-data/core)" ]; then
 	echo "numof cores...not ok"
 	errs=$((errs+1)) 
else
	echo "numof cores...ok"
fi

echo
if [ "$errs" -gt 0 ]; then
	echo "SMA status...failed ($errs)"
	exit $errs
fi
echo "SMA status...ok"
exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
