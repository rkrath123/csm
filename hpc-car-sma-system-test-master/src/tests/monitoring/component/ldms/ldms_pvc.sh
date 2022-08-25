#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for LDMS data collection in HPE Cray's Shasta System Monitoring Application"
    echo "Verifies that the persistent volume claims are as expeccted"
    echo "$0 > sma_component_ldms_pvc-\`date +%Y%m%d.%H%M\`"
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
# Test case: Confirm LDMS Persistent Volume Claims
declare -a pvcs
declare -A pvcstatus
declare -A accessmode
declare -A storageclass
declare -A pvccap

# get pvc name, status, access mode and storage class
for i in $(kubectl -n sma get pvc | grep ldms | awk '{print $1}');
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

# Confirm ldms-compute-aggr-mellanox-pvc exists
if [[ " ${pvcs[@]} " =~ "ldms-compute-aggr-mellanox-pvc" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[ldms-compute-aggr-mellanox-pvc]} " =~ "Bound" ]]; then
        echo "ldms-compute-aggr-mellanox-pvc is ${pvcstatus[ldms-compute-aggr-mellanox-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-compute-aggr-mellanox-pvc ${pvcstatus[ldms-compute-aggr-mellanox-pvc]}")
    else
        echo "pvc ldms-compute-aggr-mellanox-pvc is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[ldms-compute-aggr-mellanox-pvc]} " =~ "ceph-cephfs-external" ]]; then
        echo "ldms-compute-aggr-mellanox-pvc is ${storageclass[ldms-compute-aggr-mellanox-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-compute-aggr-mellanox-pvc ${storageclass[ldms-compute-aggr-mellanox-pvc]}")
    else
        echo "ldms-compute-aggr-mellanox-pvc is using ${pvccap[ldms-compute-aggr-mellanox-pvc]} of ceph-cephfs-external storage"
    fi
    # Confirm access mode is RWX
    if [[ ! " ${accessmode[ldms-compute-aggr-mellanox-pvc]} " =~ "RWX" ]]; then
        echo "ldms-compute-aggr-mellanox-pvc has acccess mode ${accessmode[ldms-compute-aggr-mellanox-pvc]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - ldms-compute-aggr-mellanox-pvc ${pvcstatus[ldms-compute-aggr-mellanox-pvc]}")
    else
        echo "ldms-compute-aggr-mellanox-pvc has acccess mode RWX, as expected"
    fi
else
    echo "ldms-compute-aggr-mellanox-pvc pvc is missing. If this system uses mellanox, this indicates a problem."
    failures+=("LDMS PVCs - ldms-compute-aggr-mellanox-pvc pvc is missing: an error IF this system is using mellanox.")
fi
echo

# Confirm ldms-compute-aggr-pvc exists
if [[ " ${pvcs[@]} " =~ "ldms-compute-aggr-pvc" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[ldms-compute-aggr-pvc]} " =~ "Bound" ]]; then
        echo "ldms-compute-aggr-pvc is ${pvcstatus[ldms-compute-aggr-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-compute-aggr-pvc ${pvcstatus[ldms-compute-aggr-pvc]}")
    else
        echo "pvc ldms-compute-aggr-pvc is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[ldms-compute-aggr-pvc]} " =~ "ceph-cephfs-external" ]]; then
        echo "ldms-compute-aggr-pvc is ${storageclass[ldms-compute-aggr-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-compute-aggr-pvc ${storageclass[ldms-compute-aggr-pvc]}")
    else
        echo "ldms-compute-aggr-pvc is using ${pvccap[ldms-compute-aggr-pvc]} of ceph-cephfs-external storage"
    fi
    # Confirm access mode is RWX
    if [[ ! " ${accessmode[ldms-compute-aggr-pvc]} " =~ "RWX" ]]; then
        echo "ldms-compute-aggr-pvc has acccess mode ${accessmode[ldms-compute-aggr-pvc]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - ldms-compute-aggr-pvc ${pvcstatus[ldms-compute-aggr-pvc]}")
    else
        echo "ldms-compute-aggr-pvc has acccess mode RWX, as expected"
    fi
else
    echo "ldms-compute-aggr-pvc pvc is missing."
    errs=$((errs+1))
    failures+=("LDMS PVCs - ldms-compute-aggr-pvc pvc is missing.")
fi
echo

# Confirm ldms-compute-smpl-pvc exists
if [[ " ${pvcs[@]} " =~ "ldms-compute-smpl-pvc" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[ldms-compute-smpl-pvc]} " =~ "Bound" ]]; then
        echo "ldms-compute-smpl-pvc is ${pvcstatus[ldms-compute-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-compute-smpl-pvc ${pvcstatus[ldms-compute-smpl-pvc]}")
    else
        echo "pvc ldms-compute-smpl-pvc is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[ldms-compute-smpl-pvc]} " =~ "ceph-cephfs-external" ]]; then
        echo "ldms-compute-smpl-pvc is ${storageclass[ldms-compute-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-compute-smpl-pvc ${storageclass[ldms-compute-smpl-pvc]}")
    else
        echo "ldms-compute-smpl-pvc is using ${pvccap[ldms-compute-smpl-pvc]} of ceph-cephfs-external storage"
    fi
    # Confirm access mode is RWX
    if [[ ! " ${accessmode[ldms-compute-smpl-pvc]} " =~ "RWX" ]]; then
        echo "ldms-compute-smpl-pvc has acccess mode ${accessmode[ldms-compute-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - ldms-compute-smpl-pvc ${pvcstatus[ldms-compute-smpl-pvc]}")
    else
        echo "ldms-compute-smpl-pvc has acccess mode RWX, as expected"
    fi
else
    echo "ldms-compute-smpl-pvc pvc is missing."
    errs=$((errs+1))
    failures+=("LDMS PVCs - ldms-compute-smpl-pvc pvc is missing.")
fi
echo

# Confirm ldms-smpl-pvc exists
if [[ " ${pvcs[@]} " =~ "ldms-smpl-pvc" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[ldms-smpl-pvc]} " =~ "Bound" ]]; then
        echo "ldms-smpl-pvc is ${pvcstatus[ldms-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-smpl-pvc ${pvcstatus[ldms-smpl-pvc]}")
    else
        echo "pvc ldms-smpl-pvc is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[ldms-smpl-pvc]} " =~ "ceph-cephfs-external" ]]; then
        echo "ldms-smpl-pvc is ${storageclass[ldms-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-smpl-pvc ${storageclass[ldms-smpl-pvc]}")
    else
        echo "ldms-smpl-pvc is using ${pvccap[ldms-smpl-pvc]} of ceph-cephfs-external storage"
    fi
    # Confirm access mode is RWX
    if [[ ! " ${accessmode[ldms-smpl-pvc]} " =~ "RWX" ]]; then
        echo "ldms-smpl-pvc has acccess mode ${accessmode[ldms-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - ldms-smpl-pvc ${pvcstatus[ldms-smpl-pvc]}")
    else
        echo "ldms-smpl-pvc has acccess mode RWX, as expected"
    fi
else
    echo "ldms-smpl-pvc pvc is missing."
    errs=$((errs+1))
    failures+=("LDMS PVCs - ldms-smpl-pvc pvc is missing.")
fi
echo

# Confirm ldms-sms-aggr-mellanox-pvc exists
if [[ " ${pvcs[@]} " =~ "ldms-sms-aggr-mellanox-pvc" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[ldms-sms-aggr-mellanox-pvc]} " =~ "Bound" ]]; then
        echo "ldms-sms-aggr-mellanox-pvc is ${pvcstatus[ldms-sms-aggr-mellanox-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-sms-aggr-mellanox-pvc ${pvcstatus[ldms-sms-aggr-mellanox-pvc]}")
    else
        echo "pvc ldms-sms-aggr-mellanox-pvc is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[ldms-sms-aggr-mellanox-pvc]} " =~ "ceph-cephfs-external" ]]; then
        echo "ldms-sms-aggr-mellanox-pvc is ${storageclass[ldms-sms-aggr-mellanox-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-sms-aggr-mellanox-pvc ${storageclass[ldms-sms-aggr-mellanox-pvc]}")
    else
        echo "ldms-sms-aggr-mellanox-pvc is using ${pvccap[ldms-sms-aggr-mellanox-pvc]} of ceph-cephfs-external storage"
    fi
    # Confirm access mode is RWX
    if [[ ! " ${accessmode[ldms-sms-aggr-mellanox-pvc]} " =~ "RWX" ]]; then
        echo "ldms-sms-aggr-mellanox-pvc has acccess mode ${accessmode[ldms-sms-aggr-mellanox-pvc]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - ldms-sms-aggr-mellanox-pvc ${pvcstatus[ldms-sms-aggr-mellanox-pvc]}")
    else
        echo "ldms-sms-aggr-mellanox-pvc has acccess mode RWX, as expected"
    fi
else
    echo "ldms-sms-aggr-mellanox-pvc pvc is missing. If this system uses mellanox, this indicates a problem."
    failures+=("LDMS PVCs - ldms-sms-aggr-mellanox-pvc pvc is missing: an error IF this system is using mellanox.")
fi
echo

# Confirm ldms-sms-aggr-pvc exists
if [[ " ${pvcs[@]} " =~ "ldms-sms-aggr-pvc" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[ldms-sms-aggr-pvc]} " =~ "Bound" ]]; then
        echo "ldms-sms-aggr-pvc is ${pvcstatus[ldms-sms-aggr-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-sms-aggr-pvc ${pvcstatus[ldms-sms-aggr-pvc]}")
    else
        echo "pvc ldms-sms-aggr-pvc is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[ldms-sms-aggr-pvc]} " =~ "ceph-cephfs-external" ]]; then
        echo "ldms-sms-aggr-pvc is ${storageclass[ldms-sms-aggr-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-sms-aggr-pvc ${storageclass[ldms-sms-aggr-pvc]}")
    else
        echo "ldms-sms-aggr-pvc is using ${pvccap[ldms-sms-aggr-pvc]} of ceph-cephfs-external storage"
    fi
    # Confirm access mode is RWX
    if [[ ! " ${accessmode[ldms-sms-aggr-pvc]} " =~ "RWX" ]]; then
        echo "ldms-sms-aggr-pvc has acccess mode ${accessmode[ldms-sms-aggr-pvc]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - ldms-sms-aggr-pvc ${pvcstatus[ldms-sms-aggr-pvc]}")
    else
        echo "ldms-sms-aggr-pvc has acccess mode RWX, as expected"
    fi
else
    echo "ldms-sms-aggr-pvc pvc is missing."
    errs=$((errs+1))
    failures+=("LDMS PVCs - ldms-sms-aggr-pvc pvc is missing.")
fi
echo

# Confirm ldms-sms-smpl-pvc exists
if [[ " ${pvcs[@]} " =~ "ldms-sms-smpl-pvc" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[ldms-sms-smpl-pvc]} " =~ "Bound" ]]; then
        echo "ldms-sms-smpl-pvc is ${pvcstatus[ldms-sms-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-sms-smpl-pvc ${pvcstatus[ldms-sms-smpl-pvc]}")
    else
        echo "pvc ldms-sms-smpl-pvc is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[ldms-sms-smpl-pvc]} " =~ "ceph-cephfs-external" ]]; then
        echo "ldms-sms-smpl-pvc is ${storageclass[ldms-sms-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("LDMS PVCs - ldms-sms-smpl-pvc ${storageclass[ldms-sms-smpl-pvc]}")
    else
        echo "ldms-sms-smpl-pvc is using ${pvccap[ldms-sms-smpl-pvc]} of ceph-cephfs-external storage"
    fi
    # Confirm access mode is RWX
    if [[ ! " ${accessmode[ldms-sms-smpl-pvc]} " =~ "RWX" ]]; then
        echo "ldms-sms-smpl-pvc has acccess mode ${accessmode[ldms-sms-smpl-pvc]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - ldms-sms-smpl-pvc ${pvcstatus[ldms-sms-smpl-pvc]}")
    else
        echo "ldms-sms-smpl-pvc has acccess mode RWX, as expected"
    fi
else
    echo "ldms-sms-smpl-pvc pvc is missing."
    errs=$((errs+1))
    failures+=("LDMS PVCs - ldms-sms-smpl-pvc pvc is missing.")
fi
echo

unset pvcs
unset pvcstatus
unset accessmode
unset storageclass
unset pvccap


######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo  "LDMS cluster is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "LDMS persistent volume claims look good"
# in case there are mellanox-related warnings:
printf '%s\n' "${failures[@]}"

exit 0