#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for LDMS data collection in HPE Cray's Shasta System Monitoring Application"
    echo "verifies the expected pods and their states."
    echo "$0 > sma_component_ldms_pods-\`date +%Y%m%d.%H%M\`"
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


#######################
# Test Case: "Confirm ldms Pods are Running in SMA Namespace"
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep ldms | awk '{print $1}');
    do pods+=($i);
    podstatus[$i]=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podnode[$i]=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    echo $i" is "${podstatus[$i]}" on "${podnode[$i]};
done

# Confirm Pod is Running
if [[ " ${pods[@]} " =~ "sma-ldms-aggr-compute-0" ]]; then
  if [[ " ${podstatus["sma-ldms-aggr-compute-0"]} " =~ "Running" ]]; then
    echo "sma-ldms-aggr-compute-0 is Running";
  else
    echo "sma-ldms-aggr-compute-0 is ${podstatus["sma-ldms-aggr-compute-0"]}"
    errs=$((errs+1))
    failures+=("LDMS Pods - sma-ldms-aggr-compute-0 is ${podstatus["sma-ldms-aggr-compute-0"]}")
  fi
else
  echo "sma-ldms-aggr-compute-0 is missing"
  errs=$((errs+1))
  failures+=("LDMS Pods - sma-ldms-aggr-compute-0 is missing")
fi

if [[ " ${pods[@]} " =~ "sma-ldms-aggr-ncn-0" ]]; then
  if [[ " ${podstatus[sma-ldms-aggr-ncn-0]} " =~ "Running" ]]; then
    echo "sma-ldms-aggr-ncn-0 is Running";
  else
    echo "sma-ldms-aggr-ncn-0 is ${podstatus[sma-ldms-aggr-ncn-0]}"
    errs=$((errs+1))
    failures+=("LDMS Pods - sma-ldms-aggr-ncn-0 is ${podstatus[sma-ldms-aggr-ncn-0]}")
  fi
else
  echo "sma-ldms-aggr-ncn-0 is missing"
  errs=$((errs+1))
  failures+=("LDMS Pods - sma-ldms-aggr-ncn-0 is missing")
fi

unset pods
unset podstatus
unset podnode

############################

if [ "$errs" -gt 0 ]; then
	echo
	echo "LDMS Cluster is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "LDMS pods are in the expected state"

exit 0