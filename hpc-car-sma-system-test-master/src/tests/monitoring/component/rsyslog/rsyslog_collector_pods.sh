#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for rsyslog in Cray's Shasta System Monitoring Application"
    echo "The test focuses on verification of a valid environment and initial configuration, and"
    echo "tests that the collector pods are running"
    echo "$0 > sma_component_rsyslog_collector_pods-\`date +%Y%m%d.%H%M\`"
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
# Test case: SMA rsyslog Collector Pods are Running
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep rsyslog-collector- | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "rsyslog-collector-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "rsyslog-collector-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Rsyslog Collector Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "rsyslog-collector pods are missing"
  errs=$((errs+1))
  failures+=("Rsyslog Collector Pods - rsyslog-collector pods are missing")
fi

unset pods
unset podstatus
unset podnode

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Rsyslog is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Rsyslog collector pods are in the expected state"

exit 0