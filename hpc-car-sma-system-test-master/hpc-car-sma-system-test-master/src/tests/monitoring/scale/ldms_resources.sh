#!/bin/bash
# Copyright 2022 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for LDMS data collection in HPE Cray's Shasta System Monitoring Application"
    echo "reports the CPU and Memory utilization of each LDMS pod, as well as the percentage of the limits that"
    echo "that number represents."
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
exit 0
