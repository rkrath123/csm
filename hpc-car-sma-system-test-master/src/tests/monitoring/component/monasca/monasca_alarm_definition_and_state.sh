#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the monasca alarm and notification service in HPE's Cray"
    echo "System Monitoring Application checks the ability to create and delete notifications and alarm definitions,"
    echo "as well as the ability to transition between alarm states."
    echo "$0 > sma_component_monasca_definition_and_state-\`date +%Y%m%d.%H%M\`"
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
# Test case: Create Notification
#   Confirm that notifications can be created
kubectl -n sma exec -it $monascapod -c collector -- sh -c 'monasca notification-create test EMAIL testuser@cray.com'
createnotification=$(kubectl -n sma exec -it $monascapod -c collector -- sh -c 'monasca notification-list' | grep test |awk '{print $2}')
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
notificationid=$(kubectl -n sma exec -it $monascapod -c collector -- monasca notification-list | grep test | cut -d "|" -f 3 | cut -d " " -f 2 | tr "\r" " ")
createdefinition=$(kubectl -n sma exec -it $monascapod -c collector -- monasca alarm-definition-create --description "SMA test" --severity "MEDIUM" --match-by "hostname" --alarm-actions "$notificationid" --undetermined-actions "$notificationid" --ok-actions "$notificationid" "SMA Alarm Test" "avg(cray_test.other_test) > 20")
testdef=$(kubectl -n sma exec -it $monascapod -c collector -- monasca alarm-definition-list | grep SMA | cut -d "|" -f 2 | xargs)
if [[ " $testdef " =~ "SMA Alarm Test" ]]; then
  echo "test alarm definition created";
  defid=$(kubectl -n sma exec -it sma-monasca-agent-0 -c forwarder -- monasca alarm-definition-list | grep SMA | awk '{print $6}')
else
  echo "create alarm definition failed"
  errs=$((errs+1))
  failures+=("Monasca Create alarm definition - create definition failed")
fi

##################
# Test case: Trigger alarm
# The first metric received should trigger an alarm in the undetermined state. After getting a few more, it will put it into Alarm.
# It uses the timestamp in order to do this, so using an old static value is not sufficient to trigger an alarm.
# The tenantId value in the metrics must be the id value found using the following method:
minimon=$(kubectl -n sma exec -it sma-monasca-mysql-0 -- bash -c "mysql --user=keystone --password=keystone -D keystone -e 'SELECT id,name FROM project'" | grep mini-mon | awk '{print $2}')
# create a template for a json metric intended to trigger the alarm
echo '{"metric":{"timestamp":current_time,"name":"cray_test.other_test","dimensions":{"hostname":"ncn-w001"},"value":testval,"value_meta":null},"meta":{"region":"useast","tenantId":"'$minimon'"},"creation_time":created_time}' > alarm.json
# copy it to the kafka pod
kubectl -n sma cp alarm.json cluster-kafka-0://tmp/alarm.json -c kafka
# In the kafka pod's shell, loop through populating the timestamps and sending the metric
kubectl -n sma exec -it cluster-kafka-0 -c kafka -- bash -c 'touch /tmp/test.out; chmod 666 /tmp/test.out; for i in {1..6}; do created_time=$(date +%s%N); current_time=$(($(date +%s%N)/1000000)); sed "s/current_time/$current_time/g" /tmp/alarm.json | sed -e "s/created_time/$created_time/g" -e "s/testval/70/g" > /tmp/test.out; cat /tmp/test.out | /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic metrics; cat /tmp/test.out; sleep 30; done'
# Check to see that the alarm is in the ALARM state
state=$(kubectl -n sma exec -it sma-monasca-agent-0 -c forwarder -- monasca alarm-list --alarm-definition-id=$defid | awk '{print $17}')
echo "alarm in "$state" state."
if [[ " $state " =~ "ALARM" ]]; then
  echo "alarm triggered successfully";
else
  echo "alarm triggering failed"
  errs=$((errs+1))
  failures+=("Monasca alarm triggering - alarm triggering failed")
fi

##################
# Test case: Alarm OK
# The first metric received should trigger an alarm in the undetermined state. After getting a few more, it will put it into Ok.
# In the kafka pod's shell, loop through populating the timestamps and sending the metric
kubectl -n sma exec -it cluster-kafka-0 -c kafka -- bash -c 'touch /tmp/test.out; chmod 666 /tmp/test.out; for i in {1..6}; do created_time=$(date +%s%N); current_time=$(($(date +%s%N)/1000000)); sed "s/current_time/$current_time/g" /tmp/alarm.json | sed -e "s/created_time/$created_time/g" -e "s/testval/10/g" > /tmp/test.out; cat /tmp/test.out | /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic metrics; cat /tmp/test.out; sleep 30; done'
# Check to see that the alarm is in the ALARM state
state=$(kubectl -n sma exec -it sma-monasca-agent-0 -c forwarder -- monasca alarm-list --alarm-definition-id=$defid | awk '{print $17}')
echo "alarm in "$state" state."
if [[ " $state " =~ "OK" ]]; then
  echo "alarm dismissed successfully";
else
  echo "alarm dismissal failed"
  errs=$((errs+1))
  failures+=("Monasca alarm triggering - alarm dismissal failed")
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
echo "Monasca is able to create and delete notifications, create alarm definitions, and trigger state changes"

exit 0