#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Grafana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that the expected dashboards exist."
    echo "$0 > sma_component_grafana_dashboards-\`date +%Y%m%d.%H%M\`"
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


#############################
# Test case: Check Expected Dashboards
#   Confirm that expected dashboards exist.
declare -a dash

clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
prefix="cmn."
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
echo "Grafana dashboards look good"

exit 0