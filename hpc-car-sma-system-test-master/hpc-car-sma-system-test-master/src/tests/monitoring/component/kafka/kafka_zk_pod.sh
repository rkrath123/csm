#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kafka messaging bus in Cray's Shasta System Monitoring Application"
    echo "tests that the zookeeper pods are Running."
    echo "$0 > sma_component_kafka_zk_pod-\`date +%Y%m%d.%H%M\`"
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


#################################
# Test case: ZK Pods Exist in SMA Namespace
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep zookeeper | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

# Confirm Pod is Running
if [[ " ${pods[@]} " =~ "cluster-zookeeper-0" ]]; then
    if [[ ! " ${podstatus[cluster-zookeeper-0]} " =~ "Running" ]]; then
    echo "cluster-zookeeper-0 is ${podstatus[cluster-zookeeper-0]} on ${podnode[cluster-zookeeper-0]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-0 ${podstatus[cluster-zookeeper-0]}")
    else
        echo "cluster-zookeeper-0 is Running"
    fi
else
    echo "cluster-zookeeper-0 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-0 is missing")
fi

if [[ " ${pods[@]} " =~ "cluster-zookeeper-1" ]]; then
    if [[ ! " ${podstatus[cluster-zookeeper-1]} " =~ "Running" ]]; then
    echo "cluster-zookeeper-1 is ${podstatus[cluster-zookeeper-1]} on ${podnode[cluster-zookeeper-1]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-1 ${podstatus[cluster-zookeeper-1]}")
    else
        echo "cluster-zookeeper-1 is Running"
    fi
else
    echo "cluster-zookeeper-1 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-1 is missing")
fi

if [[ " ${pods[@]} " =~ "cluster-zookeeper-2" ]]; then
    if [[ ! " ${podstatus[cluster-zookeeper-2]} " =~ "Running" ]]; then
    echo "cluster-zookeeper-2 is ${podstatus[cluster-zookeeper-2]} on ${podnode[cluster-zookeeper-2]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-2 ${podstatus[cluster-zookeeper-2]}")
    else
        echo "cluster-zookeeper-2 is Running"
    fi
else
    echo "cluster-zookeeper-2 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-2 is missing")
fi

unset pods
unset podstatus
unset podnode


######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Kafka is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Kafka zookeeper pods are in the expected state"

exit 0