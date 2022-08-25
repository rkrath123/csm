#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Grafana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that the pod is Running."
    echo "$0 > sma_component_grafana_pods-\`date +%Y%m%d.%H%M\`"
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

##############################################
# Test case: Grafana Pod Exists
podname=$(kubectl -n services get pods | grep sma-grafana- | awk '{print $1}');
podstatus=$(kubectl -n services --no-headers=true get pod $podname | awk '{print $3}');

if [[ "$podname" =~ "sma-grafana-" ]]; then
  if [[ "$podstatus" =~ "Running" ]]; then
    echo "$podname is Running";
  else
    echo "$podname is $podstatus"
    errs=$((errs+1))
    failures+=("Grafana pod - $podname is $podstatus")
  fi
else
  echo "sma-grafana pod is missing"
  errs=$((errs+1))
  failures+=("Grafana Pod - sma-grafana pod is missing")
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
echo "Grafana pod is in the expected state."

exit 0