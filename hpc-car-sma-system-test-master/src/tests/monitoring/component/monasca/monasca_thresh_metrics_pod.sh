#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the monasca alarm and notification service in Cray's"
    echo "System Monitoring Application verifies the thresh-metrics pod is Running."
    echo "$0 > sma_component_monasca_thresh_metrics_pod-\`date +%Y%m%d.%H%M\`"
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

monascapod=$(kubectl -n sma get pods | grep monasca-agent | head -n 1 | cut -d " " -f 1)

###################
# Test case: Monasca thresh-metrics-init Pod Completed in SMA Namespace
podname=$(kubectl -n sma get pods | grep sma-monasca-thresh-metrics-init-job | awk '{print $1}')
podstatus=$(kubectl -n sma get pods | grep sma-monasca-thresh-metrics-init-job | awk '{print $3}')
if [[ " $podname " =~ "sma-monasca-thresh-metrics-init-job-" ]]; then
  if [[ " $podstatus " =~ "Completed" ]]; then
    echo "sma-monasca-thresh-metrics pod is Completed";
  else
    echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
    errs=$((errs+1))
    failures+=("Monasca thresh-metrics-init Pod - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
  fi
else
  echo "sma-monasca-thresh-metrics-init-job pod is missing"
  errs=$((errs+1))
  failures+=("Monasca thresh-metrics-init Pod - sma-monasca-thresh-metrics-init-job is missing")
fi

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Monasca is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Monasca thresh-metrics pod is in the expected state"

exit 0