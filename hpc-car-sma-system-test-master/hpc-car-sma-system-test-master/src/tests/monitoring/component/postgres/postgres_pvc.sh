#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the persistent volume claims are as expeccted"
    echo "$0 > sma_component_postgres_pvc-\`date +%Y%m%d.%H%M\`"
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

###################################################
# Test case: Confirm Postgres Persistent Volume Claim
declare -a pvcs
declare -A pvcstatus
declare -A accessmode
declare -A storageclass
declare -A capacity

# get pvc name, status, access mode and storage class
for i in $(kubectl -n sma get pvc | grep postgres | awk '{print $1}');
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

# Confirm pgdata-sma-postgres-cluster-0 exists
if [[ " ${pvcs[@]} " =~ "pgdata-sma-postgres-cluster-0" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[pgdata-sma-postgres-cluster-0]} " =~ "Bound" ]]; then
        echo "pgdata-sma-postgres-cluster-0 is ${pvcstatus[pgdata-sma-postgres-cluster-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-0 ${pvcstatus[pgdata-sma-postgres-cluster-0]}")
    else
        echo "pvc pgdata-sma-postgres-cluster-0 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[pgdata-sma-postgres-cluster-0]} " =~ "sma-block-replicated" ]]; then
        echo "pgdata-sma-postgres-cluster-0 is ${storageclass[pgdata-sma-postgres-cluster-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-0 ${storageclass[pgdata-sma-postgres-cluster-0]}")
    else
        echo "pgdata-sma-postgres-cluster-0 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[pgdata-sma-postgres-cluster-0]} " =~ "RWO" ]]; then
        echo "pgdata-sma-postgres-cluster-0 has acccess mode ${accessmode[pgdata-sma-postgres-cluster-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-0 ${pvcstatus[pgdata-sma-postgres-cluster-0]}")
    else
        echo "pgdata-sma-postgres-cluster-0 has acccess mode RWO, as expected"
    fi
else
    echo "pgdata-sma-postgres-cluster-0 pvc is missing"
    errs=$((errs+1))
    failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-0 missing")
fi
echo

# Confirm pgdata-sma-postgres-cluster-1 exists
if [[ " ${pvcs[@]} " =~ "pgdata-sma-postgres-cluster-1" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[pgdata-sma-postgres-cluster-1]} " =~ "Bound" ]]; then
        echo "pgdata-sma-postgres-cluster-1 is ${pvcstatus[pgdata-sma-postgres-cluster-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-1 ${pvcstatus[pgdata-sma-postgres-cluster-1]}")
    else
        echo "pvc pgdata-sma-postgres-cluster-1 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[pgdata-sma-postgres-cluster-1]} " =~ "sma-block-replicated" ]]; then
        echo "pgdata-sma-postgres-cluster-1 is ${storageclass[pgdata-sma-postgres-cluster-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-1 ${storageclass[pgdata-sma-postgres-cluster-1]}")
    else
        echo "pgdata-sma-postgres-cluster-1 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[pgdata-sma-postgres-cluster-1]} " =~ "RWO" ]]; then
        echo "pgdata-sma-postgres-cluster-1 has acccess mode ${accessmode[pgdata-sma-postgres-cluster-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-1 ${pvcstatus[pgdata-sma-postgres-cluster-1]}")
    else
        echo "pgdata-sma-postgres-cluster-1 has acccess mode RWO, as expected"
    fi
else
    echo "pgdata-sma-postgres-cluster-1 pvc is missing"
    errs=$((errs+1))
    failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-1 missing")
fi

unset pvcs
unset pvcstatus
unset accessmode
unset storageclass
unset capacity


######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo  "Postgres cluster is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Postgres persistent volume claims look good"

exit 0