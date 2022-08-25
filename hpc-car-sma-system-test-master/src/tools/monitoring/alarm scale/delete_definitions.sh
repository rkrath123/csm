#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This cleans up after the scale test for the monasca alarm and notification service in Cray's"
    echo "System Monitoring Application. It removes Custom Alarm Definitions and the test Notification."
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
# Test case: Cleanup Custom Alarm Definitions
for def in $(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-list -j | grep name | cut -d '"' -f 4);
do definitionid=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-list --name $def -j | grep id | cut -d '"' -f 4)
  if [[ "$def" == "SMATest"* ]]; then
    echo $def
    kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-delete "$definitionid"
  fi
  done
  definitions=$(kubectl -n sma exec $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-list| grep SMA | cut -d "|" -f 2 | xargs)
  if [[ ! "$definitions" =~ "SMATest" ]]; then
    echo "test alarm definitions deleted";
  else
    echo "delete alarm definitions failed"
    errs=$((errs+1))
    failures+=("Monasca Delete alarm definition - delete definition failed")
  fi

###################
# Test case: Cleanup Notification
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



######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Monasca alarm definitions deleted"

exit 0