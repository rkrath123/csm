#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the ability to create, read, update, and delete views."
    echo "$0 > sma_component_postgres_view_crud-\`date +%Y%m%d.%H%M\`"
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

######################################
# Test Case: Create and Delete Test View in SMA Schema
#   Create a new view called "test" in the sma postgreSQL schema and confirm it exists
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)

kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -c "CREATE VIEW sma.test AS SELECT measurementtypeid, measurementunits FROM sma.measurementsource;"
testview=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "\\dv sma.*" | grep test | awk '{print $3}')
if [[ $testview="test" ]]; then
    echo "Test view created as expected"; else
    errs=$((errs+1))
    failures+=("Postgres View Creation - test view not created")
fi

#   Delete the recently created "test" view from the sma schema and confirm it no longer exists
kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -c "DROP VIEW sma.test;"
testview=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "\\dv sma.*" | grep test | awk '{print $3}')
if [[ ! $testview ]]; then
    echo "Test view deleted as expected"; else
    errs=$((errs+1))
    failures+=("Postgres View Deletion - test view not deleted")
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
echo "Postgres view creation and deletion successful"

exit 0