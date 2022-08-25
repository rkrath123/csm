#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kibana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that the kibana pod is Running"
    echo "$0 > sma_component_kibana_pod-\`date +%Y%m%d.%H%M\`"
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
# Test case: Kibana Pod Exists in SMA Namespace
podname=$(kubectl -n services get pods | grep sma-kibana- | awk '{print $1}');
podstatus=$(kubectl -n services --no-headers=true get pod $podname | awk '{print $3}');

if [[ "$podname" =~ "sma-kibana-" ]]; then
  if [[ "$podstatus" =~ "Running" ]]; then
    echo "$podname is Running";
  else
    echo "$podname is $podstatus"
    errs=$((errs+1))
    failures+=("Kibana pod - $podname is $podstatus")
  fi
else
  echo "sma-kibana pod is missing"
  errs=$((errs+1))
  failures+=("Kibana Pod - sma-kibana pod is missing")
fi


######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo  "Kibana is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"

	exit 1
fi

echo
echo "Kibana pod is in the expected state"

exit 0