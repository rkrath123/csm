*** Settings ***
Library     OperatingSystem
Library     Process
Force Tags      sms      sma     component

Documentation
...     This is the resiliency test for the Elasticsearch data persistence service in Cray's
...     Shasta System Monitoring Application.
...     This test makes a simple check for a valid environment and initial configuration, and tests for the ability to
...     describe an index both before and after pod and node failover, demonstrating service integrity and volume persistence.
...     See https://connect.us.cray.com/confluence/display/~msilvia/Shasta+SMA+Resiliency+Test+Plan

*** Variables ***
${espod0}     elasticsearch-0
${esdatapod0}     elasticsearch-data-0
${esmasterpod0}     elasticsearch-master-0
${expectedstatus}   yellow

*** Test Case ***
Elasticsearch Configuration
#   This is a minimal test intended to indicate major failures of component deployment.
    ${essvc}=     Run    kubectl -n sma get svc | grep elastic
    Log To Console      ${essvc}
    Should Contain      ${essvc}     elastic
#   Kubernetes persistent volume claim for elastic is bound
    ${elasticpvc}=     Run    kubectl -n sma get pvc | grep elasticsearch
    Should Contain      ${elasticpvc}     Bound
    Should Not Contain      ${elasticpvc}     Available
    Should Not Contain      ${elasticpvc}     Terminating
    Should Not Contain      ${elasticpvc}     Pending
#  	Confirm that Elasticsearch self-reports a healthy state.
    ${health}=     Run   curl -X GET "elasticsearch:9200/_cat/health?v"
    Should Contain      ${health}   elasticsearch
    Should Contain      ${health}   ${expectedstatus}

*** Test Case ***
Expected Elasticsearch Indices Exist
#   Confirm that expected Elasticsearch indices exist.
    ${indices}=     Run   curl -X GET "elasticsearch:9200/_cat/indices?v"
    Should Contain      ${indices}   shasta-logs
#   A “correctly” configured clusterstor system (like venom) has view-logs. If this is to be run on non-clusterstor
#   systems, logic should be added to only look for this when appropriate.
#    Should Contain      ${indices}   view-logs
    Should Contain      ${indices}   .kibana

*** Test Case ***
Elasticsearch Failure - Process Killed
#   Cause the failure of the Elasticsearch process, and confirm that the service recovers gracefully.
    Log To Console      Add a test index in order to provide data for use in verifying persistence.
    ${createindex}=     Run   curl -X PUT "elasticsearch:9200/test?pretty"
    Should Contain X Times      ${createindex}      true    2
    Should Contain      ${createindex}     test
    Log To Console      Checking index status...
    ${index}=     Run   curl -X GET "elasticsearch:9200/_cat/indices?v" | grep test
    Log To Console      ${index}
    Should Contain      ${index}      ${expectedstatus}
    Should Contain      ${index}      test
    Log To Console      Checking elasticsearch health status...
    ${initialstatus}=   Run     curl -X GET "elasticsearch:9200/_cat/health?h=status"
    Log To Console      ${initialstatus}
    Log To Console      Finding the elasticsearch process in the client pod...
    ${process}=     Run     test=$(kubectl -n sma exec -it ${espod0} -- bash -c 'ps -ef -o pid= -o comm | grep java | cut -d "j" -f 1'); echo $test
    Log To Console      Killing the process...
    Run     kubectl -n sma exec -it ${espod0} kill ${process}
    Log To Console      Waiting for elasticsearch health recovery...
    FOR     ${index}        IN RANGE        18
        Sleep       5
        ${esstatus}=   Run    curl -X GET "elasticsearch:9200/_cat/health?h=status"
        Log To Console      Elasticsearch status is ${esstatus}
        Exit For Loop If    '${expectedstatus}' in '''${esstatus}'''
        Run Keyword If      '${index}' == '18'       Fail    Status not ${expectedstatus} after 90 seconds
    END
    Log To Console      Checking for test index (data persistence)...
    ${index}=     Run   curl -X GET "elasticsearch:9200/_cat/indices?v" | grep test
    Log To Console      ${index}
    Should Contain      ${index}      ${expectedstatus}
    Should Contain      ${index}      test

*** Test Case ***
Elasticsearch Failure - Data Process Killed
#   Cause the failure of the Elasticsearch data process, and confirm that the service recovers gracefully.
#   elasticsearch:9200 should be available with a single data process outage.
    Log To Console      Checking Elasticsearch status...
    FOR     ${index}        IN RANGE        18
        Sleep       5
        ${esstatus}=   Run    curl -X GET "elasticsearch:9200/_cat/health?h=status"
        Log To Console      Elasticsearch status is ${esstatus}
        Exit For Loop If    '${expectedstatus}' in '''${esstatus}'''
        Run Keyword If      '${index}' == '18'       Fail    Status not ${expectedstatus} after 90 seconds
    END
    Log To Console      Finding the elasticsearch process in the data pod...
    ${process}=     Run     test=$(kubectl -n sma exec -it ${esdatapod0} -- bash -c 'ps -ef -o pid= -o comm | grep java | cut -d "j" -f 1'); echo $test
    Log To Console      Killing the process...
    Run     kubectl -n sma exec -it ${esdatapod0} kill ${process}
    Log To Console      Checking for test index (data persistence)...
    ${index}=     Run   curl -X GET "elasticsearch:9200/_cat/indices?v" | grep test
    Log To Console      ${index}
    Should Contain      ${index}      ${expectedstatus}
    Should Contain      ${index}      test
    Log To Console      Waiting for elasticsearch health recovery...
    FOR     ${index}        IN RANGE        18
        Sleep       5
        ${esstatus}=   Run    curl -X GET "elasticsearch:9200/_cat/health?h=status"
        Log To Console      Elasticsearch status is ${esstatus}
        Exit For Loop If    '${expectedstatus}' in '''${esstatus}'''
        Run Keyword If      '${index}' == '18'       Fail    Status not ${expectedstatus} after 90 seconds
    END

*** Test Case ***
Elasticsearch Failure - Master Process Killed
#   Cause the failure of the Elasticsearch master process, and confirm that the service recovers gracefully
#   and that service is not disrupted.
    Log To Console      Checking Elasticsearch status...
    FOR     ${index}        IN RANGE        18
        Sleep       5
        ${esstatus}=   Run    curl -X GET "elasticsearch:9200/_cat/health?h=status"
        Log To Console      Elasticsearch status is ${esstatus}
        Exit For Loop If    '${expectedstatus}' in '''${esstatus}'''
        Run Keyword If      '${index}' == '18'       Fail    Status not ${expectedstatus} after 90 seconds
    END
    Log To Console      Finding the elasticsearch process in the data pod...
    ${process}=     Run     test=$(kubectl -n sma exec -it ${esmasterpod0} -- bash -c 'ps -ef -o pid= -o comm | grep java | cut -d "j" -f 1'); echo $test
    Log To Console      Killing the process...
    Run     kubectl -n sma exec -it ${esmasterpod0} kill ${process}
    Log To Console      Checking for test index (failure resiliency)...
    ${index}=     Run   curl -X GET "elasticsearch:9200/_cat/indices?v" | grep test
    Log To Console      ${index}
    Should Contain      ${index}      test
    Log To Console      Waiting for elasticsearch health recovery...
    FOR     ${index}        IN RANGE        18
        Sleep       5
        ${esstatus}=   Run    curl -X GET "elasticsearch:9200/_cat/health?h=status"
        Log To Console      Elasticsearch status is ${esstatus}
        Exit For Loop If    '${expectedstatus}' in '''${esstatus}'''
        Run Keyword If      '${index}' == '18'       Fail    Status not ${expectedstatus} after 90 seconds
    END

*** Test Case ***
Elasticsearch Failure - Pods Deleted
#   Delete and re-apply Elasticsearch pods, and confirm that persisted storage is intact.
    Log To Console      Executing : kubectl delete -f /root/k8s/sma-elasticsearch.yaml
    ${deleteout}=      Run   kubectl delete -f /root/k8s/sma-elasticsearch.yaml
    Log To Console      Output: ${deleteout}
    #   Sleep as workaround for CASM-950. It's taking too long to give up the port after the delete.
    Sleep   130
    Log To Console      Executing : kubectl apply -f /root/k8s/sma-elasticsearch.yaml
    ${applyout}=      Run   kubectl apply -f /root/k8s/sma-elasticsearch.yaml
    Log To Console      Output: ${applyout}
    Log To Console      Waiting for elasticsearch container to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${espod}=     Run    kubectl -n sma get pods | grep elasticsearch | grep -v "data" | cut -d " " -f 1
        Log To Console      elasticsearch pod is: ${espod}
        Exit For Loop If    'elasticsearch' in '${espod}'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    Log To Console      Waiting for elasticsearch data container to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${esdatapod}=     Run    kubectl -n sma get pods | grep elasticsearch | grep "data" | cut -d " " -f 1
        Log To Console      elasticsearch data pod is: ${esdatapod}
        Exit For Loop If    'elasticsearch' in '${esdatapod}'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${espodstatus}=   Run    kubectl -n sma get pod ${espod} -o=custom-columns=STATUS:.status.phase --no-headers=true
        Log To Console      ${espod} is ${espodstatus}
        Exit For Loop If    '${espodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${esdatapodstatus}=   Run    kubectl -n sma get pod ${esdatapod} -o=custom-columns=STATUS:.status.phase --no-headers=true
        Log To Console      ${esdatapod} is ${esdatapodstatus}
        Exit For Loop If    '${esdatapodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    Log To Console      Waiting for elasticsearch health recovery...
    FOR     ${index}        IN RANGE        18
        Sleep       5
        ${esstatus}=   Run    curl -X GET "elasticsearch:9200/_cat/health?h=status"
        Log To Console      Elasticsearch status is ${esstatus}
        Exit For Loop If    '${expectedstatus}' in '''${esstatus}'''
        Run Keyword If      '${index}' == '18'       Fail    Status not ${expectedstatus} after 90 seconds
    END
    Log To Console      Checking for test index (data persistence)...
    ${index}=     Run   curl -X GET "elasticsearch:9200/_cat/indices?v" | grep test
    Log To Console      ${index}
    Should Contain      ${index}      ${expectedstatus}
    Should Contain      ${index}      test
    Log To Console      Removing Test Index...
    [Teardown]  	Run     curl -X DELETE "elasticsearch:9200/test?pretty"