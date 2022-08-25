#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is used in the scale test for the monasca alarm and notification service in Cray's"
    echo "System Monitoring Application. It creates multiple copies of an alarm definition so that"
    echo "alarms of varying scales can be triggered."
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
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

declare -a failures
errs=0

###################

monascapod=$(kubectl -n sma get pods | grep monasca-agent | head -n 1 | cut -d " " -f 1)

###################
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
# Test case: Create Custom Alarm Definitions
#   Confirm that Custom Alarm Definitions can be created
if ! test -f ./alarm_test; then
  mkdir ./alarm_test
fi
notificationid=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 notification-list | grep test | cut -d "|" -f 3 | cut -d " " -f 2 | tr "\r" " ")
for i in {1..500};
  do createdefinition=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-create --description "SMA test" --severity "MEDIUM" --match-by "hostname" --alarm-actions "$notificationid" --undetermined-actions "$notificationid" --ok-actions "$notificationid" "SMATest$i" "avg(cray_test.other_test) > 20")
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
      echo "Definitions:$i pod:$pod MEM:$mem CPU:$cpu" 2>&1 | tee -a ./alarm_test/$pod.out
    done
    prelist=$(date +%s);
    testalarm=$(kubectl -n sma exec -it $monascapod -c collector -- monasca --os-auth-url http://sma-monasca-keystone:35357 alarm-definition-list | grep "SMATest$i" | cut -d "|" -f 2 | xargs)
    postlist=$(date +%s)
    listtime=$(echo $(($postlist-$prelist)) )
    echo "Definitions:$i List_time:$listtime sec"
    if [[ "$testalarm" =~ "SMATest$i" ]]; then
      echo "test alarm definition created";
    else
      echo "create alarm definition failed"
      errs=$((errs+1))
      failures+=("Monasca Create alarm definition - create definition failed")
      break
    fi
  done

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Alarm Definition creation completed"

exit 0