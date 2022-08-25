*** Settings ***
Library     OperatingSystem
Library     Process
Force Tags      sms      sma     component

Documentation
...     This is the resiliency test for the Kibana visualization tool in Cray's Shasta System Monitoring Application.
...     Kibana runs as a web application, and allows the formation of complex search queries, and shows matching log events mapped over time.
...     Kibana runs as a service inside the Kubernetes cluster, and queries the data stored in the ElasticSearch database.
...     Kibana is accessed from a remote host running outside of the Kubernetes cluster.
...     A user can access it from a web browser, by entering into the location bar any of the SMS hosts at port 30601.
...     Kubernetes port forwarding will pass this request to the Kibana server, running on one of the SMS server nodes, which will serve the Kibana web page out to the client.
...     See https://connect.us.cray.com/confluence/display/~msilvia/Shasta+SMA+Resiliency+Test+Plan

*** Variables ***
${espod0}     elasticsearch-0
${esdatapod0}     elasticsearch-data-0
${esmasterpod0}     elasticsearch-master-0
${expectedstatus}   yellow

*** Keywords ***
Remove Index
    ${kibanaip}=    Run     kubectl -n sma get svc kibana -o=custom-columns=IP:.spec.clusterIP --no-headers=true
    Run     curl -X DELETE http://${kibanaip}:5601/api/saved_objects/index-pattern/test-pattern -H 'kbn-xsrf: true' -H 'Content-Type: application/json'

*** Test Case ***
Kibana Configuration
#   This is a minimal test intended to indicate major failures of kibana component deployment.
    Log To Console      Confirming kibana pod exists in SMA namespace...
    ${kibanapod}=     Run    kubectl -n sma get pods | grep kibana
    Log To Console  	${kibanapod}
    Should Contain      ${kibanapod}     kibana
    Should Contain      ${kibanapod}     Running
    Log To Console      Confirming kibana is running as a K8S service...
    ${kibanasvc}=     Run    kubectl -n sma get svc | grep kibana
    Should Contain      ${kibanasvc}     kibana

*** Test Case ***
Elasticsearch Configuration
#   This is a minimal test intended to indicate major failures of elasticsearch component deployment, because
#   kibana has a dependency on it as a data source.
    Log To Console      Confirming elasticsearch is running as a k8s service...
    ${essvc}=     Run    kubectl -n sma get svc | grep elastic
    Log To Console      ${essvc}
    Should Contain      ${essvc}     elastic
    Log To Console      Confirming Kubernetes persistent volume claim for elastic is bound...
    ${elasticpvc}=     Run    kubectl -n sma get pvc | grep elasticsearch
    Log To Console      ${elasticpvc}
    Should Contain      ${elasticpvc}     Bound
    Should Not Contain      ${elasticpvc}     Available
    Should Not Contain      ${elasticpvc}     Terminating
    Should Not Contain      ${elasticpvc}     Pending
    Log To Console      Confirming  Elasticsearch self-reports a healthy state...
    ${health}=     Run   curl -X GET "elasticsearch:9200/_cat/health?v"
    Log To Console      ${health}
    Should Contain      ${health}   elasticsearch
    Should Contain      ${health}   ${expectedstatus}

*** Test Case ***
Kibana Failure - Pod Deleted
#   Cause the failure of the kibana process, and confirm that the pod recovers gracefully
#   and that service is then able to process requests.
    ${kibanapod}=     Run    kubectl -n sma get pods | grep kibana | cut -d " " -f 1
    Log To Console      Checking kibana status...
    FOR     ${index}        IN RANGE        6
        Sleep       5
        ${kibanastatus}=   Run      kubectl -n sma get pod ${kibanapod} -o custom-columns=STATUS:.status.phase --no-headers=True
        Log To Console      kibana status is ${kibanastatus}
        Exit For Loop If    'Running' in '${kibanastatus}'
        Run Keyword If      '${index}' == '18'       Fail    Status not running after 30 seconds
    END
    ${httpcode}=    Run     curl -I http://kibana:5601 | grep HTTP
    Should Contain      ${httpcode}     200 OK
#   do some kibana stuff
#  	Kibana index-patterns can be created.
    ${createpattern}=     Run    curl -X POST "http://kibana:5601/api/saved_objects/index-pattern/test-pattern" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d '{"attributes": {"title": "test-pattern-title"}}'
    Should Contain      ${createpattern}    "id":"test-pattern"
    Should Contain      ${createpattern}    "type":"index-pattern"
    Should Contain      ${createpattern}    "title":"test-pattern-title"
#   Delete and re-apply Kibana yaml, and confirm that service still responds to calls.
    Log To Console      Executing : kubectl delete -f /root/k8s/sma-kibana.yaml
    ${deleteout}=      Run   kubectl delete -f /root/k8s/sma-kibana.yaml
    Log To Console      Output: ${deleteout}
    Log To Console      Executing : kubectl apply -f /root/k8s/sma-kibana.yaml
#   Sleep as workaround for CASM-950. It's taking too long to give up the port after the delete.
    Sleep   130
    FOR     ${index}        IN RANGE        6
        Sleep       5
        ${applyout}=      Run   kubectl apply -f /root/k8s/sma-kibana.yaml
        Log To Console      ${applyout}
        Exit For Loop If    'service/kibana created' in '''${applyout}'''
        Run Keyword If      '${index}' == '18'       Fail    kibana service not successfully applied
    END
    Log To Console      Waiting for container to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${kibanapod}=     Run    kubectl -n sma get pods | grep kibana | cut -d " " -f 1
        Log To Console      kibanapod is: ${kibanapod}
        Exit For Loop If    'kibana' in '${kibanapod}'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${kpodstatus}=   Run    kubectl -n sma get pod ${kibanapod} -o=custom-columns=STATUS:.status.phase --no-headers=true
        Log To Console      ${kibanapod} is ${kpodstatus}
        Exit For Loop If    '${kpodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    ${kibanaip}=    Run     kubectl -n sma get svc kibana -o=custom-columns=IP:.spec.clusterIP --no-headers=true
    Log To Console      Waiting for kibana health recovery...
    FOR     ${index}        IN RANGE        6
        Sleep       5
        ${kibanastatus}=    Run     curl -XGET http://${kibanaip}:5601/api/status
        Log To Console      Kibana status report:
        Log To Console      ${kibanastatus}
        Exit For Loop If    '"overall":{"state":"green"' in '''${kibanastatus}'''
        Run Keyword If      '${index}' == '18'       Fail    Status not recovered after 30 seconds
    END
    ${httpcode}=    Run     curl -I http://${kibanaip}:5601 | grep HTTP
    Should Contain      ${httpcode}     200 OK
    Log To Console      Checking for test index (data persistence)...
#  	Kibana index-patterns can be retrieved.
    ${getpattern}=      Run     curl -X GET "http://${kibanaip}:5601/api/saved_objects/index-pattern/test-pattern"
    Should Contain      ${getpattern}   "title":"test-pattern-title"
    Log To Console      Removing Test Index...
    [Teardown]  	Run Keywords  	Remove Index

*** Test Case ***
ElasticSearch Pod failure
#   ElasticSearch supports internal high availability functionality. As such, the failure of a single ElasticSearch pod
#   within the cluster will not prevent normal operation. Kibana, which depends upon ElasticSearch for it's storage and
#   search functionality, is thus insulated from service availability problems associated with ElasticSearch failures.
#   Some in-flight requests may fail or time-out if they hit the ElasticSearch pod as it fails.
#   Restarting these requests will cause them to target a different ElasticSearch pod, and restore normal operation.
#   This test examines the result of kubernetes deleting and re-applying the Elasticsearch service and it's pods.
#   Delete and re-apply Elasticsearch pods, and confirm that kibana can still connect after recovery
    ${kibanaip}=    Run     kubectl -n sma get svc kibana -o=custom-columns=IP:.spec.clusterIP --no-headers=true
    Log To Console      Kibana SVC IP= ${kibanaip}
    ${kibanastatus}=    Run     curl -XGET http://${kibanaip}:5601/api/status
    Log To Console      Kibana status report:
    Log To Console      ${kibanastatus}
    Should Contain      ${kibanastatus}     "overall":{"state":"green"
    Should Contain      ${kibanastatus}     "plugin:elasticsearch@5.6.4","state":"green"
    Log To Console      Executing : kubectl delete -f /root/k8s/sma-elasticsearch.yaml
    ${deleteout}=   Run   kubectl delete -f /root/k8s/sma-elasticsearch.yaml
    Log To Console      Output: ${deleteout}
    Log To Console      Sleeping for CASM-950 workaround
    #   Sleep as workaround for CASM-950. It's taking too long to give up the port after the delete.
    Sleep   130
    ${kibanastatus}=    Run     curl -XGET http://${kibanaip}:5601/api/status
    Log To Console      Kibana status report:
    Log To Console      ${kibanastatus}
    Should Contain      ${kibanastatus}     "plugin:elasticsearch@5.6.4","state":"red"
    Log To Console      Executing : kubectl apply -f /root/k8s/sma-elasticsearch.yaml
    FOR     ${index}        IN RANGE        6
        Sleep       5
        ${applyout}=      Run   kubectl apply -f /root/k8s/sma-elasticsearch.yaml
        Log To Console      ${applyout}
        Exit For Loop If    'service/elasticsearch created' in '''${applyout}'''
        Run Keyword If      '${index}' == '18'       Fail    elasticsearch service not applied successfully
    END
    Log To Console      Waiting for elasticsearch health recovery...
    FOR     ${index}        IN RANGE        18
        Sleep       5
        ${esstatus}=   Run    curl -X GET "elasticsearch:9200/_cat/health?h=status"
        Log To Console      Elasticsearch status is ${esstatus}
        Exit For Loop If    '${expectedstatus}' in '''${esstatus}'''
        Run Keyword If      '${index}' == '18'       Fail    Status not ${expectedstatus} after 90 seconds
    END
    Log To Console      Checking for elasticsearch status in kibana:
    ${kibanaip}=    Run     kubectl -n sma get svc kibana -o=custom-columns=IP:.spec.clusterIP --no-headers=true
    Log To Console      Kibana SVC IP= ${kibanaip}
    ${kibanastatus}=    Run     curl -XGET http://${kibanaip}:5601/api/status
    Log To Console      Kibana status report:
    Log To Console      ${kibanastatus}
    Should Contain      ${kibanastatus}     "overall":{"state":"green"
    Should Contain      ${kibanastatus}     "plugin:elasticsearch@5.6.4","state":"green"