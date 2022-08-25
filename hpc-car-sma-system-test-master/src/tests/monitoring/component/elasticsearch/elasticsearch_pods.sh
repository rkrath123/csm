#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies the expected pods are up and Running"
    echo "$0 > sma_component_elasticsearch_pods-\`date +%Y%m%d.%H%M\`"
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

#############################################
# Test Case: Elasticsearch Pods Exists in SMA Namespace

curatorstatus=$(kubectl -n sma get pods | grep elasticsearch-curator | awk '{print $3}')
if [[ ! $curatorstatus ]]; then
    echo "elasticsearch-curator is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-curator not found")
elif [[ ! $curatorstatus == "Running" ]]; then
    echo "elasticsearch-curator is $curatorstatus"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-curator $curatorstatus")
else
    echo "elasticsearch-curator is Running"
fi

master0status=$(kubectl -n sma get pods | grep elasticsearch-master-0 | awk '{print $3}')
if [[ ! $master0status ]]; then
    echo "elasticsearch-master-0 is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-0 not found")
elif [[ ! $master0status == "Running" ]]; then
    echo "elasticsearch-master-0 is $master0status"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-0 $master0status")
else
    echo "elasticsearch-master-0 is Running"
fi

master1status=$(kubectl -n sma get pods | grep elasticsearch-master-1 | awk '{print $3}')
if [[ ! $master1status ]]; then
    echo "elasticsearch-master-1 is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-1 not found")
elif [[ ! $master1status == "Running" ]]; then
    echo "elasticsearch-master-1 is $master1status"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-1 $master0status")
else
    echo "elasticsearch-master-1 is Running"
fi

master2status=$(kubectl -n sma get pods | grep elasticsearch-master-2 | awk '{print $3}')
if [[ ! $master2status ]]; then
    echo "elasticsearch-master-2 is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-2 not found")
elif [[ ! $master2status == "Running" ]]; then
    echo "elasticsearch-master-2 is $master2status"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-2 $master0status")
else
    echo "elasticsearch-master-2 is Running"
fi


#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch pods are in the expected state"

exit 0