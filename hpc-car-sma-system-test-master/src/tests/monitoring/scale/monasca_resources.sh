#!/bin/bash
# Copyright 2022 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This test of the monasca alarm and notification service in Cray's Shasta System Monitoring Application"
    echo "reports the CPU and Memory utilization of each pod, as well as the percentage of the limits that"
    echo "that number represents."
    echo "$0 > sma_component_monasca-\`date +%Y%m%d.%H%M\`"
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
# Test case: Monasca Resources

# get cpu and memory limits from sma-monasca-agent statefulsets
agtcpulimit=$(kubectl -n sma describe statefulsets.apps sma-monasca-agent | grep cpu | head -n 1 |awk '{print $2}')
# if memory is in milliCPUs,
if [[ "$agtcpulimit" == *"m" ]]; then agtcpulimit=$(echo $agtcpulimit | cut -d "m" -f 1); agtcpulimit=$(echo "scale=2 ; $agtcpulimit / 1000" | bc);fi
agtmemlimit=$(kubectl -n sma describe statefulsets.apps sma-monasca-agent | grep memory | head -n 1 |awk '{print $2}')
agtrawmemlimit=$(echo $agtmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-monasca-mysql statefulsets
sqlcpulimit=$(kubectl -n sma describe statefulsets.apps sma-monasca-mysql | grep cpu | head -n 1 |awk '{print $2}')
if [[ "$sqlcpulimit" == *"m" ]]; then sqlcpulimit=$(echo $sqlcpulimit | cut -d "m" -f 1); sqlcpulimit=$(echo "scale=2 ; $sqlcpulimit / 1000" | bc);fi
sqlmemlimit=$(kubectl -n sma describe statefulsets.apps sma-monasca-mysql | grep memory | head -n 1 |awk '{print $2}')
sqlrawmemlimit=$(echo $sqlmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-monasca-notification statefulsets
notcpulimit=$(kubectl -n sma describe statefulsets.apps sma-monasca-notification | grep cpu | head -n 1 |awk '{print $2}')
if [[ "$notcpulimit" == *"m" ]]; then notcpulimit=$(echo $notcpulimit | cut -d "m" -f 1); notcpulimit=$(echo "scale=2 ; $notcpulimit / 1000" | bc);fi
notmemlimit=$(kubectl -n sma describe statefulsets.apps sma-monasca-notification | grep memory | head -n 1 |awk '{print $2}')
notrawmemlimit=$(echo $notmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-monasca-api replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-monasca-api | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
apicpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
if [[ "$apicpulimit" == *"m" ]]; then apicpulimit=$(echo $apicpulimit | cut -d "m" -f 1); apicpulimit=$(echo "scale=2 ; $apicpulimit / 1000" | bc);fi
apimemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
apirawmemlimit=$(echo $apimemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-monasca-keystone replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-monasca-keystone | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
keycpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
if [[ "$keycpulimit" == *"m" ]]; then keycpulimit=$(echo $keycpulimit | cut -d "m" -f 1); keycpulimit=$(echo "scale=2 ; $keycpulimit / 1000" | bc);fi
keymemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
keyrawmemlimit=$(echo $keymemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-monasca-memcached replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-monasca-memcached | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
mcdcpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
if [[ "$mcdcpulimit" == *"m" ]]; then mcdcpulimit=$(echo $mcdcpulimit | cut -d "m" -f 1); mcdcpulimit=$(echo "scale=2 ; $mcdcpulimit / 1000" | bc);fi
mcdmemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
mcdrawmemlimit=$(echo $mcdmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-monasca-thresh-metrics replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-monasca-thresh-metrics | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
mtmcpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
if [[ "$mtmcpulimit" == *"m" ]]; then mtmcpulimit=$(echo $mtmcpulimit | cut -d "m" -f 1); mtmcpulimit=$(echo "scale=2 ; $mtmcpulimit / 1000" | bc);fi
mtmmemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
mtmrawmemlimit=$(echo $mtmmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-monasca-thresh-node replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-monasca-thresh-node | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
mtncpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
if [[ "$mtncpulimit" == *"m" ]]; then mtncpulimit=$(echo $mtncpulimit | cut -d "m" -f 1); mtncpulimit=$(echo "scale=2 ; $mtncpulimit / 1000" | bc);fi
mtnmemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
mtnrawmemlimit=$(echo $mtnmemlimit | numfmt --from=auto)

# get cpu and memory utilization for each sma-monasca-agent pod
for i in $(kubectl -n sma get pods | grep sma-monasca-agent | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $agtcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $agtcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $agtrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $agtmemlimit memory limit."
     echo
  done

  # get storage, cpu, and memory utilization for each sma-monasca-mysql pod
for i in $(kubectl -n sma get pods | grep sma-monasca-mysql | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $sqlcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $sqlcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $sqlrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $sqlmemlimit memory limit."

     volsize=$(kubectl -n sma exec -it  $i -- df -h | grep mysql | awk '{print $2}');
     volused=$(kubectl -n sma exec -it  $i -- df -h | grep mysql | awk '{print $3}');
     volpct=$(kubectl -n sma exec -it  $i -- df -h | grep mysql | awk '{print $5}');
     echo "pod $i is using $volused storage, $volpct of the $volsize total."
     echo
  done

  # get cpu and memory utilization for each sma-monasca-notification pod
for i in $(kubectl -n sma get pods | grep sma-monasca-notification | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $notcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $notcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $notrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $notmemlimit memory limit."
     echo
  done

  # get cpu and memory utilization for each sma-monasca-zoo-entrance pod
for i in $(kubectl -n sma get pods | grep sma-monasca-zoo-entrance | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     echo "pod $i is using $podcpu cores."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     echo "pod $i is using $podmem memory."
     echo
  done

  # get cpu and memory utilization for each sat-monasca-translator pod
for i in $(kubectl -n sma get pods | grep sat-monasca-translator | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     echo "pod $i is using $podcpu cores."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     echo "pod $i is using $podmem memory."
     echo
  done

  # get cpu and memory utilization for each sma-monasca-api pod
for i in $(kubectl -n sma get pods | grep sma-monasca-api | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $apicpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $apicpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $apirawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $apimemlimit memory limit."
     echo
  done

  # get cpu and memory utilization for each sma-monasca-keystone pod
for i in $(kubectl -n sma get pods | grep sma-monasca-keystone | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $keycpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $keycpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $keyrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $keymemlimit memory limit."
     echo
  done

  # get cpu and memory utilization for each sma-monasca-memcached pod
for i in $(kubectl -n sma get pods | grep sma-monasca-memcached | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $mcdcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $mcdcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $mcdrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $mcdmemlimit memory limit."
     echo
  done

  # get cpu and memory utilization for each sma-monasca-thresh-dmtf pod
for i in $(kubectl -n sma get pods | grep sma-monasca-thresh-dmtf | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     echo "pod $i is using $podcpu cores."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     echo "pod $i is using $podmem memory."
     echo
  done

  # get cpu and memory utilization for each sma-monasca-thresh-metrics pod
for i in $(kubectl -n sma get pods | grep sma-monasca-thresh-metrics | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $mtmcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $mtmcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $mtmrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $mtmmemlimit memory limit."
     echo
  done

  # get cpu and memory utilization for each sma-monasca-thresh-node pod
for i in $(kubectl -n sma get pods | grep sma-monasca-thresh-node | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $mtncpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $mtncpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $mtnrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $mtnmemlimit memory limit."
     echo
  done

 exit 0
