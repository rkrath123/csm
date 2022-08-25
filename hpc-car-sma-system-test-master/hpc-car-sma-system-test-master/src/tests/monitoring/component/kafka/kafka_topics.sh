#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kafka messaging bus in Cray's Shasta System Monitoring Application"
    echo "tests that that the pods are in the expected state."
    echo "$0 > sma_component_kafka_topics-\`date +%Y%m%d.%H%M\`"
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
kafkapod="cluster-kafka-0"
#############################################
# Test case: Confirm Expected Topics Exist
declare -a topics
declare -a expected=( "60-seconds-notifications" "__consumer_offsets" "alarm-notifications" "alarm-state-transitions" "cray-dmtf-monasca" "cray-dmtf-resource-event" "cray-fabric-crit-telemetry" "cray-fabric-perf-telemetry" "cray-fabric-telemetry" "cray-logs-containers" "cray-logs-syslog" "cray-node" "cray-telemetry-energy" "cray-telemetry-fan" "cray-telemetry-power" "cray-telemetry-pressure" "cray-telemetry-temperature" "cray-telemetry-voltage" "events" "kafka-health-check" "metrics" "retry-notifications" )

for i in $(kubectl -n sma exec -it ${kafkapod} -c kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list | tr '\r' '\n');
    do topics+=($i);
    echo "Kafka topic $i exists";
done

for i in ${expected[@]}; do
  if [[ ! " ${topics[@]} " =~ " $i " ]]; then
    echo "$i topic is missing"
    errs=$((errs+1))
    failures+=("Kafka Topics - $i topic is missing")
  fi
done

unset topics
unset expected


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
echo "Kafka topics are in the expected state"

exit 0