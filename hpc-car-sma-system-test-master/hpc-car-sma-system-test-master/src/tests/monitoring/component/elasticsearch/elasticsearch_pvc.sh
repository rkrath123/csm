#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies that the expected Persistent Volume Claims are bound"
    echo "$0 > sma_component_elasticsearch_pvc-\`date +%Y%m%d.%H%M\`"
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

#######################################
# Test Case: Elasticsearch Persistent Volume Claim
#   Confirm Kubernetes persistent volume claim for elastic is bound
declare -a pvcs
declare -A pvcstatus
declare -A accessmode
declare -A storageclass

# get pvc name, status, access mode and storage class
for i in $(kubectl -n sma get pvc | grep elasticsearch | awk '{print $1}');
    do pvcs+=($i);
    status=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $2}')
    pvcstatus[$i]=$status;
    mode=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $5}')
    accessmode[$i]=$mode;
    class=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $6}')
    storageclass[$i]=$class;
done

# Confirm PVCs are bound
if [[ " ${pvcs[@]} " =~ "elasticsearch-master-elasticsearch-master-0" ]]; then
    if [[ ! " ${pvcstatus[elasticsearch-master-elasticsearch-master-0]} " =~ "Bound" ]]; then
        echo "elasticsearch-master-elasticsearch-master-0 is ${pvcstatus[elasticsearch-master-elasticsearch-master-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - elasticsearch-master-elasticsearch-master-0 ${pvcstatus[elasticsearch-master-elasticsearch-master-0]}")
    else
        echo "elasticsearch-master-elasticsearch-master-0 is Bound"
    fi
else
    echo "elasticsearch-master-elasticsearch-master-0 pvc is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch PVCs - elasticsearch-master-elasticsearch-master-0 missing")
fi

if [[ " ${pvcs[@]} " =~ "elasticsearch-master-elasticsearch-master-1" ]]; then
    if [[ ! " ${pvcstatus[elasticsearch-master-elasticsearch-master-1]} " =~ "Bound" ]]; then
        echo "elasticsearch-master-elasticsearch-master-1 is ${pvcstatus[elasticsearch-master-elasticsearch-master-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - elasticsearch-master-elasticsearch-master-1 ${pvcstatus[elasticsearch-master-elasticsearch-master-1]}")
    else
        echo "elasticsearch-master-elasticsearch-master-1 is Bound"
    fi
else
    echo "elasticsearch-master-elasticsearch-master-1 pvc is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch PVCs - elasticsearch-master-elasticsearch-master-1 missing")
fi

if [[ " ${pvcs[@]} " =~ "elasticsearch-master-elasticsearch-master-2" ]]; then
    if [[ ! " ${pvcstatus[elasticsearch-master-elasticsearch-master-2]} " =~ "Bound" ]]; then
        echo "elasticsearch-master-elasticsearch-master-2 is ${pvcstatus[elasticsearch-master-elasticsearch-master-2]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - elasticsearch-master-elasticsearch-master-2 ${pvcstatus[elasticsearch-master-elasticsearch-master-2]}")
    else
        echo "elasticsearch-master-elasticsearch-master-2 is Bound"
    fi
else
    echo "elasticsearch-master-elasticsearch-master-2 pvc is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch PVCs - elasticsearch-master-elasticsearch-master-2 missing")
fi

unset pvcs
unset pvcstatus
unset accessmode
unset storageclass
#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch looks healthy"

exit 0