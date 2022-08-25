#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Telemetry API in Cray's Shasta System Monitoring Application"
    echo "verifies that the gateway DNS is resolvable."
    echo "$0 > sma_component_telemetry_gateway-\`date +%Y%m%d.%H%M\`"
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
#Test Case: Gateway DNS is resolvable
ping=$(kubectl -n services exec -it ${telempod} -- ping -c 1 api-gw-service-nmn.local|grep "packet loss" | cut -d "," -f 3 | xargs);
if [[ "$ping" =~ "0% packet loss" ]]; then
  echo "Gateway DNS is resolvable";
else
  echo "Gateway DNS is unresolvable"
  errs=$((errs+1))
  failures+=("Telemetry Gateway - Gateway DNS is resolvable")
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
echo "Telemetry API can resolve gateway DNS"

exit 0