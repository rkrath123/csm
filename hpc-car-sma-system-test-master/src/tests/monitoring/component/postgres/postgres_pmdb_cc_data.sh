#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the pmdb cabinet controller data table is formatted correctly, indicating that"
    echo "initialization happened as expected."
    echo "$0 > sma_component_postgres_pmdb_cc_data-\`date +%Y%m%d.%H%M\`"
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
# Test Case: PMDB cc_data Table is formatted
#   Confirm that the pmdb schema's cc_data table exists, and has been formatted with the expected schema.
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)
columns=$(kubectl -n sma exec -t sma-postgres-cluster-0 -- bash -c "psql pmdb -U postgres -c 'select * from pmdb.cc_data limit 0'")
if [[ $columns == *"location"* ]]; then
    echo "pmdb.cc_data exists, and has been formatted"; else
    errs=$((errs+1))
    failures+=("pmdb.cc_data schema missing or incorrect")
fi

#######################################
# Test Case: PMDB cc_data Table is populated
#   Confirm that the pmdb schema's cabinet controller data table has been populated with data.
#   Fetching PMDB cc_data row counts from the replica pod...
rows=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "SELECT COUNT(*) FROM pmdb.cc_data")
if [[ $rows>0 ]]; then
    echo "pmdb.cc_data table is populated"; else
    errs=$((errs+1))
    failures+=("pmdb.cc_data table is unpopulated")
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
echo "Postgres pmdb.cc_data table is formatted"

exit 0