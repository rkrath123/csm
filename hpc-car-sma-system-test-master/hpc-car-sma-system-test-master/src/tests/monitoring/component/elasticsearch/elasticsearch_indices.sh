#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies that expected Elasticsearch indices exist."
    echo "$0 > sma_component_elasticsearch_indices-\`date +%Y%m%d.%H%M\`"
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
# Test Case: Expected Elasticsearch Indices Exist
#   Confirm that expected Elasticsearch indices exist.
declare -a indices

for i in $(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET "elasticsearch:9200/_cat/indices?h=index"");
    do indices+=($i);
done


if [[ " ${indices[@]} " =~ "elastalert_status" ]]; then
    echo "Index elastalert_status is in the cluster"
else
    echo "Index elastalert_status is not found in the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Index - elastalert_status not in cluster")
fi

if [[ " ${indices[@]} " =~ ".kibana_1" ]]; then
    echo "Index .kibana_1 is in the cluster"
else
    echo "Index .kibana_1 is not found in the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Index - .kibana_1 not in cluster")
fi

if [[ " ${indices[@]} " =~ "shasta-logs-" ]]; then
    echo "Index shasta-logs- is in the cluster"
else
    echo "Index shasta-logs- is not found in the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Index - shasta-logs- not in cluster")
fi

unset indices

#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch indices look good"

exit 0