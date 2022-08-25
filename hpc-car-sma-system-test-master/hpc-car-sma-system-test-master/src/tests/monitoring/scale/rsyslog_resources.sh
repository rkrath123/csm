#!/bin/bash
# Copyright 2022 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for rsyslog in HPE Cray's Shasta System Monitoring Application"
    echo "reports the CPU and Memory utilization of each rsyslog pod, as well as the percentage of the limits that"
    echo "that number represents."
    echo "$0 > sma_component_rsyslog-\`date +%Y%m%d.%H%M\`"
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
# Test case: rsyslog Resources

# get cpu and memory limits from rsyslog aggregator statefulsets
aggcpulimit=$(kubectl -n sma describe statefulsets.apps rsyslog-aggregator | grep -v udp | grep cpu | head -n 1 |awk '{print $2}')
aggmemlimit=$(kubectl -n sma describe statefulsets.apps rsyslog-aggregator | grep -v udp | grep memory | head -n 1 |awk '{print $2}')
aggrawmemlimit=$(echo $aggmemlimit | numfmt --from=auto)

udpcpulimit=$(kubectl -n sma describe statefulsets.apps rsyslog-aggregator-udp | grep cpu | head -n 1 |awk '{print $2}')
udpmemlimit=$(kubectl -n sma describe statefulsets.apps rsyslog-aggregator-udp | grep memory | head -n 1 |awk '{print $2}')
udprawmemlimit=$(echo $udpmemlimit | numfmt --from=auto)

# get cpu and memory limits from rsyslog aggregator daemonsets
audcpulimit=$(kubectl -n sma describe daemonsets.apps rsyslog-auditlogs | grep cpu | head -n 1 |awk '{print $2}')
audmemlimit=$(kubectl -n sma describe daemonsets.apps rsyslog-auditlogs | grep memory | head -n 1 |awk '{print $2}')
audrawmemlimit=$(echo $audmemlimit | numfmt --from=auto)

colcpulimit=$(kubectl -n sma describe daemonsets.apps rsyslog-collector | grep cpu | head -n 1 |awk '{print $2}')
colmemlimit=$(kubectl -n sma describe daemonsets.apps rsyslog-collector | grep memory | head -n 1 |awk '{print $2}')
colrawmemlimit=$(echo $colmemlimit | numfmt --from=auto)

# get cpu and memory utilization for each ldms pod
for i in $(kubectl -n sma get pods | grep rsyslog-aggregator | grep -v udp | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $aggcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $aggcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $aggrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $aggmemlimit memory limit."
  done

for i in $(kubectl -n sma get pods | grep rsyslog-aggregator-udp | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $udpcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $udpcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $udprawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $udpmemlimit memory limit."
  done

for i in $(kubectl -n sma get pods | grep rsyslog-auditlogs | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $audcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $audcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $audrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $audmemlimit memory limit."
  done

for i in $(kubectl -n sma get pods | grep rsyslog-collector | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $colcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $colcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $colrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $colmemlimit memory limit."
  done

 exit 0
