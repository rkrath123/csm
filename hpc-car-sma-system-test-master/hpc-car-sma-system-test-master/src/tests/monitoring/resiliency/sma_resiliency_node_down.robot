*** Settings ***
Library     OperatingSystem
Library     Process
Library     String
Library     Collections
Force Tags      sms      sma     component

Documentation
...     This is the node failure resiliency test for Cray's Shasta System Monitoring Application.
...     This test makes a simple check for a valid and healthy environment and then powers off a worker node via the
...     ipmitool. It confirms that nodes are restarted on other nodes, or that they are left in "Terminating" if they
...     have an affinity, taint, or PVC mount that would prevent that. In the case of PVC mounts, the nodes are forced
...     to terminate and are expected to start elsewhere, except for Elasticsearch, which only allows one pod per node.
...     The node is then powered back on, at which point all pods should be fully recovered.
...     See https://connect.us.cray.com/confluence/display/~msilvia/Shasta+SMA+Resiliency+Test+Plan

*** Keywords ***
Check Pod Status Not
#   Confirm pods don't have given status
    [Arguments]    ${status}    ${podcount}      ${pods}
    FOR     ${index}    IN RANGE    12
        Sleep   10
        ${stats}=   Run     kubectl -n sma get pod | grep ncn-w002 | awk '{print $1 " " $3}'
        Log To Console      ${stats}
        ${contains}=    Run Keyword And Return Status    Should Not Contain    ${stats}    ${status}
        ${podstatus}=     Set Variable If     '${contains}' == 'True'     Complete    Incomplete
    END
    [Return]    ${podstatus}



*** Test Case ***
Initial State
#   Validate that the SMA services are initially healthy.
#   SMA Namespace Exists
    ${smanamespace}=     Run    kubectl get namespace | grep sma
    Should Contain      ${smanamespace}     sma
    Should Contain      ${smanamespace}     Active
    Should Not Contain      ${smanamespace}      Terminating
#   Pods in SMA Namespace are healthy
    ${pods}=     Run    kubectl -n sma get pods -o wide
    Log To Console  	${pods}
    Should Not Contain      ${pods}      Failed
    Should Not Contain      ${pods}      Unknown
    Should Not Contain      ${pods}      Pending
    Should Not Contain      ${pods}      CrashLoopBackOff
    Should Not Contain      ${pods}      Error
    Should Not Contain      ${pods}      ContainerCreating
#   K8S Services are up
    ${svcs}=     Run    kubectl -n sma get svc
    Log To Console      ${svcs}
    Should Contain      ${svcs}     elastic
    Should Contain      ${svcs}     cluster-kafka-bootstrap
    Should Contain      ${svcs}     cluster-kafka-brokers
    Should Contain      ${svcs}     cluster-zookeeper-client
    Should Contain      ${svcs}     cluster-zookeeper-nodes
    Should Contain      ${svcs}     elasticsearch
    Should Contain      ${svcs}     elasticsearch-curator
    Should Contain      ${svcs}     elasticsearch-master
    Should Contain      ${svcs}     elasticsearch-master-headless
    Should Contain      ${svcs}     mysql
    Should Contain      ${svcs}     rsyslog-aggregator
    Should Contain      ${svcs}     rsyslog-aggregator-can
    Should Contain      ${svcs}     rsyslog-aggregator-can-udp
    Should Contain      ${svcs}     rsyslog-aggregator-hmn
    Should Contain      ${svcs}     rsyslog-aggregator-hmn-udp
    Should Contain      ${svcs}     rsyslog-aggregator-udp
    Should Contain      ${svcs}     rsyslog-collector
    Should Contain      ${svcs}     sma-cstream
    Should Contain      ${svcs}     sma-ldms-aggr-compute
    Should Contain      ${svcs}     sma-ldms-aggr-ncn
    Should Contain      ${svcs}     sma-monasca-api
    Should Contain      ${svcs}     sma-monasca-keystone
    Should Contain      ${svcs}     sma-monasca-memcached
    Should Contain      ${svcs}     sma-monasca-mysql
    Should Contain      ${svcs}     sma-monasca-zoo-entrance
    Should Contain      ${svcs}     sma-postgres-cluster
    Should Contain      ${svcs}     sma-postgres-cluster-config
    Should Contain      ${svcs}     sma-postgres-cluster-repl
#   Ceph Namespace Exists
    ${cnamespace}=    Run     kubectl get namespace | grep ceph
    Log To Console      ${cnamespace}
    Should Contain      ${cnamespace}     ceph
    Should Contain          ${cnamespace}      Active
    Should Not Contain      ${cnamespace}      Terminating
#   Kubernetes persistent volume claims in the sma namespace are bound
    ${pvcs}=     Run    kubectl -n sma get pvc
    Log To Console      ${pvcs}
    Should Contain      ${pvcs}     Bound
    Should Not Contain      ${pvcs}     Available
    Should Not Contain      ${pvcs}     Terminating
    Should Not Contain      ${pvcs}     Pending
#  	Confirm that Elasticsearch self-reports a healthy state.
    ${health}=     Run   curl -X GET "elasticsearch:9200/_cat/health?v"
    Log To Console      ${health}
    Should Contain      ${health}   elasticsearch
    Should Contain Any      ${health}   green   yellow

*** Test Case ***
Node Down
#   Power off a worker node and confirm pods on that node respond appropriately
#   Find pods running on ncn-w002
    ${pods}=     Run     kubectl -n sma get pods -o wide | grep ncn-w002 | awk '{print $1}'
    ${podcount}=    Get Line Count      ${pods}
    Log To Console      ${podcount} pods are running on ncn-w002
#   use ipmitool to power off ncn-w002
    ${poweroff}=    Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@ncn-w001 ipmitool -I lanplus -H 10.254.2.2 -U root -P initial0 chassis power off
    Log To Console      ${poweroff}
    Should Contain      ${poweroff}     Chassis Power Control: Down/Off
#   attempt to connect to the node in order to verify it is down
    FOR     ${index}        IN RANGE        12
       Sleep   10
        ${pingnode}=    Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@ncn-w001 ssh ncn-w002 -o ConnectTimeout=5 hostname
        Log To Console      ${pingnode}
        Exit For Loop If      '${pingnode}' == 'ssh: connect to host ncn-w002 port 22: No route to host'
        Exit For Loop If      '${pingnode}' == 'ssh: connect to host ncn-w002 port 22: Broken pipe'
        Exit For Loop If      '${pingnode}' == 'ssh: connect to host ncn-w002 port 22: closed by remote host'
        Exit For Loop If      '${pingnode}' == 'ssh: connect to host ncn-w002 port 22: Connection refused'
        Exit For Loop If      '${pingnode}' == 'ssh: connect to host ncn-w002 port 22: Connection timed out'
    END
    Run Keyword If      '${pingnode}' == 'ncn-w002'   Fail      Node ncn-w002 still up
    Log To Console      Node is down. Confirming pod termination...
#   Confirm pods on ncn-w002 terminate:
    Sleep   120
    FOR     ${index}    IN RANGE    30
        Sleep   10
        ${podstatus}=   Check Pod Status Not   Running      ${podcount}     ${pods}
        Exit For Loop If      '${podstatus}' == 'Complete'
    END
    Run Keyword If      '${podstatus}' == 'Incomplete'   Fail      Some pods not Terminating
    Run Keyword If      '${podstatus}' == 'Complete'   Log To Console      All ncn-w002 SMA pods entered Terminating

*** Test Case ***
Force Delete
#   Force kubernetes to move pods with PVC that are stuck in Terminating.
#   Find PVC pods stuck in Terminating
    ${pods}=     Run     kubectl -n sma get pods -o wide | grep Terminating | awk '{print $1}'
    ${podcount}=    Get Line Count      ${pods}
    Log To Console      ${podcount} pods are stuck in terminating
#   Delete PVC pods stuck in Terminating
    FOR     ${index}        IN RANGE        ${podcount}
        ${serverpod}=   Get Line   ${pods}      ${index}
        ${deletepod}=   Run     kubectl delete pod -n sma ${serverpod} --force --grace-period=0
        Should Contain      ${deletepod}    pod "${serverpod}" force deleted
    END
#   Confirm pods in Terminating are moved when deleted:
    FOR     ${index}        IN RANGE        12
        Sleep       10
        ${terminating}=     Run     kubectl -n sma get pods -o wide | grep Terminating | awk '{print $1}'
        ${termcount}=   Get Line Count      ${terminating}
        Log To Console      ${termcount} pods are still terminating
        Exit For Loop If    '${termcount}' == '0'
    END
    Run Keyword If      '${termcount}' != '0'   Fail      Some pods did not change state
    Run Keyword If      '${termcount}' == '0'   Log To Console      All pods were deleted successfully
#   Pods in SMA Namespace are healthy
    ${pods}=     Run    kubectl -n sma get pods
    Should Not Contain      ${pods}      Failed
    Should Not Contain      ${pods}      Unknown
    Should Not Contain      ${pods}      Pending
    Should Not Contain      ${pods}      CrashLoopBackOff
    Should Not Contain      ${pods}      Terminating

*** Test Case ***
Node Up
#   Restart the node
#   use ipmitool to power on ncn-w002
    ${poweron}=    Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@ncn-w001 ipmitool -I lanplus -H 10.254.2.2 -U root -P initial0 chassis power on
    Should Contain      ${poweron}     Chassis Power Control: Up/On
    #   Confirm node comes back up:
    FOR     ${index}        IN RANGE        12
        Sleep       10
#       attempt to connect to the node in order to verify it is down
        ${isup}=    Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@ncn-w001 ssh ncn-w002 -o ConnectTimeout=5 hostname
        Should Contain      ${isup}     ncn-w002
        Log To Console      ssh hostname response: ${isup}
        Exit For Loop If    '${isup}' == 'ncn-w002'
    END
    Run Keyword If      '${isup}' != 'ncn-w002'   Fail      node not responsive
    Run Keyword If      '${isup}' != 'ncn-w002'   Log To Console      node restarted successfully
    #   Pods in SMA Namespace recover
    Log To Console      Confirming pod recovery...

#   Confirm pods on ncn-w002 recover:
    ${pods}=     Run     kubectl -n sma get pods -o wide | grep ncn-w002 | awk '{print $1}'
    ${podcount}=    Get Line Count      ${pods}
    Log To Console      ${podcount} pods are assigned to ncn-w002
    Sleep   120
    FOR     ${index}    IN RANGE    30
        Sleep   10
        ${podstatus}=   Check Pod Status Not   Running      ${podcount}     ${pods}
        Exit For Loop If      '${podstatus}' == 'Complete'
    END
    Run Keyword If      '${podstatus}' == 'Incomplete'   Fail      Some pods not Running on ncn-w002
    Run Keyword If      '${podstatus}' == 'Complete'   Log To Console      All ncn-w002 SMA pods are Running
    #   Pods in SMA Namespace are healthy
    ${pods}=     Run    kubectl -n sma get pods -o wide
    Log To Console  	${pods}
    Should Not Contain      ${pods}      Failed
    Should Not Contain      ${pods}      Unknown
    Should Not Contain      ${pods}      Pending
    Should Not Contain      ${pods}      CrashLoopBackOff
    Should Not Contain      ${pods}      Error
    Should Not Contain      ${pods}      ContainerCreating