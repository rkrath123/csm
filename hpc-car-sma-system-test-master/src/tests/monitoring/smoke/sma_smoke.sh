#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the smoke test for HPE Cray's Shasta System Monitoring Application."
    echo "The test verifies that ldms and log data is collected and persisted."
    echo "$0 > sma_component_elasticsearch-\`date +%Y%m%d.%H%M\`"
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
unset hosts

#####################################
# Test Case: Recent LDMS data from ncn
# The following confirms that for each vmstat measurement type, ncn-w001 has reported data within the last 30 seconds.
declare -a hosts
pgmaster=$(kubectl -n sma get pod -l application=spilo -L spilo-role | grep master | awk '{print $1}')
for i in $(kubectl -n sma exec -i $pgmaster -c postgres -- psql sma -U postgres -t -c "select DISTINCT h.hostname from sma.ldms_data ld, sma.ldms_host h WHERE h.hostid=ld.hostid");
    do hosts+=($i);
done
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

#####################################
# Test Case: Recent LDMS data from ncn
# The following confirms that for each vmstat measurement type, ncn-w001 has reported data within the last 30 seconds.
declare -a hosts
pgmaster=$(kubectl -n sma get pod -l application=spilo -L spilo-role | grep master | awk '{print $1}')
for i in $(kubectl -n sma exec -i $pgmaster -c postgres -- psql sma -U postgres -t -c "select DISTINCT h.hostname from sma.ldms_data ld, sma.ldms_host h WHERE h.hostid=ld.hostid");
    do hosts+=($i);
done
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

#########################
#Test Case: Rsyslog Collects NCN Logs
time=$(date +%s)
ssh ncn-w002 logger "ncntest_$time"
search=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -X GET "elasticsearch:9200/_search?q=ncntest_${time}" | jq | grep ncntest | grep -v "q=" | cut -d '"' -f 4 | xargs)
if [[ " $search " =~ "ncntest_" ]]; then
  echo "Log collected from ncn";
else
  echo "Log collection from ncn failed"
  errs=$((errs+1))
  failures+=("Rsyslog Collects NCN Logs - Log collection from ncn failed")
fi

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "SMA is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "SMA looks healthy"

exit 0