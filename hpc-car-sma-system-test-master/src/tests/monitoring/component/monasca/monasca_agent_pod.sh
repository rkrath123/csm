#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the monasca alarm and notification service in Cray's"
    echo "System Monitoring Application verifies the agent pod is Running."
    echo "$0 > sma_component_monasca_agent_pod-\`date +%Y%m%d.%H%M\`"
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
# Test case: SMA Monasca Agent Pods are Running
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep monasca-agent | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "monasca-agent-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "monasca-agent-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Monasca Agent Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "monasca-agent pods are missing"
  errs=$((errs+1))
  failures+=("Monasca Agent Pods - sma-monasca-agent is missing")
fi

unset pods
unset podstatus
unset podnode


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
echo "Monasca agent pod is in the expected state"

exit 0