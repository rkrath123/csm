#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Grafana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that the service is available."
    echo "$0 > sma_component_grafana_service-\`date +%Y%m%d.%H%M\`"
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

#############################
# Test case: Grafana is Running as a K8S Service
service=$(kubectl -n services get svc | grep sma-grafana | awk '{print $1}')
if [[ "$service" =~ "sma-grafana" ]]; then
  echo "$service is available";
else
  echo "sma-grafana service is missing"
  errs=$((errs+1))
  failures+=("Grafana Service - sma-grafana service is missing")
fi

######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo "Grafana is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Grafana service is available"

exit 0