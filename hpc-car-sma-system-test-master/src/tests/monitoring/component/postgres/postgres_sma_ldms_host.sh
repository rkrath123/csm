#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the sma ldms_host table is formatted correctly, indicating that"
    echo "initialization happened as expected."
    echo "$0 > sma_component_postgres_sma_ldms_host-\`date +%Y%m%d.%H%M\`"
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

#######################################
# Test Case: sma ldms_host Table is formatted
#   Confirm that the sma schema's ldms_host table exists, and has been formatted with the expected schema.
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)
columns=$(kubectl -n sma exec -t sma-postgres-cluster-0 -- bash -c "psql sma -U postgres -c 'select * from sma.ldms_host limit 0'")
if [[ $columns == *"hostname"* ]]; then
    echo "sma.ldms_host exists, and has been formatted"; else
    errs=$((errs+1))
    failures+=("sma.ldms_host schema missing or incorrect")
fi

#######################################
# Test Case: sma ldms_host Table is populated
#   Confirm that the sma schema's cabinet controller data table has been populated with data.
#   Fetching sma ldms_host row counts from the replica pod...
rows=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "SELECT COUNT(*) FROM sma.ldms_host")
if [[ $rows>0 ]]; then
    echo "sma.ldms_host table is populated"; else
    errs=$((errs+1))
    failures+=("sma.ldms_host table is unpopulated")
fi

######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo  "Postgres cluster is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Postgres sma.ldms_host table is formatted"

exit 0