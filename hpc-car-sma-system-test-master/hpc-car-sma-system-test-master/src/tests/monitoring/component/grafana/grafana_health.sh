#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Grafana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that grafana self-reports a healthy state."
    echo "$0 > sma_component_grafana_health-\`date +%Y%m%d.%H%M\`"
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

###############################
# Test case: Grafana Health
#  	Confirm that Grafana self-reports a healthy state.
#  	To run API we need to get bearer token and then run API using bearer token header.
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
prefix="cmn."
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)

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
echo "Grafana health OK"

exit 0