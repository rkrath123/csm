#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for the Kafka messaging bus in Cray's Shasta System Monitoring Application."
    echo "The test verifies a valid initial state, as well as the ability to create a topic and send/receive messsages."
    echo "$0 > sma_component_kafka-\`date +%Y%m%d.%H%M\`"
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
# Test case: Kafka Pods Exist in SMA Namespace

declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep kafka | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

# Confirm Pod is Running
if [[ " ${pods[@]} " =~ "cluster-kafka-0" ]]; then
    if [[ ! " ${podstatus[cluster-kafka-0]} " =~ "Running" ]]; then
    echo "cluster-kafka-0 is ${podstatus[cluster-kafka-0]} on ${podnode[cluster-kafka-0]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-kafka-0 ${podstatus[cluster-kafka-0]}")
    else
        echo "cluster-kafka-0 is Running"
    fi
else
    echo "cluster-kafka-0 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-kafka-0 is missing")
fi

if [[ " ${pods[@]} " =~ "cluster-kafka-1" ]]; then
    if [[ ! " ${podstatus[cluster-kafka-1]} " =~ "Running" ]]; then
    echo "cluster-kafka-1 is ${podstatus[cluster-kafka-1]} on ${podnode[cluster-kafka-1]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-kafka-1 ${podstatus[cluster-kafka-1]}")
    else
        echo "cluster-kafka-1 is Running"
    fi
else
    echo "cluster-kafka-1 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-kafka-1 is missing")
fi

if [[ " ${pods[@]} " =~ "cluster-kafka-2" ]]; then
    if [[ ! " ${podstatus[cluster-kafka-2]} " =~ "Running" ]]; then
    echo "cluster-kafka-2 is ${podstatus[cluster-kafka-2]} on ${podnode[cluster-kafka-2]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-kafka-2 ${podstatus[cluster-kafka-2]}")
    else
        echo "cluster-kafka-2 is Running"
    fi
else
    echo "cluster-kafka-2 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-kafka-2 is missing")
fi

unset pods
unset podstatus
unset podnode

#################################
# Test case: ZK Pods Exist in SMA Namespace
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n sma get pods | grep zookeeper | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

# Confirm Pod is Running
if [[ " ${pods[@]} " =~ "cluster-zookeeper-0" ]]; then
    if [[ ! " ${podstatus[cluster-zookeeper-0]} " =~ "Running" ]]; then
    echo "cluster-zookeeper-0 is ${podstatus[cluster-zookeeper-0]} on ${podnode[cluster-zookeeper-0]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-0 ${podstatus[cluster-zookeeper-0]}")
    else
        echo "cluster-zookeeper-0 is Running"
    fi
else
    echo "cluster-zookeeper-0 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-0 is missing")
fi

if [[ " ${pods[@]} " =~ "cluster-zookeeper-1" ]]; then
    if [[ ! " ${podstatus[cluster-zookeeper-1]} " =~ "Running" ]]; then
    echo "cluster-zookeeper-1 is ${podstatus[cluster-zookeeper-1]} on ${podnode[cluster-zookeeper-1]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-1 ${podstatus[cluster-zookeeper-1]}")
    else
        echo "cluster-zookeeper-1 is Running"
    fi
else
    echo "cluster-zookeeper-1 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-1 is missing")
fi

if [[ " ${pods[@]} " =~ "cluster-zookeeper-2" ]]; then
    if [[ ! " ${podstatus[cluster-zookeeper-2]} " =~ "Running" ]]; then
    echo "cluster-zookeeper-2 is ${podstatus[cluster-zookeeper-2]} on ${podnode[cluster-zookeeper-2]}"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-2 ${podstatus[cluster-zookeeper-2]}")
    else
        echo "cluster-zookeeper-2 is Running"
    fi
else
    echo "cluster-zookeeper-2 is missing"
    errs=$((errs+1))
    failures+=("Kafka Pods - cluster-zookeeper-2 is missing")
fi

unset pods
unset podstatus
unset podnode

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

####################################
# Test case: Kafka Persistent Volume Claim
#   Kubernetes persistent volume claim for kafka is bound
declare -a pvcs
declare -A pvcstatus
declare -A accessmode
declare -A storageclass
declare -A pvccap

# get pvc name, status, access mode and storage class
for i in $(kubectl -n sma get pvc | grep kafka | awk '{print $1}');
    do pvcs+=($i);
    status=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $2}')
    pvcstatus[$i]=$status;
    capacity=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $4}')
    pvccap[$i]=$capacity;
    mode=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $5}')
    accessmode[$i]=$mode;
    class=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $6}')
    storageclass[$i]=$class;
done

# Confirm data-cluster-kafka-0 exists
if [[ " ${pvcs[@]} " =~ "data-cluster-kafka-0" ]]; then
    # confirm pvc is bound
    if [[ ! " ${pvcstatus[data-cluster-kafka-0]} " =~ "Bound" ]]; then
        echo "data-cluster-kafka-0 is ${pvcstatus[data-cluster-kafka-0]}"
        errs=$((errs+1))
        failures+=("kafka PVCs - data-cluster-kafka-0 ${pvcstatus[data-cluster-kafka-0]}")
    else
        echo "data-cluster-kafka-0 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[data-cluster-kafka-0]} " =~ "sma-block-replicated" ]]; then
        echo "data-cluster-kafka-0 is ${storageclass[pgdata-sma-postgres-cluster-0]}"
        errs=$((errs+1))
        failures+=("Kafka PVCs - data-cluster-kafka-0 ${storageclass[data-cluster-kafka-0]}")
    else
        echo "data-cluster-kafka-0 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[data-cluster-kafka-0]} " =~ "RWO" ]]; then
        echo "data-cluster-kafka-0 has acccess mode ${accessmode[data-cluster-kafka-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - data-cluster-kafka-0 ${pvcstatus[data-cluster-kafka-0]}")
    else
        echo "data-cluster-kafka-0 has acccess mode RWO, as expected"
    fi
    #Report capacity
    echo "data-cluster-kafka-0 has a capacity of ${pvccap[data-cluster-kafka-0]}"
else
    echo "data-cluster-kafka-0 pvc is missing"
    errs=$((errs+1))
    failures+=("Kafka PVCs - data-cluster-kafka-0 missing")
fi

# Confirm data-cluster-kafka-1 exists
if [[ " ${pvcs[@]} " =~ "data-cluster-kafka-1" ]]; then
    # confirm pvc is bound
    if [[ ! " ${pvcstatus[data-cluster-kafka-1]} " =~ "Bound" ]]; then
        echo "data-cluster-kafka-1 is ${pvcstatus[data-cluster-kafka-1]}"
        errs=$((errs+1))
        failures+=("kafka PVCs - data-cluster-kafka-1 ${pvcstatus[data-cluster-kafka-1]}")
    else
        echo "data-cluster-kafka-1 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[data-cluster-kafka-1]} " =~ "sma-block-replicated" ]]; then
        echo "data-cluster-kafka-1 is ${storageclass[pgdata-sma-postgres-cluster-1]}"
        errs=$((errs+1))
        failures+=("Kafka PVCs - data-cluster-kafka-1 ${storageclass[data-cluster-kafka-1]}")
    else
        echo "data-cluster-kafka-1 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[data-cluster-kafka-1]} " =~ "RWO" ]]; then
        echo "data-cluster-kafka-1 has acccess mode ${accessmode[data-cluster-kafka-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - data-cluster-kafka-1 ${pvcstatus[data-cluster-kafka-1]}")
    else
        echo "data-cluster-kafka-1 has acccess mode RWO, as expected"
    fi
    #Report capacity
    echo "data-cluster-kafka-1 has a capacity of ${pvccap[data-cluster-kafka-1]}"
else
    echo "data-cluster-kafka-1 pvc is missing"
    errs=$((errs+1))
    failures+=("Kafka PVCs - data-cluster-kafka-1 missing")
fi

# Confirm data-cluster-kafka-2 exists
if [[ " ${pvcs[@]} " =~ "data-cluster-kafka-2" ]]; then
    # confirm pvc is bound
    if [[ ! " ${pvcstatus[data-cluster-kafka-2]} " =~ "Bound" ]]; then
        echo "data-cluster-kafka-2 is ${pvcstatus[data-cluster-kafka-2]}"
        errs=$((errs+1))
        failures+=("kafka PVCs - data-cluster-kafka-2 ${pvcstatus[data-cluster-kafka-2]}")
    else
        echo "data-cluster-kafka-2 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[data-cluster-kafka-2]} " =~ "sma-block-replicated" ]]; then
        echo "data-cluster-kafka-2 is ${storageclass[pgdata-sma-postgres-cluster-2]}"
        errs=$((errs+1))
        failures+=("Kafka PVCs - data-cluster-kafka-2 ${storageclass[data-cluster-kafka-2]}")
    else
        echo "data-cluster-kafka-2 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[data-cluster-kafka-2]} " =~ "RWO" ]]; then
        echo "data-cluster-kafka-2 has acccess mode ${accessmode[data-cluster-kafka-2]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - data-cluster-kafka-2 ${pvcstatus[data-cluster-kafka-2]}")
    else
        echo "data-cluster-kafka-2 has acccess mode RWO, as expected"
    fi
    #Report capacity
    echo "data-cluster-kafka-2 has a capacity of ${pvccap[data-cluster-kafka-2]}"
else
    echo "data-cluster-kafka-2 pvc is missing"
    errs=$((errs+1))
    failures+=("Kafka PVCs - data-cluster-kafka-2 missing")
fi

unset pvcs
unset pvcstatus
unset accessmode
unset storageclass

#######################################
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

#######################################
# Test case: Create Test Topic
createtopic=$(kubectl -n sma exec -it ${kafkapod} -c kafka -- /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --partitions 1 --topic test-topic --replication-factor 1|tr "\r" "\n")

if [[ "$createtopic" =~ "Created topic test-topic." ]]; then
  echo "test topic created";
else
  echo "test topic not created"
  errs=$((errs+1))
  failures+=("Kafka Service - test topic not created")
fi

#######################################
# Test case: Create Producer and Send Message
#   Create a producer and send a message to the previously created test topic
procreate=$(kubectl -n sma exec -it ${kafkapod} -c kafka -- bash -c "echo test-message | /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test-topic" | grep Error)

if [[ ! $procreate ]]; then
  echo "test message sent";
else
  echo "test message send failed"
  errs=$((errs+1))
  failures+=("Kafka Producer - test message send failed")
fi

#######################################
# Test case: Create Consumer and Receive Message
#   In order to facilitate having the producer and consumer run serially, the consumer is set to get all messages ever
#   posted to the topic and then time out.

consumerout=$(kubectl -n sma exec -it ${kafkapod} -c kafka -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-topic --from-beginning --timeout-ms 5000 | grep test-message | tr '\r' '\n')
if [[ "$consumerout" =~ "test-message" ]]; then
  echo "test message received";
else
  echo "test message read failed"
  errs=$((errs+1))
  failures+=("Kafka Consumer - test message read failed")
fi

#   Return the environment to the initial state. Logs are cleaned up automatically when the related topic is deleted.
#   Because the ability to delete topics is disabled by default, the server.properties file needs to be edited
#   in order to allow it, and then changed back after deletion.
kubectl -n sma exec -it ${kafkapod} -c kafka -- sed -n '/offsets.topic.replication.factor=/ a delete.topic.enable=true' /opt/kafka/config/server.properties
kubectl -n sma exec -it ${kafkapod} -c kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic test-topic
kubectl -n sma exec -it ${kafkapod} -c kafka -- sed -n '/delete.topic.enable=true/d' /opt/kafka/config/server.properties

#############################################
# Test case: Kafka Resources

# get cpu and memory limits from kafka statefulset
cpulimit=$(kubectl -n sma describe statefulsets.apps cluster-kafka | grep cpu | head -n 1 |awk '{print $2}')
memlimit=$(kubectl -n sma describe statefulsets.apps cluster-kafka | grep memory | head -n 1 |awk '{print $2}')
rawmemlimit=$(echo $memlimit | numfmt --from=auto)

# get cpu and memory utilization for each kafka pod
memtotal=0
cputotal=0
for i in $(kubectl -n sma get pods | grep kafka | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $cpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $cpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $rawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $memlimit memory limit."
  done

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
echo "Kafka looks healthy"

exit 0