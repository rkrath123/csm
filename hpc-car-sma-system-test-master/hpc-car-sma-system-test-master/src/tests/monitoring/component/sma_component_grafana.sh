#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for the Grafana visualization tool in Cray's Shasta System Monitoring Application."
    echo "$0 > sma_component_grafana-\`date +%Y%m%d.%H%M\`"
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

##############################################
# Test Variables
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
prefix="cmn."
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)

##############################################
# Test case: Grafana Pod Exists
podname=$(kubectl -n services get pods | grep sma-grafana- | awk '{print $1}');
podstatus=$(kubectl -n services --no-headers=true get pod $podname | awk '{print $3}');

if [[ "$podname" =~ "sma-grafana-" ]]; then
  if [[ "$podstatus" =~ "Running" ]]; then
    echo "$podname is Running";
  else
    echo "$podname is $podstatus"
    errs=$((errs+1))
    failures+=("Grafana pod - $podname is $podstatus")
  fi
else
  echo "sma-grafana pod is missing"
  errs=$((errs+1))
  failures+=("Grafana Pod - sma-grafana pod is missing")
fi

#############################
# Test case: Grafana is Running as a K8S Service
service=$(kubectl -n services get svc | grep sma-grafana | awk '{print $1}')
if [[ "$service" =~ "sma-grafana" ]]; then
  echo "$service is available";
else
  echo "sma-grafana service is missing"
  errs=$((errs+1))
  failures+=("Grafana Service - sma-grafana service is missing")
fi

################################
# Test case: Grafana-init Job Completed
initjob=$(kubectl -n services get jobs | grep sma-svc-init | awk '{print $1}');
jobstatus=$(kubectl -n services get jobs | grep sma-svc-init | awk '{print $2}');

if [[ "$initjob" =~ "sma-svc-init" ]]; then
  if [[ "$jobstatus" =~ "1/1" ]]; then
    echo "$initjob Completed";
  else
    echo "$initjob is $jobstatus"
    errs=$((errs+1))
    failures+=("Grafana pod - $initjob is $jobstatus")
  fi
else
  echo "sma-init-job is missing"
  errs=$((errs+1))
  failures+=("Grafana Init Job - sma-svc-init is missing")
fi

###############################
# Test case: Grafana Health
#  	Confirm that Grafana self-reports a healthy state.
#  	To run API we need to get bearer token and then run API using bearer token header.
health=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" https://sma-grafana.$prefix$domain/api/health --resolve sma-grafana.$prefix$domain:443:$CIP | grep database | awk '{print $2}' | cut -d '"' -f 2)
if [[ $health ]]; then
  if [[ "$health" =~ "ok" ]]; then
    echo "Grafana Health OK";
  else
    echo "Grafana health is $health"
    errs=$((errs+1))
    failures+=("Grafana health - health is $health")
  fi
else
  echo "Grafana health report failure"
  errs=$((errs+1))
  failures+=("Grafana Health - report failed")
fi

#############################
# Test case: Grafana Version
#  	Confirm that Grafana's Version is correct.
version=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" https://sma-grafana.$prefix$domain/api/health --resolve sma-grafana.$prefix$domain:443:$CIP | grep version | awk '{print $2}' | cut -d '"' -f 2)
if [[ $version ]]; then
  if [[ "$version" =~ "7.5.13" ]]; then
    echo "Grafana version $version as expected";
  else
    echo "Grafana version $version not expected"
    errs=$((errs+1))
    failures+=("Grafana version - $version not expected")
  fi
else
  echo "Grafana version report failure"
  errs=$((errs+1))
  failures+=("Grafana version - report failed")
fi

#############################
# Test case: Get Users
#  	Log in to Grafana and get users. Confirm session cookie works.
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)
users=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" https://sma-grafana.$prefix$domain/api/users --resolve sma-grafana.$prefix$domain:443:$CIP | grep "admin")
if [[ $users ]]; then
    echo "Expected user found";
else
  echo "Grafana user report failure"
  errs=$((errs+1))
  failures+=("Grafana users - report failed")
fi

#############################
# Test case: Check Datasources
#  	List the grafana datasources and confirm expected content exists.
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)
datasources=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" https://sma-grafana.$prefix$domain/api/datasources --resolve sma-grafana.$prefix$domain:443:$CIP | grep "PMDBPostgres")
if [[ $datasources ]]; then
    echo "Expected datasource found";
else
  echo "Grafana PMDBPostgres datasource not found"
  errs=$((errs+1))
  failures+=("Grafana datasource - PMDBPostgres not found")
fi

#############################
# Test case: Check Expected Dashboards
#   Confirm that expected dashboards exist.
declare -a dash

clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)
for i in $(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" https://sma-grafana.$prefix$domain/api/search --resolve sma-grafana.$prefix$domain:443:$CIP | json_pp -json_opt pretty,canonical | grep title | cut -d '"' -f 4 | tr ' ' '_');
    do dash+=($i);
    echo "Grafana dashboard "$i" exists";
done

if [[ ! " ${dash[@]} " =~ "System" ]]; then
    echo "System dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - System dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Cabinet_Controller_Sensors" ]]; then
    echo "Cabinet Controller Sensors dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Cabinet Controller Sensors dashboard is missing")
fi

#if [[ ! " ${dash[@]} " =~ "ClusterStor_Server_Metrics" ]]; then
#    echo "ClusterStor Server Metrics dashboard is missing"
#    errs=$((errs+1))
#    failures+=("Postgres dashboards - ClusterStor Server Metrics dashboard is missing")
#fi

#if [[ ! " ${dash[@]} " =~ "ClusterStor_Storage_Overview" ]]; then
#    echo "ClusterStor Storage Overview dashboard is missing"
#    errs=$((errs+1))
#    failures+=("Postgres dashboards - ClusterStor Storage Overview dashboard is missing")
#fi

if [[ ! " ${dash[@]} " =~ "Fabric_Congestion" ]]; then
    echo "Fabric Congestion dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Fabric Congestion dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Fabric_Errors" ]]; then
    echo "Fabric Errors dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Fabric Errors dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Fabric_Port_State" ]]; then
    echo "Fabric Port State dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Fabric Port State dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Fabric_RFC3635" ]]; then
    echo "Fabric RFC3635 dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Fabric RFC3635 dashboard is missing")
fi

#if [[ ! " ${dash[@]} " =~ "Job_Details" ]]; then
#    echo "Job Details dashboard is missing"
#    errs=$((errs+1))
#    failures+=("Postgres dashboards - Job Details dashboard is missing")
#fi

#if [[ ! " ${dash[@]} " =~ "Lustre_File_System_Capacity" ]]; then
#    echo "Lustre File System Capacity dashboard is missing"
#    errs=$((errs+1))
#    failures+=("Postgres dashboards - Lustre File System Capacity dashboard is missing")
#fi

#if [[ ! " ${dash[@]} " =~ "Lustre_File_System_Metadata" ]]; then
#    echo "Lustre File System Metadata dashboard is missing"
#    errs=$((errs+1))
#    failures+=("Postgres dashboards - Lustre File System Metadata dashboard is missing")
#fi

#if [[ ! " ${dash[@]} " =~ "Lustre_File_System_Performance" ]]; then
#    echo "Lustre File System Performance dashboard is missing"
#    errs=$((errs+1))
#    failures+=("Postgres dashboards - Lustre File System Performance dashboard is missing")
#fi

if [[ ! " ${dash[@]} " =~ "Node_Controller_Sensors" ]]; then
    echo "Node Controller Sensors dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Node Controller Sensors dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Overview_Details" ]]; then
    echo "Overview Details dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Overview Details dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Overview_Device_I/O_Stats" ]]; then
    echo "Overview Device I/O Stats dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Overview Device I/O Stats dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Overview_Mellanox_Host_Details" ]]; then
    echo "Overview Mellanox Host Details dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Overview Mellanox Host Details dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Redfish_Events" ]]; then
    echo "Redfish Events dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Redfish Events dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "River_Sensors" ]]; then
    echo "River Sensors dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - River Sensors dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "Switch_Controller_Sensors" ]]; then
    echo "Switch Controller Sensors dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - Switch Controller Sensors dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "System_CPU" ]]; then
    echo "System CPU dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - System CPU dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "System_I/O" ]]; then
    echo "System I/O dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - System I/O dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "System_Kernel_Attributes" ]]; then
    echo "System Kernel Attributes dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - System Kernel Attributes dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "System_Memory" ]]; then
    echo "System Memory dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - System Memory dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "System_Processes" ]]; then
    echo "System Processes dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - System Processes dashboard is missing")
fi

if [[ ! " ${dash[@]} " =~ "System_Swap" ]]; then
    echo "System Swap dashboard is missing"
    errs=$((errs+1))
    failures+=("Postgres dashboards - System Swap dashboard is missing")
fi

unset dash

#############################
# Test case: Add Datasource via API
#  	Add a datasource to Grafana and confirm it exists.
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)

addds=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" -X POST -H "Content-Type: application/json" -d '{"name": "test","url": "postgres:5432","access": "proxy", "isDefault": false, "type": "postgres","database": "pmdb","user": "pmdbuser","password": ""}' https://sma-grafana.$prefix$domain/api/datasources --resolve sma-grafana.$prefix$domain:443:$CIP | jq | grep message | cut -d '"' -f 4)
if [[ "$addds" =~ "Datasource added" ]]; then
  echo "Grafana test datasource added"
  isadded=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer ${accesstoken}" https://sma-grafana.$prefix$domain/api/datasources/name/test --resolve sma-grafana.$prefix$domain:443:$CIP|grep "postgres:5432")
  if [[ ! " $isadded " ]]; then
    echo "Grafana test datasource failed match"
    errs=$((errs+1))
    failures+=("Grafana datasource add - test datasource match failed")
  fi
else
  echo "Grafana datasource add failed"
  errs=$((errs+1))
  failures+=("Grafana Add Datasource - add failed")
fi

#############################
# Test case: Update Datasource via API
#  	Update a datasource and confirm the changes were applied.
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)
datasourceid=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" https://sma-grafana.$prefix$domain/api/datasources/name/test --resolve sma-grafana.$prefix$domain:443:$CIP | cut -d ':' -f 2 | cut -d ',' -f 1)

updateds=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" -X PUT -H "Content-Type: application/json" -d '{"name": "test","url": "updated:5432","access": "proxy", "isDefault": false, "type": "postgres","database": "pmdb","user": "pmdbuser","password": ""}' https://sma-grafana.$prefix$domain/api/datasources/$datasourceid --resolve sma-grafana.$prefix$domain:443:$CIP)
if [[ "$updateds" =~ "Datasource updated" ]]; then
  echo "Grafana test datasource updated"
  isupdated=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer ${accesstoken}" https://sma-grafana.$prefix$domain/api/datasources/name/test --resolve sma-grafana.$prefix$domain:443:$CIP|grep "updated:5432")
  if [[ ! " $isupdated " ]]; then
    echo "Grafana test datasource update failed match"
    errs=$((errs+1))
    failures+=("Grafana datasource update - test datasource match failed")
  fi
else
  echo "Grafana datasource update failed"
  errs=$((errs+1))
  failures+=("Grafana Update Datasource - update failed")
fi

#############################
# Test case: Delete Datasource via API
#  	Delete datasource from Grafana and confirm it no longer exists.
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)
datasourceid=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" https://sma-grafana.$prefix$domain/api/datasources/name/test --resolve sma-grafana.$prefix$domain:443:$CIP | cut -d ':' -f 2 | cut -d ',' -f 1)
deleteds=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" -X DELETE -H "Content-Type: application/json" https://sma-grafana.$prefix$domain/api/datasources/$datasourceid --resolve sma-grafana.$prefix$domain:443:$CIP)
if [[ "$deleteds" =~ "Data source deleted" ]]; then
  echo "Grafana test datasource deleted"
  isdeleted=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" https://sma-grafana.$prefix$domain/api/datasources/)
  if [[ ! " $isdeleted " ]]; then
    echo "Grafana test datasource delete failed match"
    errs=$((errs+1))
    failures+=("Grafana datasource update - test datasource delete match failed")
  fi
else
  echo "Grafana datasource delete failed"
  errs=$((errs+1))
  failures+=("Grafana Update Datasource - delete failed")
fi


######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo "Grafana is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Grafana looks healthy"

exit 0