#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for LDMS data collection in Cray's Shasta System Monitoring Application"
    echo "verifies the recent collection of data on ncn nodes."
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

############################

if [ "$errs" -gt 0 ]; then
	echo
	echo "LDMS Cluster is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "LDMS ncn data is recent and complete"

exit 0