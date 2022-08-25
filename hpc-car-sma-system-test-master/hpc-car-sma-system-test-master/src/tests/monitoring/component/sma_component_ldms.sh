#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for LDMS data collection in Cray's Shasta System Monitoring Application."
    echo "The test verifies a valid initial state as well as the recent collection of data on ncn and compute nodes."
    echo "$0 > sma_component_ldms-\`date +%Y%m%d.%H%M\`"
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


#######################
# Test Case: "Confirm LDMS configuration job completed"
configjob=$(kubectl -n sma get job | grep sma-ldms-config | awk '{print $1}')
completed=$(kubectl -n sma get job | grep sma-ldms-config | awk '{print $2}')
if [[ " $configjob " =~ "sma-ldms-config" ]]; then
  if [[ " $completed " =~ "1/1" ]]; then
    echo " sma-ldms-config job completed";
  else
    echo "sma-ldms-config job reports $completed completions."
    errs=$((errs+1))
    failures+=("LDMS config job - sma-ldms-config job reports $completed completions.")
  fi
else
  echo "sma-ldms-config is missing"
  errs=$((errs+1))
  failures+=("LDMS Pods - sma-ldms-config is missing")
fi

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

#####################################
# Test Case: Recent LDMS data from compute
# The following confirms that for each vmstat measurement type, a reporting compute has reported data within the last 30 seconds.
declare -a hosts
pgmaster=$(kubectl -n sma get pod -l application=spilo -L spilo-role | grep master | awk '{print $1}')
echo "Gathering host data..."
for i in $(kubectl -n sma exec -i $pgmaster -c postgres -- psql sma -U postgres -t -c "select DISTINCT h.hostname from sma.ldms_data ld, sma.ldms_host h WHERE h.hostid=ld.hostid");
    do hosts+=($i);
done

if [[ " ${hosts[@]} " =~ "nid" ]]; then
  for i in $(printf '%s\n' "${hosts[@]}");
      do if [[ " $i " =~ "nid" ]]; then
      compute=$i
      fi
  done
  for vmstat in $(kubectl -n sma exec -i $pgmaster -c postgres -- bash -c "psql sma -U postgres -t -c \"select DISTINCT m.measurementtypeid from sma.ldms_data ld, sma.ldms_host h, sma.measurementsource m WHERE h.hostid=ld.hostid AND h.hostname='$compute' AND ld.measurementtypeid=m.measurementtypeid ORDER BY m.measurementtypeid\"");
    do t1=$(kubectl -n sma exec -i $pgmaster -c postgres -- bash -c "date +%s");
    t2=$(kubectl -n sma exec -i $pgmaster -c postgres -- bash -c "psql sma -U postgres -t -c \"select EXTRACT (epoch from(select ts from sma.ldms_data d, sma.ldms_host h WHERE h.hostid=d.hostid AND d.measurementtypeid='$vmstat' AND h.hostname='$compute' ORDER BY ts DESC LIMIT 1))\""| cut -d "." -f 1 | xargs);
    age=$(($t1-$t2));
    vmstatname=$(kubectl -n sma exec -i $pgmaster -c postgres -- bash -c "psql sma -U postgres -t -c \"select measurementname from sma.measurementsource WHERE measurementtypeid=$vmstat\"");
      if [[ $age -gt 30 ]]; then
         echo "LDMS data from $vmstatname on $compute not updated in last 30 seconds"
         errs=$((errs+1))
      failures+=("LDMS data from $vmstatname on $compute not updated in last 30 seconds")
      else
         echo "LDMS data from $vmstatname on $compute was updated $age seconds ago"
      fi
   done
else
  echo "LDMS data from compute $compute is missing"
  errs=$((errs+1))
  failures+=("LDMS data - no data exists for compute $compute")
fi

#####################################
# Test Case: Recent LDMS data from ncn
# The following confirms that for each vmstat measurement type, ncn-w001 has reported data within the last 30 seconds.
if [[ " ${hosts[@]} " =~ "ncn-w001" ]]; then
  for vmstat in $(kubectl -n sma exec -i $pgmaster -c postgres -- psql sma -U postgres -t -c "select DISTINCT m.measurementtypeid from sma.ldms_data ld, sma.ldms_host h, sma.measurementsource m WHERE h.hostid=ld.hostid AND h.hostname='ncn-w001' AND ld.measurementtypeid=m.measurementtypeid ORDER BY m.measurementtypeid");
   do kubectl -n sma exec -i $pgmaster -c postgres -- bash -c 't1=$(date +%s);\
      t2=$(psql sma -U postgres -t -c "select EXTRACT (epoch from(select ts from sma.ldms_data d, sma.ldms_host h WHERE h.hostid=d.hostid AND d.measurementtypeid='$vmstat' AND h.hostname='\''ncn-w001'\'' ORDER BY ts DESC LIMIT 1))"|cut -d '.' -f 1);\
      age=$(($t1-$t2)); vmstatname=$(psql sma -U postgres -t -c "select measurementname from sma.measurementsource WHERE measurementtypeid='$vmstat'");
      if [ $age -gt 30 ]; then
         echo "LDMS data from $vmstatname on ncn-w001 not updated in last 30 seconds"
         errs=$((errs+1))
         failures+=("LDMS data from $vmstatname on ncn-w001 not updated in last 30 seconds")
      else
         echo "LDMS data from $vmstatname on ncn-w001 updated $age seconds ago"
      fi'
   done
else
  echo "LDMS data from node ncn-w001 is missing"
  errs=$((errs+1))
  failures+=("LDMS data - no data exists for ncn-w001")
fi
unset hosts

#############################################
# Test case: LDMS Resources

# get cpu and memory limits from ldms statefulsets
ncncpulimit=$(kubectl -n sma describe statefulsets.apps sma-ldms-aggr-ncn | grep cpu | head -n 1 |awk '{print $2}')
ncnmemlimit=$(kubectl -n sma describe statefulsets.apps sma-ldms-aggr-ncn | grep memory | head -n 1 |awk '{print $2}')
ncnrawmemlimit=$(echo $ncnmemlimit | numfmt --from=auto)

cmpcpulimit=$(kubectl -n sma describe statefulsets.apps sma-ldms-aggr-compute | grep cpu | head -n 1 |awk '{print $2}')
cmpmemlimit=$(kubectl -n sma describe statefulsets.apps sma-ldms-aggr-compute | grep memory | head -n 1 |awk '{print $2}')
cmprawmemlimit=$(echo $cmpmemlimit | numfmt --from=auto)

# get cpu and memory utilization for each ldms pod
for i in $(kubectl -n sma get pods | grep sma-ldms-aggr-ncn | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $ncncpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $ncncpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $ncnrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $ncnmemlimit memory limit."
  done
for i in $(kubectl -n sma get pods | grep sma-ldms-aggr-compute | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $cmpcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $cmpcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $cmprawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $cmpmemlimit memory limit."
  done

############################

if [ "$errs" -gt 0 ]; then
	echo
	echo "LDMS Cluster is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "LDMS looks healthy"

exit 0