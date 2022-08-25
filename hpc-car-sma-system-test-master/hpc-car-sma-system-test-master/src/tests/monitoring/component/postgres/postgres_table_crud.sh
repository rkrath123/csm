#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies the ability to create, read, update, and delete tables"
    echo "$0 > sma_component_postgres_table_crud-\`date +%Y%m%d.%H%M\`"
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

#####################################
# Test Case: Create, Modify, and Drop Table in SMA Schema
#  Create a test table in the sma schema
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)

kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "CREATE TABLE sma.test(test_id serial PRIMARY KEY, test_value VARCHAR (255) UNIQUE NOT NULL);"
testtable=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -t -c "\\dt sma.*" | grep test | awk '{print $3}')
if [[ $testtable="test" ]]; then
    echo "Test table created as expected"; else
    errs=$((errs+1))
    failures+=("Postgres Table Creation - test table not created")
fi

#   Modify the test table in the SMA schema and confirm that the change took effect
kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -c "ALTER TABLE sma.test ADD COLUMN testcolumn VARCHAR (255);"
column=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -c "\\d+ sma.test;" | grep testcolumn | awk '{print $1}')
if [[ $column="testcolumn" ]]; then
    echo "Test table modified as expected"; else
    errs=$((errs+1))
    failures+=("Postgres Table Creation - test table not modified")
fi

#   Delete the test table from the sma schema and verify it does not exist.
kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -c "DROP TABLE sma.test"
testtable=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -c "\\dt sma.*" | grep test | awk '{print $3}')
if [[ ! $testtable ]]; then
    echo "Test table deleted as expected"; else
    errs=$((errs+1))
    failures+=("Postgres Table Deletion - test table not deleted")
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
echo "Postgres tables can be created, read, modified, and deleted"

exit 0