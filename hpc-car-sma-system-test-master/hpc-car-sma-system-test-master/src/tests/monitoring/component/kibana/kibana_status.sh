#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kibana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that Kibana reports being healthy."
    echo "$0 > sma_component_kibana_status-\`date +%Y%m%d.%H%M\`"
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
# Test case: Kibana Status
#       Confirm that Kibana reports being healthy.
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.cmn.$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)

health=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -ksS -H "Authorization: Bearer $accesstoken" -XGET https://sma-kibana.cmn.$domain/api/status?pretty=true --resolve sma-kibana.cmn.$domain:443:$CIP | json_pp -json_opt pretty,canonical |grep nickname |cut -d '"' -f 4)
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
echo "Kibana Health OK"

exit 0