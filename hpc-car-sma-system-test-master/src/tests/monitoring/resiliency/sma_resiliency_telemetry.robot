*** Settings ***
Library     OperatingSystem
Library     Process
Force Tags      sms      sma     component

Documentation
...     This is the resiliency test for the Telemetry API service in Cray's Shasta System Monitoring Application.
...     This test makes a simple check for a valid environment and initial configuration, and tests for the ability to
...     use the API both before and after process and pod failure, demonstrating service integrity. It also checks that
...     telemetry API can successfully poll data after the failure and recovery of the kafka service.
...     See https://connect.us.cray.com/confluence/display/~msilvia/Shasta+SMA+Resiliency+Test+Plan
...     See also https://connect.us.cray.com/confluence/display/SNXEng/Telemetry+API+V1+User+Documentation+-+Shasta

*** Variables ***
${telemetrypod1}     telemetry-0
${kafkapod1}     cluster-kafka-1

*** Keywords ***
Remove Examples
    ${telemetrypod}=    Run     kubectl -n sma get pods | grep telemetry | head -n 1 | cut -d ' ' -f 1
    Run     rm -r /examples/

*** Test Case ***
Telemetry Configuration
    Log To Console      Confirm telemetry is Running as a K8S Service...
    ${telemsvc}=     Run    kubectl -n sma get svc | grep telemetry
    Should Contain      ${telemsvc}     telemetry
    Log To Console      Confirm Kafka DNS is resolvable
    ${telempod}=     Run    kubectl -n sma get pods | grep telemetry | grep -v test | head -n 1 | cut -d ' ' -f 1
    Should Contain      ${telempod}     telemetry
    ${ping}=    Run     kubectl -n sma exec -it ${telempod} -- ping -c 1 cluster-kafka-bootstrap
    Log To Console      ${ping}
    Should Contain      ${ping}     1 packets transmitted, 1 packets received, 0% packet loss
    Log To Console      Running Telemetry Unit Test
    ${telempod}=     Run    kubectl -n sma get pods | grep telemetry | grep -v test | head -n 1 | cut -d ' ' -f 1
    Should Contain      ${telempod}     telemetry
    ${unitout}=     Run     kubectl -n sma exec -it ${telempod} -- python /test/unit_test_jenkins.py
    Log To Console      ${unitout}
    Should Contain      ${unitout}      OK

*** Test Case ***
Telemetry Failure - Process Killed
#   Copy telemetry client.
    ${telemetrypod}=    Run     kubectl -n sma get pods | grep telemetry | head -n 1 | cut -d ' ' -f 1
    Run     kubectl cp -n sma $(kubectl get pods -n sma | grep ${telemetrypod} | cut -d " " -f 1):/examples examples
    Run     chmod 777 /examples/client_endpoint.py
#   Use telemetry client to get data.
    ${servernode}=   Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    ${tport}=   Run     kubectl -n sma get svc -o=custom-columns=PORT:.spec.ports,NODE:.metadata.name | grep telemetry | cut -d " " -f 2 | cut -d ":" -f 2
    ${nodemetrics}=     Run     ./examples/client_endpoint.py -b 4 -c 2 -i cray-node -s ${servernode} -p ${tport} -t cray-node
    Should Contain      ${nodemetrics}      "metrics":
#   Cause the failure of the Telemetry process, and confirm that the service is uninterrupted and recovers gracefully.
    ${telempod}=     Run    kubectl -n sma get pods | grep telemetry | grep -v test | head -n 1 | cut -d ' ' -f 1
    Should Contain      ${telempod}     telemetry
    Log To Console      Finding the telemetry process in the client pod...
    ${process}=     Run     test=$(kubectl -n sma exec -it ${telempod} -- bash -c 'ps -ef -o pid= -o comm | grep telemetry | cut -d "t" -f 1'); echo $test
    Log To Console      Killing the process...
    Run     kubectl -n sma exec -it ${telempod} kill ${process}
        Log To Console      Waiting for container to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${telemetrypod}=     Run    kubectl -n sma get pods | grep telemetry | head -n 1 | cut -d " " -f 1
        Log To Console      telemetrypod is: ${telemetrypod}
        Exit For Loop If    'telemetry' in '${telemetrypod}'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    Log To Console      Waiting for telemetry health recovery...
    FOR     ${index}        IN RANGE        18
        Sleep       5
        ${telemstatus}=   Run    kubectl -n sma get pods -o custom-columns=STATUS:status.phase,NAME:.metadata.name | grep ${telempod} | cut -d " " -f 1
        Log To Console      telemetry status is ${telemstatus}
        Exit For Loop If    '${telemstatus}' == 'Running'
        Run Keyword If      '${index}' == '18'       Fail    Disrupted pod not Running after 90 seconds
    END
    Log To Console      Re-running Unit Test after failure...
    ${unitout}=     Run     kubectl -n sma exec -it ${telempod} -- python /test/unit_test_jenkins.py
    Log To Console      ${unitout}
    Should Contain      ${unitout}      OK
#   Confirm telemetry client is receiving data.
    ${servernode}=   Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    ${tport}=   Run     kubectl -n sma get svc -o=custom-columns=PORT:.spec.ports,NODE:.metadata.name | grep telemetry | cut -d " " -f 2 | cut -d ":" -f 2
    ${nodemetrics}=     Run     ./examples/client_endpoint.py -b 4 -c 2 -i cray-node -s ${servernode} -p ${tport} -t cray-node
    Should Contain      ${nodemetrics}      "metrics":
    [Teardown]          Run Keyword     Remove Examples

*** Test Case ***
Telemetry Failure - Pod Deleted
#   Copy telemetry client.
    ${telemetrypod}=    Run     kubectl -n sma get pods | grep telemetry | head -n 1 | cut -d ' ' -f 1
    Run     kubectl cp -n sma $(kubectl get pods -n sma | grep ${telemetrypod} | cut -d " " -f 1):/examples examples
    Run     chmod 777 /examples/client_endpoint.py
#   Use telemetry client to get data.
    ${servernode}=   Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    ${tport}=   Run     kubectl -n sma get svc -o=custom-columns=PORT:.spec.ports,NODE:.metadata.name | grep telemetry | cut -d " " -f 2 | cut -d ":" -f 2
    ${nodemetrics}=     Run     ./examples/client_endpoint.py -b 4 -c 2 -i cray-node -s ${servernode} -p ${tport} -t cray-node
    Should Contain      ${nodemetrics}      "metrics":
#   Delete and re-apply telemetry pods, and confirm that service is functioning.
    Log To Console      Executing : kubectl delete -f /root/k8s/sma-telemetry-api.yaml
    ${deleteout}=      Run   kubectl delete -f /root/k8s/sma-telemetry-api.yaml
    Log To Console      Output: ${deleteout}
    Log To Console      Executing : kubectl apply -f /root/k8s/sma-telemetry-api.yaml
#   Sleep as workaround for CASM-950. It's taking too long to give up the port after the delete.
    Sleep   130
    FOR     ${index}        IN RANGE        6
        Sleep       5
        ${applyout}=      Run   kubectl apply -f /root/k8s/sma-telemetry-api.yaml
        Log To Console      ${applyout}
        Exit For Loop If    'service/telemetry created' in '''${applyout}'''
        Run Keyword If      '${index}' == '18'       Fail    telemetry service not successfully applied
    END
    Log To Console      Waiting for container to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${telemetrypod}=     Run    kubectl -n sma get pods | grep telemetry | head -n 1 | cut -d " " -f 1
        Log To Console      telemetrypod is: ${telemetrypod}
        Exit For Loop If    'telemetry' in '${telemetrypod}'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${tpodstatus}=   Run    kubectl -n sma get pod ${telemetrypod} -o=custom-columns=STATUS:.status.phase --no-headers=true
        Log To Console      ${telemetrypod} is ${tpodstatus}
        Exit For Loop If    '${tpodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    Log To Console      Re-running Unit Test after failure...
    ${telemetrypod}=    Run     kubectl -n sma get pods | grep telemetry | head -n 1 | cut -d ' ' -f 1
    ${unitout}=     Run     kubectl -n sma exec -it ${telemetrypod} -- python /test/unit_test_jenkins.py
    Log To Console      ${unitout}
    Should Contain      ${unitout}      OK
#   Confirm telemetry client is receiving data.
    ${servernode}=   Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    ${tport}=   Run     kubectl -n sma get svc -o=custom-columns=PORT:.spec.ports,NODE:.metadata.name | grep telemetry | cut -d " " -f 2 | cut -d ":" -f 2
    ${nodemetrics}=     Run     ./examples/client_endpoint.py -b 4 -c 2 -i cray-node -s ${servernode} -p ${tport} -t cray-node
    Should Contain      ${nodemetrics}      "metrics":
    [Teardown]          Run Keyword     Remove Examples

*** Test Case ***
Kafka Failure - Telemetry Recovers
#   Copy telemetry client.
    ${telemetrypod}=    Run     kubectl -n sma get pods | grep telemetry | head -n 1 | cut -d ' ' -f 1
    Run     kubectl cp -n sma $(kubectl get pods -n sma | grep ${telemetrypod} | cut -d " " -f 1):/examples examples
    Run     chmod 777 /examples/client_endpoint.py
#   Use telemetry client to get data.
    ${servernode}=   Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    ${tport}=   Run     kubectl -n sma get svc -o=custom-columns=PORT:.spec.ports,NODE:.metadata.name | grep telemetry | cut -d " " -f 2 | cut -d ":" -f 2
    ${nodemetrics}=     Run     ./examples/client_endpoint.py -b 4 -c 2 -i cray-node -s ${servernode} -p ${tport} -t cray-node
    Should Contain      ${nodemetrics}      "metrics":
#   delete the kafka pod
    Log To Console      Deleting kafka pod...
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
        Run Keyword If      '${index}' == '6'       Fail    Kafka pod not running after 1 minute
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
    FOR     ${index}        IN RANGE        10
        Sleep   30
        Log To Console      Partition 0 iteration ${index}...
        ${p0isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 0" | cut -d ":" -f 6
        Exit For Loop If    "1" in """${p0isr}"""
        Run Keyword If      '${index}' == '10'       Fail    ISR not caught up on partition 0 after 5 minutes
    END
    Log To Console      Waiting for ISR to catch up on Partition 1...
    FOR     ${index}        IN RANGE        10
        Sleep   30
        Log To Console      Partition 1 iteration ${index}...
        ${p1isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 0" | cut -d ":" -f 6
        Exit For Loop If    "1" in """${p1isr}"""
        Run Keyword If      '${index}' == '10'       Fail    ISR not caught up on partition 1 after 5 minutes
    END
    Log To Console      Waiting for ISR to catch up on Partition 2...
    FOR     ${index}        IN RANGE        10
        Sleep   30
        Log To Console      Partition 2 iteration ${index}...
        ${p2isr}=     Run    kubectl -n sma exec -it ${kafkapod1} -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic test-topic | grep "Partition: 2" | cut -d ":" -f 6
        Exit For Loop If    "1" in """${p2isr}"""
        Run Keyword If      '${index}' == '10'       Fail    ISR not caught up on partition 2 after 5 minutes
    END
  	Sleep  	20
#   Confirm telemetry client is receiving data.
    ${servernode}=   Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    ${tport}=   Run     kubectl -n sma get svc -o=custom-columns=PORT:.spec.ports,NODE:.metadata.name | grep telemetry | cut -d " " -f 2 | cut -d ":" -f 2
    ${nodemetrics}=     Run     ./examples/client_endpoint.py -b 4 -c 2 -i cray-node -s ${servernode} -p ${tport} -t cray-node
    Should Contain      ${nodemetrics}      "metrics":
    [Teardown]          Run Keyword     Remove Examples