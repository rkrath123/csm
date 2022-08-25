#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for the Telemetry API service in Cray's Shasta System Monitoring Application."
    echo "The test verifies the service is available"
    echo "$0 > sma_component_telemetry_service-\`date +%Y%m%d.%H%M\`"
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

###################
telempod=$(kubectl -n services get pods | grep telemetry | grep -v test | head -n 1 | cut -d ' ' -f 1);

###################
#Test Case: Telemetry is Running as a K8S Service
service=$(kubectl -n services get svc | grep telemetry | awk '{print $1}')
if [[ "$service" =~ "sma-telemetry" ]]; then
  echo "$service is available";
else
  echo "sma-telemetry service is missing"
  errs=$((errs+1))
  failures+=("Telemetry Service - sma-telemetry service is missing")
fi


######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Telemetry API is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Telemetry API service is available"

exit 0