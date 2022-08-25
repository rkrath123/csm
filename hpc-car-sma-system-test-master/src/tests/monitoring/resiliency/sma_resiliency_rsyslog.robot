*** Settings ***
Library     OperatingSystem
Library     Process
Force Tags      sms      sma     component

Documentation
...     This is the resiliency test for the Rsyslog service in Cray's Shasta System Monitoring Application.
...     Rsyslog inserts data into the SMA component set by publishing data to Kafka.
...     Rsyslog collectors pull logs from all services running in K8s, and forward these logs to the aggregators.
...     Rsyslog aggregator pods accept messages from rsyslog collectors, as well as from the base operating systems
...     on non-compute nodes and compute nodes; these log messages are injected into Kafka en route to ElasticSearch.
...
...     Each rsyslog aggregator acts independently. In the event that an rsyslog aggregator pod fails, or a server
...     running the rsyslog aggregator pod fails, the rsyslog connection from upstream nodes will be broken.
...     These nodes will reconnect, and the load balancer will assign a new aggregator to each.
...     When the aggregator pod restarts, it will return to the pool of available servers for load balancer selection.
...     Any brief interruption of service encountered by a node sending data to the aggregator is absorbed by internal
...     buffering on the client node.
...
...     Rsyslog collectors are not highly available, but K8S shall be configured to restart a collector on each node,
...     if the running pod fails. Once a new pod is started, it will resume collecting logs from K8S pods on the server.
 ...    Any interruption of service will be absorbed by internal buffering within the Kubernetes log infrastructure.

#   ***********************************************
#   ***********************************************
#
#   THIS IS NOT A VALID RESILIENCY TEST AS-IS
#   IT IS A DRAFT OUTLINE OF A TEST ONLY
#
#   ***********************************************
#   ***********************************************

*** Test Case ***
Rsyslog Configuration
#   Verify that Rsyslog collectors and aggregators are running as K8s services, that they are configured properly, and
#   that they appear to be functional within SMA.
Rsyslog Aggregators Exist on SMS Nodes
#   Change to test multiple pods as appropriate:
    Log To Console      Confirming Rsyslog Collector Pod Exists in SMA Namespace
    ${rsyslogcolp}=     Run    kubectl -n sma get pods | grep rsyslog-collector
    Log To Console  	${rsyslogcolp}
    Should Contain      ${rsyslogcolp}     rsyslog-collector
    Should Contain      ${rsyslogcolp}     Running
    Should Not Contain      ${rsyslogcolp}    CrashLoopBackOff
    Should Not Contain      ${rsyslogcolp}    Failed
    Should Not Contain      ${rsyslogcolp}    Unknown
    Should Not Contain      ${rsyslogcolp}    Pending
    Log To Console      Confirming Rsyslog Aggregator Pod Exists in SMA Namespace
    ${rsyslogaggp}=     Run    kubectl -n sma get pods | grep rsyslog-aggregator
    Log To Console  	${rsyslogaggp}
    Should Contain      ${rsyslogaggp}     rsyslog-aggregator
    Should Contain      ${rsyslogaggp}     Running
    Should Not Contain      ${rsyslogaggp}    CrashLoopBackOff
    Should Not Contain      ${rsyslogaggp}    Failed
    Should Not Contain      ${rsyslogaggp}    Unknown
    Should Not Contain      ${rsyslogaggp}    Pending

#   Useful as-is:
    Log To Console      Confirming Rsyslog Aggregator is Running as a K8S Service
    ${rsyslogaggs}=     Run    kubectl -n sma get svc | grep rsyslog-aggregator-cmn
    Log To Console      ${rsyslogaggs}
    Should Contain      ${rsyslogaggs}     rsyslog-aggregator-cmn
    Should Contain      ${rsyslogaggs}     NodePort
    Log To Console      Confirming Rsyslog Aggregator LB is Running as a K8S Service
    ${rsysloglbs}=      Run    kubectl -n sma get svc | grep rsyslog-aggregator | grep -v cmn
    Log To Console      ${rsysloglbs}
    Should Contain      ${rsysloglbs}     rsyslog-aggregator
    Should Contain      ${rsysloglbs}     LoadBalancer
    Log To Console      Confirming Rsyslog Collector is Running as a K8S Service...
    ${rsyslogcols}=     Run    kubectl -n sma get svc | grep rsyslog-collector
    Log To Console      ${rsyslogcols}
    Should Contain      ${rsyslogcols}     rsyslog-collector



*** Test Case ***
Aggregator Pod Fails
#   Cause the failure of the Rsyslog Aggregator pod, and confirm that it recovers gracefully.
#
#   Confirm rsyslog gathers data from node/pod and publishes it to kafka
#   Disrupt Rsyslog aggregator pod
#   Test if rsyslog gathers data from node/pod and publishes it to kafka
#   Upstream nodes will reconnect, and the load balancer will assign a new aggregator to each.
#   When aggregator pod restarts, it will return to the pool of available servers the load balancer can select.
#   Confirm rsyslog gathers data from node/pod and publishes it to kafka

*** Test Case ***
Collector Pod Fails
#   Cause the failure of the Rsyslog Collector pod, and confirm that it recovers gracefully.
#
#   Confirm rsyslog gathers data from node/pod and publishes it to kafka
#   Disrupt collector pod
#   Test if rsyslog gathers data from node/pod and publishes it to kafka
#   Kubernetes shall be configured to restart an rsyslog collector on each node, should the running pod fail.
#   Once the replacement pod is started, it will resume collecting logs from Kubernetes pods on the server as well as
#   OS data from compute and nmn nodes.
#   Confirm rsyslog gathers data from node/pod and publishes it to kafka


#   The following is from the component test, as an example for fleshing this test out.
*** Keywords ***
Backup Conf
    #   Get the name of sms 1
    ${smsname}=     Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    Log To Console      Backup /etc/rsyslog.conf on sms...
    Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} cp /etc/rsyslog.conf /etc/rsyslog.conf.bak
    ${isbak}=   Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} ls /etc/rsyslog.conf.bak
    Should Contain      ${isbak}    rsyslog.conf.bak

Add Log Forwarding
    #   Get the name of sms 1
    ${smsname}=     Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    Log To Console      Append sma_component_rsyslog.conf to /etc/rsyslog.conf on sms...
    Run     sshpass -p initial0 scp -o StrictHostKeyChecking=no /tests/monitoring/component/sma_component_rsyslog.conf root@${smsname}://root/sma_component_rsyslog.conf
    Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} '''while read line; do echo $line >> /etc/rsyslog.conf; done < /root/sma_component_rsyslog.conf'''
    ${isfwd}=  	Run  	sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} cat /etc/rsyslog.conf | grep 'template="json_data"'
    Should Contain  	${isfwd}  	"json_data"

Set Load Balancer IP
    #   Get the name of sms 1
    ${smsname}=     Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
    Log To Console      Get load balancer ip address assigned to rsyslog-aggregator...
    ${lbip}=    Run     kubectl -n sma get services|grep rsyslog-aggregator|grep Load|awk '{print $4}'
    Log To Console      Load balancer IP = ${lbip}
    Log To Console      Set Load Balancer IP in /etc/rsyslog.conf on sms
    ${sed}=  	Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} sed -i 's/IP_ADDRESS/${lbip}/g' /etc/rsyslog.conf
  	Log To Console  	${sed}

#*** Test Case ***
#Rsyslog Collects SMS Log
#   #   Get the name of sms 1
#   ${smsname}=     Run     kubectl -n sma get nodes | grep master| cut -d ' ' -f 1 | grep 1
#   ${logfwd}=      Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} cat /etc/rsyslog.conf | grep 'template="json_data"'
#   Run Keyword If      '${logfwd}'=='template="json_data"'     Set Suite Variable    ${logfwd}      True
#   Run Keyword If      '${logfwd}'=='True'     Log To Console      SMS Log Forwarding Already Configured
#   Run Keyword Unless      '${logfwd}'=='True'     Backup Conf
#   Run Keyword Unless      '${logfwd}'=='True'     Add Log Forwarding
#   Run Keyword Unless      '${logfwd}'=='True'     Set Load Balancer IP
#   Run Keyword Unless      '${logfwd}'=='True'     Log To Console      Restarting rsyslog services
#   Run Keyword Unless      '${logfwd}'=='True'     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} systemctl restart rsyslog
#   #   wait until rsyslog is active (running)
#   Log To Console  	Waiting for rsyslog...
#   FOR     ${index}        IN RANGE        5
#       Sleep   2
#       ${status}=     Run    sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} systemctl status rsyslog
#       Exit For Loop If    "active (running)" in """${status}"""
#       Run Keyword If      '${index}' == '5'       Fail    rsyslog not active 10 seconds after restart
#   END
#   Log To Console      Sending Log Message...
#   ${time}=    Run     date +%s
#   Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} logger "smstest_${time}"
#   Log To Console      Checking for data
#   Log To Console          Waiting for data to be persisted...
#   Sleep   10
#   ${search}=      Run     curl -X GET "elasticsearch:9200/_search?q=smstest_${time}"
#   Log To Console         ${search}
#   Should Not Contain      ${search}   "hits":{"total":0
#   [Teardown]  	Run Keywords  	Run Keyword Unless      '${logfwd}'=='True'     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} cp /etc/rsyslog.conf.bak /etc/rsyslog.conf
#   ...     AND     Run Keyword Unless      '${logfwd}'=='True'     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} rm -f /etc/rsyslog.conf.bak
#   ...     AND     Run Keyword Unless      '${logfwd}'=='True'     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} systemctl restart rsyslog
#   ...     AND     Run Keyword Unless      '${logfwd}'=='True'     Run     sshpass -p initial0 ssh -T -o StrictHostKeyChecking=no root@${smsname} rm -f /root/sma_component_rsyslog.conf