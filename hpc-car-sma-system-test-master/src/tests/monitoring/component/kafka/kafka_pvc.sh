#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kafka messaging bus in Cray's Shasta System Monitoring Application"
    echo "tests that the persistent volume claims are as expected."
    echo "$0 > sma_component_kafka_pvc-\`date +%Y%m%d.%H%M\`"
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


####################################
# Test case: Kafka Persistent Volume Claim
#   Kubernetes persistent volume claim for kafka is bound
declare -a pvcs
declare -A pvcstatus
declare -A accessmode
declare -A storageclass
declare -A pvccap

# get pvc name, status, access mode and storage class
for i in $(kubectl -n sma get pvc | grep kafka | awk '{print $1}');
    do pvcs+=($i);
    status=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $2}')
    pvcstatus[$i]=$status;
    capacity=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $4}')
    pvccap[$i]=$capacity;
    mode=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $5}')
    accessmode[$i]=$mode;
    class=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $6}')
    storageclass[$i]=$class;
done

# Confirm data-cluster-kafka-0 exists
if [[ " ${pvcs[@]} " =~ "data-cluster-kafka-0" ]]; then
    # confirm pvc is bound
    if [[ ! " ${pvcstatus[data-cluster-kafka-0]} " =~ "Bound" ]]; then
        echo "data-cluster-kafka-0 is ${pvcstatus[data-cluster-kafka-0]}"
        errs=$((errs+1))
        failures+=("kafka PVCs - data-cluster-kafka-0 ${pvcstatus[data-cluster-kafka-0]}")
    else
        echo "data-cluster-kafka-0 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[data-cluster-kafka-0]} " =~ "sma-block-replicated" ]]; then
        echo "data-cluster-kafka-0 is ${storageclass[pgdata-sma-postgres-cluster-0]}"
        errs=$((errs+1))
        failures+=("Kafka PVCs - data-cluster-kafka-0 ${storageclass[data-cluster-kafka-0]}")
    else
        echo "data-cluster-kafka-0 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[data-cluster-kafka-0]} " =~ "RWO" ]]; then
        echo "data-cluster-kafka-0 has acccess mode ${accessmode[data-cluster-kafka-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - data-cluster-kafka-0 ${pvcstatus[data-cluster-kafka-0]}")
    else
        echo "data-cluster-kafka-0 has acccess mode RWO, as expected"
    fi
    #Report capacity
    echo "data-cluster-kafka-0 has a capacity of ${pvccap[data-cluster-kafka-0]}"
else
    echo "data-cluster-kafka-0 pvc is missing"
    errs=$((errs+1))
    failures+=("Kafka PVCs - data-cluster-kafka-0 missing")
fi

# Confirm data-cluster-kafka-1 exists
if [[ " ${pvcs[@]} " =~ "data-cluster-kafka-1" ]]; then
    # confirm pvc is bound
    if [[ ! " ${pvcstatus[data-cluster-kafka-1]} " =~ "Bound" ]]; then
        echo "data-cluster-kafka-1 is ${pvcstatus[data-cluster-kafka-1]}"
        errs=$((errs+1))
        failures+=("kafka PVCs - data-cluster-kafka-1 ${pvcstatus[data-cluster-kafka-1]}")
    else
        echo "data-cluster-kafka-1 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[data-cluster-kafka-1]} " =~ "sma-block-replicated" ]]; then
        echo "data-cluster-kafka-1 is ${storageclass[pgdata-sma-postgres-cluster-1]}"
        errs=$((errs+1))
        failures+=("Kafka PVCs - data-cluster-kafka-1 ${storageclass[data-cluster-kafka-1]}")
    else
        echo "data-cluster-kafka-1 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[data-cluster-kafka-1]} " =~ "RWO" ]]; then
        echo "data-cluster-kafka-1 has acccess mode ${accessmode[data-cluster-kafka-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - data-cluster-kafka-1 ${pvcstatus[data-cluster-kafka-1]}")
    else
        echo "data-cluster-kafka-1 has acccess mode RWO, as expected"
    fi
    #Report capacity
    echo "data-cluster-kafka-1 has a capacity of ${pvccap[data-cluster-kafka-1]}"
else
    echo "data-cluster-kafka-1 pvc is missing"
    errs=$((errs+1))
    failures+=("Kafka PVCs - data-cluster-kafka-1 missing")
fi

# Confirm data-cluster-kafka-2 exists
if [[ " ${pvcs[@]} " =~ "data-cluster-kafka-2" ]]; then
    # confirm pvc is bound
    if [[ ! " ${pvcstatus[data-cluster-kafka-2]} " =~ "Bound" ]]; then
        echo "data-cluster-kafka-2 is ${pvcstatus[data-cluster-kafka-2]}"
        errs=$((errs+1))
        failures+=("kafka PVCs - data-cluster-kafka-2 ${pvcstatus[data-cluster-kafka-2]}")
    else
        echo "data-cluster-kafka-2 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[data-cluster-kafka-2]} " =~ "sma-block-replicated" ]]; then
        echo "data-cluster-kafka-2 is ${storageclass[pgdata-sma-postgres-cluster-2]}"
        errs=$((errs+1))
        failures+=("Kafka PVCs - data-cluster-kafka-2 ${storageclass[data-cluster-kafka-2]}")
    else
        echo "data-cluster-kafka-2 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[data-cluster-kafka-2]} " =~ "RWO" ]]; then
        echo "data-cluster-kafka-2 has acccess mode ${accessmode[data-cluster-kafka-2]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - data-cluster-kafka-2 ${pvcstatus[data-cluster-kafka-2]}")
    else
        echo "data-cluster-kafka-2 has acccess mode RWO, as expected"
    fi
    #Report capacity
    echo "data-cluster-kafka-2 has a capacity of ${pvccap[data-cluster-kafka-2]}"
else
    echo "data-cluster-kafka-2 pvc is missing"
    errs=$((errs+1))
    failures+=("Kafka PVCs - data-cluster-kafka-2 missing")
fi

unset pvcs
unset pvcstatus
unset accessmode
unset storageclass

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
echo "Kafka persistent volume claims look good"

exit 0