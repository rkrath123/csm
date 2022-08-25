#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the pods are in the expected states"
    echo "$0 > sma_component_postgres_pods-\`date +%Y%m%d.%H%M\`"
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

##############################################
# Test case: Confirm Postgres Pods are Running in SMA Namespace
declare -a pods
declare -A podstatus
declare -A podnode
pg_pods=('sma-postgres-cluster-0' 'sma-postgres-cluster-1')

# get name, status, and the node on which each postgres pod resides
for i in $(kubectl -n sma get pods | grep 'postgres' | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

for pod in "${pg_pods[@]}"
do
# Confirm each pod is Running
if [[ " ${pods[@]} " =~ $pod ]]; then
    if [[ ! " ${podstatus[$pod]} " =~ "Running" ]]; then
    echo "$pod is ${podstatus[$pod]} on ${podnode[$pod]}"
    errs=$((errs+1))
    failures+=("Postgres Pods - $pod ${podstatus[$pod]}")
    else
        echo "$pod is Running on ${podnode[$pod]}"
    fi
else
    echo "$pod is missing"
    errs=$((errs+1))
    failures+=("Postgres Pods - $pod is missing")
fi
done

#confirm each pod on a distinct node
dupnodes=$(printf '%s\n' ${pods[@]} | sort |uniq -d)
if [ -z $dupnodes]; then
    echo "Postgres Cluster pods are running on distinct nodes."
else
    echo "Postgres cluster pods are colocated!"
    errs=$((errs+1))
    failures+=("Postgres Pods - Postgres Cluster pods are running on the same node.")
fi

unset pods
unset podstatus
unset podnode

# get name, status, and the node on which each postgres persister pod resides
declare -a pods
declare -A podstatus
declare -A podnode

for i in $(kubectl -n sma get pods | grep sma-pg-persister | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "sma-pg-persister-" ]]; then
  for i in $(seq 0 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "sma-pg-persister-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Postgres Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "sma-pg-persister is missing"
  errs=$((errs+1))
  failures+=("Postgres Pods - sma-pg-persister is missing")
fi

unset pods
unset podstatus
unset podnode

# Test case: PGDB-prune Pod Exists
podname=$(kubectl -n sma get pods | grep sma-pgdb-prune | awk '{print $1}');
podstatus=$(kubectl -n sma --no-headers=true get pod $podname | awk '{print $3}');

if [[ "$podname" =~ "sma-pgdb-prune" ]]; then
  if [[ "$podstatus" =~ "Running" ]]; then
    echo "$podname is Running";
  else
    echo "$podname is $podstatus"
    errs=$((errs+1))
    failures+=("Postgres pod - $podname is $podstatus")
  fi
else
  echo "sma-pgdb-prune pod is missing"
  errs=$((errs+1))
  failures+=("Postgres Pod - sma-pgdb-prune pod is missing")
fi

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
echo "Postgres and Postgres Persister pods are in the expected state"

exit 0