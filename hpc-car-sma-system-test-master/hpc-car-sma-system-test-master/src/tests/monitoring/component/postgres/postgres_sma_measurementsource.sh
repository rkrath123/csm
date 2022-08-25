#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the measurementsource table is populated with the expected number of rows, indicating both that"
    echo "initialization happened as expected, and that postgres queries are working."
    echo "$0 > sma_component_postgres_measurementsource-\`date +%Y%m%d.%H%M\`"
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
# Test Case: SMA measurementsource Table is Populated
#   Confirm that the sma schema's measurementsource table has been populated with data.
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)
#   Fetching measurementsource row counts from the replica pod...
rows=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "SELECT COUNT(*) FROM sma.measurementsource")
if [[ $rows=191 ]]; then
    echo "Measurementsource row count is $rows as expected"; else
    errs=$((errs+1))
    failures+=("Postgres measurementsource - row count $rows unexpected")
fi

storagerows=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "SELECT COUNT(*) FROM sma.measurementsource WHERE measurementname LIKE 'cray_storage.%'")
if [[ $storagerows=108 ]]; then
    echo "Measurementsource storage row count is $storagerows as expected"; else
    errs=$((errs+1))
    failures+=("Postgres measurementsource - storage row count $storagerows unexpected")
fi

jobrows=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "SELECT COUNT(*) FROM sma.measurementsource WHERE measurementname LIKE 'cray_job.%'")
if [[ $jobrows=72 ]]; then
    echo "Measurementsource job row count is $jobrows as expected"; else
    errs=$((errs+1))
    failures+=("Postgres measurementsource - job row count $jobrows unexpected")
fi

otherrows=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "SELECT COUNT(*) FROM sma.measurementsource WHERE measurementname NOT LIKE 'cray_job.%' AND measurementname NOT LIKE 'cray_storage.%'")
if [[ ! $otherrows=0 ]]; then
    errs=$((errs+1))
    failures+=("Postgres measurementsource - unexpected rows of unknown type")
fi
unset views

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
echo "Postgres measurementsource table is fully populated"

exit 0