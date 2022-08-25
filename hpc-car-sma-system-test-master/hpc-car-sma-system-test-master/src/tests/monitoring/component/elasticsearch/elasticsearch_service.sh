#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies the service is available"
    echo "$0 > sma_component_elasticsearch_service-\`date +%Y%m%d.%H%M\`"
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

#########################################
# Test Case: Elasticsearch is Running as a K8S Service

declare -a svcs
for i in $(kubectl -n sma get svc | grep elastic | awk '{print $1}');
    do svcs+=($i);
done

if [[ " ${pods[@]} " -eq "elasticsearch" ]]; then
    echo "elasticsearch service exists"
else
    echo "elasticsearch service is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Services - elasticsearch service missing")
fi

if [[ " ${pods[@]} " -eq "elasticsearch-curator" ]]; then
    echo "elasticsearch-curator service exists"
else
    echo "elasticsearch-curator service is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Services - elasticsearch-curator service missing")
fi

if [[ " ${pods[@]} " -eq "elasticsearch-master" ]]; then
    echo "elasticsearch-master service exists"
else
    echo "elasticsearch-master service is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Services - elasticsearch-master service missing")
fi

if [[ " ${pods[@]} " -eq "elasticsearch-master-headless" ]]; then
    echo "elasticsearch-master-headless service exists"
else
    echo "elasticsearch-master-headless service is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Services - elasticsearch-master-headless service missing")
fi

unset svcs


#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch service is available"

exit 0