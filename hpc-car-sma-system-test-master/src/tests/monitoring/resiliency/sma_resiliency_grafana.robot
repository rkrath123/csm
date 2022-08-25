*** Settings ***
Library     OperatingSystem
Library     Process
Force Tags      sms      sma     component

Documentation
...     This is the resiliency test for the Grafana visualization tool in Cray's Shasta System Monitoring Application.
...     Grafana is a web application used for visualizing time series data. It serves as the UI for telemetry data.
...     Grafana runs as a service inside the K8S cluster. It accesses the telemetry data in Postgres.
...     Grafana is accessed from a remote host running outside of the Kubernetes cluster.
...     A user points a browser to the first SMS host on port 30300 and the local Grafana server returns content.
...     However, in a K8S cluster, Grafana may run on any SMS node, not just on SMS1. In such cases, internal routing
...     in K8S is provided by Kube Proxy - a K8S network proxy service running by default in the kube-system namespace.
...     The K8S network proxy runs on each node.
...     In case of failure of a Grafana pod, Kubernetes will automatically restart the Grafana pod.
...     The restart results in a minimal downtime which may be experienced as timeouts on the Grafana panels.
...     However, upon restart of Grafana pod on another node of the K8S cluster, timeouts disappear automatically.
...     See https://connect.us.cray.com/confluence/display/~msilvia/Shasta+SMA+Resiliency+Test+Plan

*** Keywords ***
Remove Datasource
    ${login}=     Run   curl --cookie-jar cookies.txt -X POST -H "Content-Type: application/json" -d '{"user":"admin", "password":"admin", "email":""}' http://grafana:3000/login
    Should Contain      ${login}   Logged in
    ${datasourceid}=    Run     curl -b cookies.txt http://grafana:3000/api/datasources/name/test|cut -d ':' -f 2|cut -d ',' -f 1
    ${deletedatasrc}=     Run    curl -X DELETE -H "Content-Type: application/json" http://grafana:3000/api/datasources/${datasourceid} -b cookies.txt
    Should Contain      ${deletedatasrc}    Data source deleted
    ${isdeleted}=   Run     curl -b cookies.txt http://grafana:3000/api/datasources/
    Should Not Contain      ${isdeleted}    test

*** Test Case ***
Grafana Initial State
    Log To Console      Checking Grafana Pod Exists in SMA Namespace
    ${getgrafanapod}=     Run    kubectl -n sma get pods | grep grafana
    Log To Console  	${getgrafanapod}
    Should Contain      ${getgrafanapod}     grafana
    Should Contain      ${getgrafanapod}     Running
    Log To Console      Checking Grafana is Running as a K8S Service
    ${getgrafanasvc}=     Run    kubectl -n sma get svc | grep grafana
    Should Contain      ${getgrafanasvc}     grafana
    Log To Console      Checking Grafana-init Job Completed in SMA Namespace
    ${initjob}=     Run    kubectl -n sma get jobs | grep grafana-init
    Log To Console      ${initjob}
    Should Contain      ${initjob}     grafana-init
    Should Contain      ${initjob}     1/1
    Log To Console      Confirm that Grafana self-reports a healthy state.
#   Currently report yellow, but should be green once Grafana runs on multiple nodes.
    ${health}=     Run   curl -X GET "grafana:3000/api/health"
    Should Contain      ${health}   "database": "ok"
    Log To Console      Checking Grafana Login
#  	Confirm that Grafana's login page exists, and can be logged in to.
    ${login}=     Run   curl --cookie-jar cookies.txt -X POST -H "Content-Type: application/json" -d '{"user":"admin", "password":"admin", "email":""}' http://grafana:3000/login
    Should Contain      ${login}   Logged in

# Grafana can get Postgres (and MySQL) data
# This is desirable, but I have so far not found a suitable mechanism for doing it within this CLI-based test framework



*** Test Case ***
Grafana Failure - Pod Deleted
#   Cause the failure of the grafana processes, and confirm that the pod recovers gracefully
#   and that the service is then able to process requests.
    ${grafanapod}=     Run    kubectl -n sma get pods | grep grafana | cut -d " " -f 1
    Log To Console      Checking grafana status...
    FOR     ${index}        IN RANGE        6
        Sleep       5
        ${grafanastatus}=   Run      kubectl -n sma get pod ${grafanapod} -o custom-columns=STATUS:.status.phase --no-headers=True
        Log To Console      grafana status is ${grafanastatus}
        Exit For Loop If    'Running' in '${grafanastatus}'
        Run Keyword If      '${index}' == '18'       Fail    Status not running after 30 seconds
    END
#  	Add a datasource to Grafana and confirm it exists.
    ${adddatasrc}=     Run    curl -X POST -H "Content-Type: application/json" -d '{"name": "test","url": "postgres:5432","access": "proxy", "isDefault": false, "type": "postgres","database": "pmdb","user": "pmdbuser","password": ""}' http://grafana:3000/api/datasources -b cookies.txt
    Should Contain      ${adddatasrc}    Datasource added
    Should Contain      ${adddatasrc}    test
    ${isdatasrc}=     Run    curl -b cookies.txt http://grafana:3000/api/datasources/name/test
    Should Contain      ${isdatasrc}     test
    Should Contain      ${isdatasrc}     postgres:5432
#   Delete and re-apply grafana yaml, and confirm that service still responds to calls.
    Log To Console      Executing : kubectl delete -f /root/k8s/sma-grafana.yaml
    ${deleteout}=      Run   kubectl delete -f /root/k8s/sma-grafana.yaml
    Log To Console      Output: ${deleteout}
    Log To Console      Executing : kubectl apply -f /root/k8s/sma-grafana.yaml
#   Sleep as workaround for CASM-950. It's taking too long to give up the port after the delete.
    Sleep   130
    FOR     ${index}        IN RANGE        6
        Sleep       5
        ${applyout}=      Run   kubectl apply -f /root/k8s/sma-grafana.yaml
        Log To Console      ${applyout}
        Exit For Loop If    'service/grafana created' in '''${applyout}'''
        Run Keyword If      '${index}' == '18'       Fail    grafana service not successfully applied
    END
    Log To Console      Waiting for container to come back up...
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${grafanapod}=     Run    kubectl -n sma get pods | grep grafana | cut -d " " -f 1
        Log To Console      grafanapod is: ${grafanapod}
        Exit For Loop If    'grafana' in '${grafanapod}'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    FOR     ${index}        IN RANGE        6
        Sleep       10
        ${gpodstatus}=   Run    kubectl -n sma get pod ${grafanapod} -o=custom-columns=STATUS:.status.phase --no-headers=true
        Log To Console      ${grafanapod} is ${gpodstatus}
        Exit For Loop If    '${gpodstatus}' == 'Running'
        Run Keyword If      '${index}' == '6'       Fail    pod not running after 1 minute
    END
    ${grafanaip}=    Run     kubectl -n sma get svc grafana -o=custom-columns=IP:.spec.clusterIP --no-headers=true
    Log To Console      Waiting for grafana health recovery...
    FOR     ${index}        IN RANGE        6
        Sleep       5
        ${health}=     Run   curl -X GET "grafana:3000/api/health"
        Log To Console      grafana health report:
        Log To Console      ${health}
        Exit For Loop If    '"database": "ok"' in '''${health}'''
        Run Keyword If      '${index}' == '18'       Fail    Health not ok after 30 seconds
    END
    ${login}=     Run   curl --cookie-jar cookies.txt -X POST -H "Content-Type: application/json" -d '{"user":"admin", "password":"admin", "email":""}' http://grafana:3000/login
    Should Contain      ${login}   Logged in
    Log To Console      Checking for test index (data persistence)...
#  	grafana test datasource can be retrieved (persistence).
    ${datasource}=      Run     curl -b cookies.txt http://grafana:3000/api/datasources/name/test
    Should Contain      ${datasource}   "name":"test","type":"postgres"
    Log To Console      Removing Test Index...
    [Teardown]  	Run Keywords  	Remove Datasource

