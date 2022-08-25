#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for the monasca alarm and notification service in Cray's"
    echo "System Monitoring Application."
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

declare -a failures
errs=0

###################

monascapod=$(kubectl -n sma get pods | grep monasca-agent | head -n 1 | cut -d " " -f 1)

###################
# Test case: SMA Monasca Agent Pods are Running
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep monasca-agent | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "monasca-agent-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "monasca-agent-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Monasca Agent Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "monasca-agent pods are missing"
  errs=$((errs+1))
  failures+=("Monasca Agent Pods - sma-monasca-agent is missing")
fi

unset pods
unset podstatus
unset podnode

###################
# Test case: Monasca Api Pod Exists in SMA Namespace
podname=$(kubectl -n sma get pods | grep sma-monasca-api | awk '{print $1}')
podstatus=$(kubectl -n sma get pods | grep sma-monasca-api | awk '{print $3}')
if [[ " $podname " =~ "sma-monasca-api-" ]]; then
  if [[ " $podstatus " =~ "Running" ]]; then
    echo "sma-monasca-api pod is Running";
  else
    echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
    errs=$((errs+1))
    failures+=("Monasca API Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
  fi
else
  echo "sma-monasca-api pod is missing"
  errs=$((errs+1))
  failures+=("Monasca API Pods - sma-monasca-api is missing")
fi

###################
# Test case: Monasca Keystone Pod Exists in SMA Namespace
podname=$(kubectl -n sma get pods | grep sma-monasca-keystone | awk '{print $1}')
podstatus=$(kubectl -n sma get pods | grep sma-monasca-keystone | awk '{print $3}')
if [[ " $podname " =~ "sma-monasca-keystone-" ]]; then
  if [[ " $podstatus " =~ "Running" ]]; then
    echo "sma-monasca-keystone pod is Running";
  else
    echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
    errs=$((errs+1))
    failures+=("Monasca keystone Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
  fi
else
  echo "sma-monasca-keystone pod is missing"
  errs=$((errs+1))
  failures+=("Monasca keystone Pods - sma-monasca-keystone is missing")
fi

###################
# Test case: Monasca Memcached Pod Exists in SMA Namespace
podname=$(kubectl -n sma get pods | grep sma-monasca-memcached | awk '{print $1}')
podstatus=$(kubectl -n sma get pods | grep sma-monasca-memcached | awk '{print $3}')
if [[ " $podname " =~ "sma-monasca-memcached-" ]]; then
  if [[ " $podstatus " =~ "Running" ]]; then
    echo "sma-monasca-memcached pod is Running";
  else
    echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
    errs=$((errs+1))
    failures+=("Monasca memcached Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
  fi
else
  echo "sma-monasca-memcached pod is missing"
  errs=$((errs+1))
  failures+=("Monasca memcached Pod - sma-monasca-memcached is missing")
fi

###################
# Test case: Monasca Mysql Pod Exists in SMA Namespace
podname=$(kubectl -n sma get pods | grep sma-monasca-mysql | awk '{print $1}')
podstatus=$(kubectl -n sma get pods | grep sma-monasca-mysql | awk '{print $3}')
if [[ " $podname " =~ "sma-monasca-mysql-" ]]; then
  if [[ " $podstatus " =~ "Running" ]]; then
    echo "sma-monasca-mysql pod is Running";
  else
    echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
    errs=$((errs+1))
    failures+=("Monasca mysql Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
  fi
else
  echo "sma-monasca-mysql pod is missing"
  errs=$((errs+1))
  failures+=("Monasca mysql Pod - sma-monasca-mysql is missing")
fi

###################
# Test case: Monasca notification Pod Exists in SMA Namespace
podname=$(kubectl -n sma get pods | grep sma-monasca-notification | awk '{print $1}')
podstatus=$(kubectl -n sma get pods | grep sma-monasca-notification | awk '{print $3}')
if [[ " $podname " =~ "sma-monasca-notification-" ]]; then
  if [[ " $podstatus " =~ "Running" ]]; then
    echo "sma-monasca-notification pod is Running";
  else
    echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
    errs=$((errs+1))
    failures+=("Monasca notification Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
  fi
else
  echo "sma-monasca-notification pod is missing"
  errs=$((errs+1))
  failures+=("Monasca notification Pod - sma-monasca-notification is missing")
fi

###################
# Test case: Monasca thresh-metrics-init job Completed in SMA Namespace
jobname=$(kubectl -n sma get jobs | grep sma-monasca-thresh-metrics-init | awk '{print $1}')
jobstatus=$(kubectl -n sma get jobs | grep sma-monasca-thresh-metrics | awk '{print $2}')
if [[ " $jobname " =~ "sma-monasca-thresh-metrics-init-job" ]]; then
  if [[ " $jobstatus " =~ "1/1" ]]; then
    echo "sma-monasca-thresh-metrics-init job Completed";
  else
    echo "sma-monasca-thresh-metrics-init job did not complete as expected"
    errs=$((errs+1))
    failures+=("Monasca thresh-metrics-init Job - completions $jobstatus")
  fi
else
  echo "sma-monasca-thresh-metrics-init job not found"
  errs=$((errs+1))
  failures+=("Monasca thresh-metrics-init Job not found")
fi

###################
# Test case: Monasca Zoo-Entrance Pod Exists in SMA Namespace
podname=$(kubectl -n sma get pods | grep sma-monasca-zoo-entrance | awk '{print $1}')
podstatus=$(kubectl -n sma get pods | grep sma-monasca-zoo-entrance | awk '{print $3}')
if [[ " $podname " =~ "sma-monasca-zoo-entrance-" ]]; then
  if [[ " $podstatus " =~ "Running" ]]; then
    echo "sma-monasca-zoo-entrance pod is Running";
  else
    echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
    errs=$((errs+1))
    failures+=("Monasca zoo-entrance Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
  fi
else
  echo "sma-monasca-zoo-entrance pod is missing"
  errs=$((errs+1))
  failures+=("Monasca zoo-entrance Pod - sma-monasca-zoo-entrance is missing")
fi

###################
# Test case: Check Monasca thresh-metrics-cluster
podname=$(kubectl -n sma get pods | grep sma-monasca-storm-supervisor | head -n 1 | awk '{print $1}')
if [[ " $podname " =~ "sma-monasca-storm-supervisor-" ]]; then
  stormstatus=$(kubectl -n sma exec -it $podname -- storm list | grep thresh-metrics-cluster | awk '{print $2}')
  if [[ " $stormstatus " =~ "ACTIVE" ]]; then
    echo "Storm thresh-metrics-cluster is active";
  else
    echo "Storm thresh-metrics-cluster is $stormstatus"
    errs=$((errs+1))
    failures+=("Storm thresh-metrics-cluster is $stormstatus")
  fi
else
  echo "sma-monasca-storm-supervisor pod is missing"
  errs=$((errs+1))
  failures+=("Monasca storm-supervisor pod - sma-monasca-storm-supervisor pod is missing")
fi

###################
# Test case: Create Notification
#   Confirm that notifications can be created
kubectl -n sma exec -it $monascapod -c collector -- sh -c 'monasca --os-auth-url http://sma-monasca-keystone:35357 notification-create test EMAIL testuser@cray.com'
createnotification=$(kubectl -n sma exec -it $monascapod -c collector -- sh -c 'monasca --os-auth-url http://sma-monasca-keystone:35357 notification-list' | grep test |awk '{print $2}')
if [[ " $createnotification " =~ "test" ]]; then
  echo "notification created";
else
  echo "create notification failed"
  errs=$((errs+1))
  failures+=("Monasca Create Notification - create notification failed")
fi

###################
# Test case: Create Custom Alarm Definition
#   Confirm that Custom Alarm Definitions can be created
notificationid=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 notification-list | grep test | cut -d "|" -f 3 | cut -d " " -f 2 | tr "\r" " ")
createdefinition=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-create --description "SMA test" --severity "MEDIUM" --match-by "hostname" --alarm-actions "$notificationid" --undetermined-actions "$notificationid" --ok-actions "$notificationid" "SMA Alarm Test" "avg(cray_test.other_test) > 20")
testalarm=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-list | grep SMA | cut -d "|" -f 2 | xargs)
if [[ " $testalarm " =~ "SMA Alarm Test" ]]; then
  echo "test alarm definition created";
else
  echo "create alarm definition failed"
  errs=$((errs+1))
  failures+=("Monasca Create alarm definition - create definition failed")
fi

###################
# Test case: Delete Custom Alarm Definition
#   Confirm that Custom Alarm Definitions can be deleted
definitionid=$(kubectl -n sma exec -i $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-list | grep "SMA Alarm Test" | cut -d "|" -f 3 | cut -d " " -f 2)
deletedefinition=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-delete "$definitionid")
definitions=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-list| grep SMA | cut -d "|" -f 2 | xargs)
if [[ ! "$definitions" =~ "SMA Alarm Test" ]]; then
  echo "test alarm definition deleted";
else
  echo "delete alarm definition failed"
  errs=$((errs+1))
  failures+=("Monasca Delete alarm definition - delete definition failed")
fi

###################
# Test case: Delete Notification
#   Confirm that notifications can be deleted
notificationid=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 notification-list | grep test | cut -d "|" -f 3 | cut -d " " -f 2 | tr "\r" " ");
deletenotification=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 notification-delete "$notificationid")
notifications=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 notification-list | grep test | awk '{print $2}')
if [[ ! "$notifications" =~ "test" ]]; then
  echo "test notification deleted";
else
  echo "delete notification failed"
  errs=$((errs+1))
  failures+=("Monasca Delete notification - delete notification failed")
fi

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
for i in $(kubectl -n sma get pods | grep sma-monasca-mysql | grep -v Completed | awk '{print $1}');
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
for i in $(kubectl -n sma get pods | grep sma-monasca-thresh-metrics | grep -v Completed | awk '{print $1}');
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

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Monasca is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Monasca looks healthy"

exit 0
