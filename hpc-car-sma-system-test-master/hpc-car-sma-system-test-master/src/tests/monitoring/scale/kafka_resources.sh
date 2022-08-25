#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kafka messaging bus in HPE Cray's Shasta System Monitoring Application"
    echo "reports the CPU and Memory utilization of each kafka pod, as well as the percentage of the limits that"
    echo "that number represents."
    echo "$0 > sma_component_kafka-\`date +%Y%m%d.%H%M\`"
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
# Test case: Kafka Resources

# get cpu and memory limits from kafka statefulset
cpulimit=$(kubectl -n sma describe statefulsets.apps cluster-kafka | grep cpu | head -n 1 |awk '{print $2}')
memlimit=$(kubectl -n sma describe statefulsets.apps cluster-kafka | grep memory | head -n 1 |awk '{print $2}')
rawmemlimit=$(echo $memlimit | numfmt --from=auto)

# get cpu and memory utilization for each kafka pod
memtotal=0
cputotal=0
for i in $(kubectl -n sma get pods | grep kafka | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $cpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $cpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $rawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $memlimit memory limit."
  done


exit 0
