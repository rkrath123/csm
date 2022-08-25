#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Grafana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that the version is correct."
    echo "$0 > sma_component_grafana_version-\`date +%Y%m%d.%H%M\`"
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
# Test case: Grafana Version
#  	Confirm that Grafana's Version is correct.
clientsecret=$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)
prefix="cmn."
domain=$(kubectl get secret site-init -n loftsman -o jsonpath='{.data.customizations\.yaml}' | base64 -d | grep external: | awk '{print $2}')
CIP=$(kubectl get svc -A|grep -w "istio-ingressgateway"|awk '{print $4}'|head -1)
accesstoken=$(kubectl -n sma exec -t cluster-kafka-0 -c kafka -- curl -sSk -d grant_type=client_credentials -d client_id=admin-client -d client_secret=$clientsecret https://auth.$prefix$domain/keycloak/realms/shasta/protocol/openid-connect/token | cut -d '"' -f 4)

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

######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo "Grafana version unexpected"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Grafana version looks good"

exit 0