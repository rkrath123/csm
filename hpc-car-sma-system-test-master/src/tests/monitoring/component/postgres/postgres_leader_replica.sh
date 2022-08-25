#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the leader and replica are running and in sync"
    echo "$0 > sma_component_postgres_leader_replica-\`date +%Y%m%d.%H%M\`"
    echo
    exit 1
}

while getopts h option
do
    case "${option}"
    in
        h) usage;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

declare -a failures
errs=0

postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)

#######################################
# Test Case: Leader Running
status=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Leader | cut -d '|' -f 5 | xargs")
if [[ $status == *running* ]]; then
    echo "Leader is Running"; else
    errs=$((errs+1))
    failures+=("No Running Leader found for SMA postgres cluster")
fi

#######################################
# Test Case: Replica Running
status=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Replica | cut -d '|' -f 5 | xargs")
if [[ $status == *running* ]]; then
    echo "Replica is Running"; else
    errs=$((errs+1))
    failures+=("No Running Replica found for SMA postgres cluster")
fi

#######################################
# Test Case: Timeline
ldrtl=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Leader | cut -d '|' -f 6 | xargs")
reptl=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Replica | cut -d '|' -f 6 | xargs")
if [[ $ldrtl == $reptl ]]; then
    echo "Timelines are consistent"; else
    errs=$((errs+1))
    failures+=("Leader and Replica Timelines are Different. Leader: $ldrtl Replica: $reptl")
fi

#######################################
# Test Case: Lag in MB
lag=$(kubectl -n sma exec -it $postgrespod -c postgres-- bash -c "patronictl list | grep Replica | cut -d '|' -f 7 | xargs")
echo "Replica lag in MB: $lag"

######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo  "Postgres cluster is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Postgres replication is working."

exit 0