*** Settings ***
Library     OperatingSystem
Library     Process
Force Tags      sms      sma     component

Documentation
...     This is the resiliency test for the Kafka messaging bus in Cray's Shasta System Monitoring Application.
...     See https://connect.us.cray.com/confluence/display/~msilvia/Shasta+SMA+Resiliency+Test+Plan

*** Variables ***
${kafkapod0}     cluster-kafka-0
${kafkapod1}     cluster-kafka-1
${kafkapod2}     cluster-kafka-2
${zkpod2}  	cluster-zookeeper-2

*** Keywords ***
Remove Topic
#   Return the environment to the initial state. Logs are cleaned up automatically when the related topic is deleted.
#   Because the ability to delete topics is disabled by default, the server.properties file needs to be edited
#   in order to allow it, and then changed back after deletion.
    ${enable}=      Run     kubectl -n sma exec -it ${kafkapod0} -- sed -n '/offsets.topic.replication.factor=1/ a delete.topic.enable=true' /opt/kafka/config/server.properties
    Log To Console      ${enable}
    ${delete}=      Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --delete --topic test-topic
    Log To Console      ${delete}
    ${disable}=      Run     kubectl -n sma exec -it ${kafkapod0} -- sed -n '/delete.topic.enable=true/d' /opt/kafka/config/server.properties
    Log To Console      ${disable}

*** Test Case ***
Kafka is Running as a K8S Service
    ${kafkasvc}=     Run    kubectl -n sma get svc | grep kafka
    Should Contain      ${kafkasvc}     cluster-kafka-bootstrap
    Should Contain      ${kafkasvc}     cluster-kafka-brokers

*** Test Case ***
Create Test Topic
    ${createtopic}=    Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --partitions 3 --topic test-topic --replication-factor 3
    Should Contain      ${createtopic}      Created topic test-topic.
    ${topicexists}=    Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --list | grep test-topic
    Should Contain      ${topicexists}      test-topic

*** Test Case ***
Create Producer and Send Message
#   Create a producer and send a message to the previously created test topic
    ${producerout}=     Run     kubectl -n sma exec -it ${kafkapod0} -- bash -c "echo smatest_kafka_res | /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test-topic"
    Log To Console      ${producerout}
    Should Not Contain      ${producerout}      Error

*** Test Case ***
Create Consumer and Receive Message
#   In order to facilitate having the producer and consumer run serially, the consumer is set to get all messages ever
#   posted to the topic and then time out.
    ${consumerout}=     Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-topic --from-beginning --timeout-ms 5000
    Log To Console      ${consumerout}
    Should Contain      ${consumerout}      smatest_kafka_res
    ${partition}=       Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Leader: 0" | cut -d ":" -f 3 | cut -d " " -f 2 | cut -c 1
#   Loop through until ISR catches up
    Log To Console      Waiting for ISR to sync replica 1...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${isr1}=     Run    kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: ${partition}" | cut -d ":" -f 6
        Exit For Loop If    "1" in """${isr1}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR replica 1 not in sync after 5 minutes
    END
    Log To Console      Waiting for ISR to sync replica 2...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${isr2}=     Run    kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: ${partition}" | cut -d ":" -f 6
        Exit For Loop If    "2" in """${isr2}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR replica 2 not in sync after 5 minutes
    END

*** Test Case ***
Service Recovery - Process Killed
#   find node it is running on
    ${kafkanode}=   Run     kubectl -n sma describe pod ${kafkapod0} | grep Node: |awk '{print $2}' | cut -d '/' -f 1
    ${kafkaip}=         Run     kubectl -n sma describe node ${kafkanode} | grep InternalIP: | cut -d " " -f 5
    Log To Console      Kafka is running on ${kafkanode} at IP ${kafkaip}
    ${partition}=       Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Leader: 0" | cut -d ":" -f 3 | cut -d " " -f 2 | cut -c 1
    Log To Console      Partition ${partition} has leader 0.
    ${leader_a}=   Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: ${partition}" | cut -d ":" -f 4 | cut -d " " -f 2 | cut -c 1
    Log To Console          Leader for partition ${partition} is ${leader_a}
#   get the docker container on the node running kafka and kill the process
    ${process}=     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${kafkaip} docker ps -a | grep k8s_kafka_cluster-kafka-0_sma | grep Up | cut -d ' ' -f 1
    ${kill}=        Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${kafkaip} docker kill ${process}
    Should Be Equal    ${kill}     ${process}
    Log To Console      Docker process ${kill} was terminated.
#   confirm container is restarted
    Log To Console      Waiting for container to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${kpodstatus}=   Run    kubectl -n sma get -o json pod/${kafkapod0} | grep phase | cut -d '"' -f 4
        Log To Console      ${kafkapod0} is ${kpodstatus}
        Exit For Loop If    '${kpodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
#   Loop through until Process Up
    Log To Console     Waiting for process to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep   10
        ${status}=     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${kafkaip} docker ps -a --format "{{.ID}}\,{{.Names}}\,{{.Status}}" | grep k8s_kafka_cluster-kafka-0_sma | grep Up | cut -d ',' -f 3 | cut -d ' ' -f 1
        Exit For Loop If    '${status}' == 'Up'
        Run Keyword If      '${index}' == '6'  	Fail    process not Up after 1 minute
    END
#   Loop through until ISR catches up
    Log To Console  	Waiting for ISR to catch up on Partition 0...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p0isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 0" | cut -d ":" -f 6
        Exit For Loop If    "0" in """${p0isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 0 after 5 minutes
    END
    Log To Console      Waiting for ISR to catch up on Partition 1...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p1isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 0" | cut -d ":" -f 6
        Exit For Loop If    "0" in """${p1isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 1 after 5 minutes
    END
    Log To Console      Waiting for ISR to catch up on Partition 2...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p2isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 2" | cut -d ":" -f 6
        Exit For Loop If    "0" in """${p2isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 2 after 5 minutes
    END
  	Sleep  	20
    ${leader_b}=   Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: ${partition}" | cut -d ":" -f 4 | cut -d " " -f 2 | cut -c 1
    Log To Console          Leader was ${leader_a}, and is now ${leader_b}
  	Should Not Be Equal  	${leader_a}  	${leader_b}
    Log To Console      Checking for persisted data...
#   Confirm the message sent earlier still exists
    ${consumerout}=     Run     kubectl -n sma exec -it ${kafkapod0} -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-topic --from-beginning --timeout-ms 5000
    Log To Console      ${consumerout}
    Should Contain      ${consumerout}      smatest_kafka_res

*** Test Case ***
Service Recovery - Pod Deleted
    ${partition}=       Run     kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Leader: 1" | head -n 1 | cut -d ":" -f 3 | cut -d " " -f 2 | cut -c 1
    ${leader_a}=   Run     kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: ${partition}" | cut -d ":" -f 4 | cut -d " " -f 2 | cut -c 1
    Log To Console          Leader for partition ${partition} is ${leader_a}
#   delete the kafka pod
    Log To Console      Deleting the kafka pod
    ${killpod}=        Run     kubectl -n sma delete pod ${kafkapod1}
    Should Contain      ${killpod}     pod \"${kafkapod1}\" deleted
    Log To Console      ${killpod}
#   Loop through until pod is restarted
    Log To Console      Waiting for pod to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${kpodstatus}=   Run    kubectl -n sma get -o json pod/cluster-kafka-1 | grep phase | cut -d '"' -f 4
        Log To Console      ${kafkapod1} is ${kpodstatus}
        Exit For Loop If    '${kpodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
#   find node it is running on
    ${kafkanode}=   Run     kubectl -n sma describe pod ${kafkapod1} | grep Node: | cut -d ' ' -f 16 | cut -d '/' -f 1
    ${kafkaip}=         Run     kubectl -n sma describe node ${kafkanode} | grep InternalIP: | cut -d " " -f 5
    Log To Console      Kafka is running on ${kafkanode} at IP ${kafkaip}
#   Loop through until Process Up
    Log To Console     Waiting for process to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep   10
        ${status}=     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${kafkaip} docker ps -a --format "{{.ID}}\,{{.Names}}\,{{.Status}}" | grep k8s_kafka_cluster-kafka-1_sma | grep Up | cut -d ',' -f 3 | cut -d ' ' -f 1
        Exit For Loop If    '${status}' == 'Up'
        Run Keyword If      '${index}' == '6'       Fail    process not Up after 1 minute
    END
#   Loop through until ISL catches up
    Log To Console      Waiting for ISR to catch up on Partition 0...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p0isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 0" | cut -d ":" -f 6
        Exit For Loop If    "1" in """${p0isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 0 after 5 minutes
    END
    Log To Console      Waiting for ISR to catch up on Partition 1...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p1isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 0" | cut -d ":" -f 6
        Exit For Loop If    "1" in """${p1isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 1 after 5 minutes
    END
    Log To Console      Waiting for ISR to catch up on Partition 2...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p2isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 2" | cut -d ":" -f 6
        Exit For Loop If    "1" in """${p2isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 2 after 5 minutes
    END
  	Sleep  	20
    ${leader_b}=   Run     kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: ${partition}" | cut -d ":" -f 4 | cut -d " " -f 2 | cut -c 1
    Log To Console          Leader was ${leader_a}, and is now ${leader_b}
        Should Not Be Equal     ${leader_a}     ${leader_b}
    Log To Console      Checking for persisted data...
    #   Confirm the message sent earlier still exists?
    ${consumerout}=     Run     kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-topic --from-beginning --timeout-ms 5000
    Log To Console      ${consumerout}
    Should Contain      ${consumerout}      smatest_kafka_res

*** Test Case ***
Service Recovery - Leader and ZK Fail
#   Check that Kafka and Zookeeper recover when they fail together.
    ${partition}=       Run     kubectl -n sma exec -it ${kafkapod2} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Leader: 2" | head -n 1 | cut -d ":" -f 3 | cut -d " " -f 2 | cut -c 1
    Log To Console      Partition ${partition} has leader 2.
    ${leader_a}=   Run     kubectl -n sma exec -it ${kafkapod2} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: ${partition}" | cut -d ":" -f 4 | cut -d " " -f 2 | cut -c 1
    Log To Console          Leader for partition ${partition} is ${leader_a}
#   delete the kafka pod
    Log To Console      Deleting the kafka pod
    ${killkpod}=        Run     kubectl -n sma delete pod ${kafkapod2}
    Should Contain      ${killkpod}     pod \"${kafkapod2}\" deleted
    Log To Console      ${killkpod}
#   delete the zookeeper pod
    Log To Console      Deleting the zookeeper pod
    ${killzkpod}=        Run     kubectl -n sma delete pod ${zkpod2}
    Should Contain      ${killzkpod}     pod \"${zkpod2}\" deleted
    Log To Console      ${killzkpod}
#   Loop through until pod is restarted
    Log To Console      Waiting for pod to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${kpodstatus}=   Run    kubectl -n sma get -o json pod/${kafkapod2} | grep phase | cut -d '"' -f 4
        Log To Console      ${kafkapod2} is ${kpodstatus}
        Exit For Loop If    '${kpodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
#   find node it is running on
    ${kafkanode}=   Run     kubectl -n sma describe pod ${kafkapod2} | grep Node: | cut -d ' ' -f 16 | cut -d '/' -f 1
    ${kafkaip}=         Run     kubectl -n sma describe node ${kafkanode} | grep InternalIP: | cut -d " " -f 5
    Log To Console      Kafka is running on ${kafkanode} at IP ${kafkaip}
    Log To Console      Waiting for zk pod to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${zkpodstatus}=   Run    kubectl -n sma get -o json pod/${zkpod2} | grep phase | cut -d '"' -f 4
        Log To Console      ${zkpod2} is ${zkpodstatus}
        Exit For Loop If    '${zkpodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
#   Loop through until Process Up
    Log To Console     Waiting for process to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep   10
        ${status}=     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${kafkaip} docker ps -a --format "{{.ID}}\,{{.Names}}\,{{.Status}}" | grep k8s_kafka_cluster-kafka-1_sma | grep Up | cut -d ',' -f 3 | cut -d ' ' -f 1
        Exit For Loop If    '${status}' == 'Up'
        Run Keyword If      '${index}' == '6'       Fail    process not Up after 1 minute
    END
#   Loop through until ISL catches up
    Log To Console      Waiting for ISR to catch up on Partition 0...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p0isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 0" | cut -d ":" -f 6
        Exit For Loop If    "2" in """${p0isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 0 after 5 minutes
    END
    Log To Console      Waiting for ISR to catch up on Partition 1...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p1isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 0" | cut -d ":" -f 6
        Exit For Loop If    "2" in """${p1isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 1 after 5 minutes
    END
    Log To Console      Waiting for ISR to catch up on Partition 2...
    FOR     ${index}        IN RANGE        30
        Sleep   10
        ${p2isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 2" | cut -d ":" -f 6
        Exit For Loop If    "2" in """${p2isr}"""
        Run Keyword If      '${index}' == '60'       Fail    ISR not caught up on partition 2 after 5 minutes
    END
  	Sleep  	20
    ${leader_b}=   Run     kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: ${partition}" | cut -d ":" -f 4 | cut -d " " -f 2 | cut -c 1
    Log To Console          Leader was ${leader_a}, and is now ${leader_b}
    Should Not Be Equal     ${leader_a}     ${leader_b}
    Log To Console      Checking for persisted data...
    #   Confirm the message sent earlier still exists?
    ${consumerout}=     Run     kubectl -n sma exec -it ${kafkapod2} -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-topic --from-beginning --timeout-ms 5000
    Log To Console      ${consumerout}
    Should Contain      ${consumerout}      smatest_kafka_res
    [Teardown]          Run Keyword     Remove Topic