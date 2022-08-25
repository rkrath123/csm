#!/bin/bash
# Copyright 2022 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This test of the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "reports the CPU, Memory, and storage utilization of each pod, as well as the percentage of the limits that"
    echo "that number represents."
    echo "$0 > sma_component_postgres-\`date +%Y%m%d.%H%M\`"
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

#############################################
# Test case: Postgres Resources

# get cpu and memory limits from sma-postgres-cluster statefulsets
pgccpulimit=$(kubectl -n sma describe statefulsets.apps sma-postgres-cluster | grep cpu | head -n 1 |awk '{print $2}')
pgcmemlimit=$(kubectl -n sma describe statefulsets.apps sma-postgres-cluster | grep memory | head -n 1 |awk '{print $2}')
pgcrawmemlimit=$(echo $pgcmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-pg-persister replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-pg-persister | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
pgpcpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
pgpmemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
pgprawmemlimit=$(echo $pgpmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-pgdb-prune replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-pgdb-prune | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
dbpcpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
dbpmemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
dbprawmemlimit=$(echo $dbpmemlimit | numfmt --from=auto)

# get cpu and memory utilization for each sma-postgres-cluster pod
for i in $(kubectl -n sma get pods | grep sma-postgres-cluster | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $pgccpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $pgccpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $pgcrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $pgcmemlimit memory limit."

     # get data storage utilization for each sma-postgres-cluster pod
     volsize=$(kubectl -n sma exec -it  sma-postgres-cluster-0 -c postgres -- df -h | grep data | awk '{print $2}');
     volused=$(kubectl -n sma exec -it  sma-postgres-cluster-0 -c postgres -- df -h | grep data | awk '{print $3}');
     volpct=$(kubectl -n sma exec -it  sma-postgres-cluster-0 -c postgres -- df -h | grep data | awk '{print $5}');
     echo "pod $i is using $volused storage, $volpct of the $volsize total."
     echo
  done

# get cpu and memory utilization for each postgres-persister pod
for i in $(kubectl -n sma get pods | grep sma-pg-persister | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $pgpcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $pgpcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $pgprawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $pgpmemlimit memory limit."
  done

# get cpu and memory utilization for each pgdb-prune pod
for i in $(kubectl -n sma get pods | grep sma-pgdb-prune | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $dbpcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $dbpcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $dbprawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $dbpmemlimit memory limit."
  done

 exit 0
