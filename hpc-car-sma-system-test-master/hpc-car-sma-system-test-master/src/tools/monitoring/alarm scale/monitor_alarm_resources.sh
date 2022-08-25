#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is used in the scale test for the monasca alarm and notification service in Cray's"
    echo "System Monitoring Application. It collects mem and cpu utilization for each SMA pod from"
    echo "the kubernetes 'top' command, as well as a count of the number of alarms, and writes the"
    echo "values to an individual file for each pod."
    echo "$0 > sma_component_monasca_notification_and_definition-\`date +%Y%m%d.%H%M\`"
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

###################
monascapod=$(kubectl -n sma get pods | grep monasca-agent | head -n 1 | cut -d " " -f 1)
if ! test -f ./alarm_test; then
  mkdir ./alarm_test
fi

for pod in $(kubectl -n sma get pods | grep -v Completed | awk {'print $1'});
  do echo "alarms mem cpu" 2>&1 | tee -a ./alarm_test/$pod.out
done

while :
  do alarms=$(kubectl -n sma exec -it $monascapod -c collector -- sh -c 'monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-list' | grep Z | wc -l)
  echo $alarms
  for pod in $(kubectl -n sma get pods | grep -v Completed | awk {'print $1'});
  do if [[ $pod =~ "sma-monasca-mysql" ]]; then
      cpu=$(kubectl -n sma top pods | grep -v NAME | grep $pod | awk {'print $2'} | tail -n 1)
      mem=$(kubectl -n sma top pods | grep -v NAME | grep $pod | awk {'print $3'} | tail -n 1)
    elif [[ $pod =~ "mysql" ]]; then
      cpu=$(kubectl -n sma top pods | grep -v NAME | grep $pod | awk {'print $2'} | head -n 1)
      mem=$(kubectl -n sma top pods | grep -v NAME | grep $pod | awk {'print $3'} | head -n 1)
    else
      cpu=$(kubectl -n sma top pods | grep -v NAME | grep $pod | awk {'print $2'})
      mem=$(kubectl -n sma top pods | grep -v NAME | grep $pod | awk {'print $3'})
  fi
  echo "$alarms $mem $cpu" 2>&1 | tee -a ./alarm_test/$pod.out
  done
done