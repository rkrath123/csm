#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kafka messaging bus in Cray's Shasta System Monitoring Application"
    echo "tests the ability to create a topic and send/receive messsages."
    echo "$0 > sma_component_kafka_service-\`date +%Y%m%d.%H%M\`"
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


###################################
# Test case: Kafka is Running as a K8S Service
declare -a services

for i in $(kubectl -n sma get svc | grep kafka | awk '{print $1}');
    do services+=($i);
done

if [[ " ${services[@]} " =~ "cluster-kafka-bootstrap" ]]; then
  echo "service cluster-kafka-bootstrap is available";
else
  echo "service cluster-kafka-bootstrap is missing"
  errs=$((errs+1))
  failures+=("Kafka Service - cluster-kafka-bootstrap is missing")
fi

if [[ " ${services[@]} " =~ "cluster-kafka-brokers" ]]; then
  echo "service cluster-kafka-brokers is available";
else
  echo "service cluster-kafka-brokers is missing"
  errs=$((errs+1))
  failures+=("Kafka Service - cluster-kafka-brokers is missing")
fi

unset services

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Kafka is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Kafka services are available"

exit 0