#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for rsyslog in Cray's Shasta System Monitoring Application"
    echo "tests that the aggregator pods are Running"
    echo "$0 > sma_component_rsyslog-aggregator_pods-\`date +%Y%m%d.%H%M\`"
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
# Test case: SMA rsyslog Aggregator Pods are Running
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep rsyslog-aggregator | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "rsyslog-aggregator-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "rsyslog-aggregator-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Rsyslog Aggregator Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "rsyslog-aggregator pods are missing"
  errs=$((errs+1))
  failures+=("Rsyslog Aggregator Pods - rsyslog-aggregator pods are missing")
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
echo "Rsyslog aggregator pods are in the expected state"

exit 0