#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies that an index and document can be added and deleted"
    echo "$0 > sma_component_elasticsearch_-\`date +%Y%m%d.%H%M\`"
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

######################
#Test Case: Add Elasticsearch Index
#   Verify the ability to add a test index and confirm that it exists via the REST API.
kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -X PUT "elasticsearch:9200/test?pretty""
testindex=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET "elasticsearch:9200/_cat/indices?h=index" | grep test")
if [ $testindex == "test" ]; then
    echo "Test index created"; else
    echo "Test index creation failure"
    errs=$((errs+1))
    failures+=("Elasticsearch Index Creation - Test index creation failure")
fi

######################
#Test Case: Add Elasticsearch Document
#   Add a document to the test index and verify that it exists.
kubectl -n sma exec -t elasticsearch-master-0 -- curl -sSX PUT "elasticsearch:9200/test/doc/1?pretty" -H 'Content-Type: application/json' -d'{"name": "Seymour Cray" }'
testdoc=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sSI -XGET "elasticsearch:9200/test/doc/1?pretty" | head -n 1 | cut -d ' ' -f 2")
if [ $testdoc == "200" ]; then
    echo "Test document created"; else
    echo "Test document creation failure"
    errs=$((errs+1))
    failures+=("Elasticsearch Document Creation - Test document creation failure")
fi

#####################
#Test Case: Delete Elasticsearch Document
#   Delete a document from the test index and verify that it no longer exists.
kubectl -n sma exec -t elasticsearch-master-0 -- curl -sS -X DELETE "elasticsearch:9200/test/doc/1?pretty"
testdoc=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sSI -XGET "elasticsearch:9200/test/doc/1?pretty" | head -n 1 | cut -d ' ' -f 2")
if [ $testdoc == "404" ]; then
    echo "Test document deleted"; else
    echo "Test document deletion failure"
    errs=$((errs+1))
    failures+=("Elasticsearch Document Deletion - Test document deletion failure")
fi

######################
#Test Case: Delete Elasticsearch Index
#   Delete the test index and verify that it no longer exists.
kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -X DELETE "elasticsearch:9200/test?pretty" "
testindex=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sSI -XGET "elasticsearch:9200/_cat/indices?h=index" | head -n 1 | cut -d ' ' -f 2")
if [ ! $testindex == "404" ]; then
    echo "Test index deleted"; else
    echo "Test index deletion failure"
    errs=$((errs+1))
    failures+=("Elasticsearch Index Deletion - Test index deletion failure")
fi

#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch index and document add and delete successfully"

exit 0