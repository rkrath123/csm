#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for the Kibana visualization tool in Cray's Shasta System Monitoring Application."
    echo "The test focuses on verification of a valid environment and CRUD functionality of index-patterns, visualizations,"
    echo "and dashboards."
    echo "$0 > sma_component_kibana-\`date +%Y%m%d.%H%M\`"
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

#############################################
# Test Variables

clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
prefix="cmn."
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)


##############################################
# Test case: Kibana Pod Exists in SMA Namespace
podname=$(kubectl -n services get pods | grep sma-kibana- | awk '{print $1}');
podstatus=$(kubectl -n services --no-headers=true get pod $podname | awk '{print $3}');

if [[ "$podname" =~ "sma-kibana-" ]]; then
  if [[ "$podstatus" =~ "Running" ]]; then
    echo "$podname is Running";
  else
    echo "$podname is $podstatus"
    errs=$((errs+1))
    failures+=("Kibana pod - $podname is $podstatus")
  fi
else
  echo "sma-kibana pod is missing"
  errs=$((errs+1))
  failures+=("Kibana Pod - sma-kibana pod is missing")
fi

################################################
# Test case: Kibana is Running as a K8S Service
service=$(kubectl -n services get svc | grep sma-kibana | awk '{print $1}')
if [[ "$service" =~ "sma-kibana" ]]; then
  echo "$service is available";
else
  echo "sma-kibana service is missing"
  errs=$((errs+1))
  failures+=("Kibana Service - sma-kibana service is missing")
fi

##############################################
# Test case: Kibana Status
#       Confirm that Kibana reports being healthy.

health=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -ksS -H "Authorization: Bearer $accesstoken" -XGET https://sma-kibana.$prefix$domain/api/status?pretty=true --resolve sma-kibana.$prefix$domain:443:$CIP | json_pp -json_opt pretty,canonical |grep nickname |cut -d '"' -f 4)
if [[ $health ]]; then
  if [[ "$health" =~ "Looking good" ]]; then
    echo "Kibana Health OK";
  else
    echo "Kibana health is $health"
    errs=$((errs+1))
    failures+=("Kibana health - health is $health")
  fi
else
  echo "Kibana health report failure"
  errs=$((errs+1))
  failures+=("Kibana Health - report failed")
fi

##############################################
# Test case: Create a Kibana Index-Pattern
#       Kibana index-patterns can be created via API.

addkip=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" -X POST https://sma-kibana.$prefix$domain/api/saved_objects/index-pattern/test-pattern -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d '{"attributes": {"title": "test-pattern-title"}}' --resolve sma-kibana.$prefix$domain:443:$CIP | json_pp -json_opt pretty,canonical |grep title |cut -d '"' -f 4)
if [[ "$addkip" =~ "test-pattern-title" ]]; then
  echo "Kibana test Index-Pattern added"
else
  echo "Kibana Index-Pattern add failed"
  errs=$((errs+1))
  failures+=("Kibana Add Index-Pattern - add failed")
fi

#############################################
# Test case: Modify a Kibana Index-Pattern and Confirm
#       Kibana index-patterns can be modified and retrieved via API.

modkip=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" -X PUT -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d '{"attributes": {"title": "test-pattern-changed"}}' https://sma-kibana.$prefix$domain/api/saved_objects/index-pattern/test-pattern --resolve sma-kibana.$prefix$domain:443:$CIP | json_pp -json_opt pretty,canonical |grep title |cut -d '"' -f 4)
if [[ "$modkip" =~ "test-pattern-changed" ]]; then
  echo "Kibana test Index-Pattern modified"
else
  echo "Kibana Index-Pattern modify failed"
  errs=$((errs+1))
  failures+=("Kibana Modify Index-Pattern - modify failed")
fi

############################################
# Test case: Delete a Kibana Index-Pattern
#       Kibana index-patterns can be deleted via API.

delkip=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -H "Authorization: Bearer $accesstoken" -X DELETE https://sma-kibana.$prefix$domain/api/saved_objects/index-pattern/test-pattern -H 'kbn-xsrf: true' -H 'Content-Type: application/json' --resolve sma-kibana.$prefix$domain:443:$CIP)
if [[ $delkip ]]; then
  echo "Kibana test Index-Pattern deleted"
else
  echo "Kibana Index-Pattern delete failed"
  errs=$((errs+1))
  failures+=("Kibana Delete Index-Pattern - delete failed")
fi

######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo  "Kibana is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"

	exit 1
fi

echo
echo "Kibana looks healthy"

exit 0