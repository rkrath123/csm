#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the correct schema version is installed"
    echo "$0 > sma_component_postgres_schema-\`date +%Y%m%d.%H%M\`"
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
# Test case: Postgres SMA Schema Version
#   Confirm that the sma schema version has the correct, major, minor, and gen number
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)

major=$(kubectl -n sma exec -t $postgrespod -c postgres -- psql -t sma -U postgres -c "SELECT major_num FROM sma.version WHERE component_name='DB_SCHEMA';")
minor=$(kubectl -n sma exec -t $postgrespod -c postgres -- psql -t sma -U postgres -c "SELECT minor_num FROM sma.version WHERE component_name='DB_SCHEMA';")
gen=$(kubectl -n sma exec -t $postgrespod -c postgres -- psql -t sma -U postgres -c "SELECT gen_num FROM sma.version WHERE component_name='DB_SCHEMA';")
version=$(echo $major"."$minor"."$gen)
if [[ ! $version = "2. 2. 3" ]]; then
    echo "incorrect postgres sma schema version $version"
    errs=$((errs+1))
    failures+=("Postgres SMA Schema - Incorrect Version $version"); else
    echo "postgres sma schema version is $version as expected"
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
echo "Postgres schema version is correct"

exit 0