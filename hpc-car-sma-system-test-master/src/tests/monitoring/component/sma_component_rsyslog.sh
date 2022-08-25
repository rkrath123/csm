#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for rsyslog in Cray's Shasta System Monitoring Application."
    echo "The test focuses on verification of a valid environment and initial configuration, and"
    echo "tests the ability to send OS and container log messages to kafka/elasticsearch."
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

declare -a failures
errs=0


###################
# Test case: SMA rsyslog Aggregator Pods are Running
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep rsyslog-aggregator | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "rsyslog-aggregator-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "rsyslog-aggregator-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Rsyslog Aggregator Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "rsyslog-aggregator pods are missing"
  errs=$((errs+1))
  failures+=("Rsyslog Aggregator Pods - rsyslog-aggregator pods are missing")
fi

unset pods
unset podstatus
unset podnode

###################
# Test case: SMA rsyslog Auditlogs Pods are Running
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep rsyslog-auditlogs | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "rsyslog-auditlogs-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "rsyslog-auditlogs-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Rsyslog Auditlogs Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "rsyslog-auditlogs pods are missing"
  errs=$((errs+1))
  failures+=("Rsyslog Auditlogs Pods - rsyslog-auditlogs pods are missing")
fi

unset pods
unset podstatus
unset podnode

###################
# Test case: SMA rsyslog Collector Pods are Running
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep rsyslog-collector- | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "rsyslog-collector-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "rsyslog-collector-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Rsyslog Collector Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "rsyslog-collector pods are missing"
  errs=$((errs+1))
  failures+=("Rsyslog Collector Pods - rsyslog-collector pods are missing")
fi

unset pods
unset podstatus
unset podnode

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

#########################
#Test Case: Rsyslog Collects Compute Logs
time=$(date +%s)
compute=$(sat status --filter Role=compute --filter State=Ready --fields Aliases --no-borders --no-headings | head -n 1 | xargs)
ssh -o "StrictHostKeyChecking no" "$compute-nmn" logger "computetest_$time"
search=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -X GET "elasticsearch:9200/_search?q=computetest_${time}" | jq | grep computetest | grep -v "q=" | cut -d '"' -f 4 | xargs)
if [[ " $search " =~ "computetest_" ]]; then
  echo "Log collected from compute node";
else
  echo "Log collection from compute node failed"
  errs=$((errs+1))
  failures+=("Rsyslog Collects Compute Logs - Log collection from compute failed")
fi

######################################
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

#####################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Rsyslog is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Rsyslog looks healthy"

exit 0