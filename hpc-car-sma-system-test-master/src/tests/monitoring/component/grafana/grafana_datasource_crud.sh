#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Grafana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that a grafana datasource can be created, read, modified, and deleted."
    echo "$0 > sma_component_grafana_datasource_crud-\`date +%Y%m%d.%H%M\`"
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


clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
prefix="cmn."
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)

#############################
# Test case: Add Datasource via API
#  	Add a datasource to Grafana and confirm it exists.

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
echo "Grafana datasource CRUD successful"

exit 0