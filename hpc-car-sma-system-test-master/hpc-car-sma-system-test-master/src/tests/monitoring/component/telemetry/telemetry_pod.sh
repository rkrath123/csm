#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Telemetry API in Cray's Shasta System Monitoring Application"
    echo "verifies that the expected pod is up and running."
    echo "$0 > sma_component_telemetry_pods-\`date +%Y%m%d.%H%M\`"
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
#Test Case: Telemetry Pod Exists in SMA Namespace
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n services get pods | grep telemetry | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n services --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n services --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "sma-telemetry-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "sma-telemetry-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Telemetry Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "telemetry pods are missing"
  errs=$((errs+1))
  failures+=("Telemetry Pods - sma-telemetry pods are missing")
fi

unset pods
unset podstatus
unset podnode

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
echo "Telemetry API pod is in the expected state"

exit 0