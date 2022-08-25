#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the expected tables exist."
    echo "$0 > sma_component_postgres_tables-\`date +%Y%m%d.%H%M\`"
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


#########################################
# Test case: Postgres SMA Schema and Tables Exist
declare -a tables
#   Confirm that the sma schema and it's expected tables exist.
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)

for i in $(kubectl -n sma exec -t $postgrespod -c postgres -- psql -t sma -U postgres -c "\\dt sma.*" | awk '{print $3}');
    do tables+=($i);
    echo "sma table "$i" exists";
done

if [[ ! " ${tables[@]} " =~ "jobstats_data" ]]; then
    echo "jobstats_data table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - jobstats_data is missing")
fi

if [[ ! " ${tables[@]} " =~ "ldms_data" ]]; then
    echo "ldms_data table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - ldms_data is missing")
fi

if [[ ! " ${tables[@]} " =~ "ldms_device" ]]; then
    echo "ldms_device table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - ldms_device is missing")
fi

if [[ ! " ${tables[@]} " =~ "ldms_host" ]]; then
    echo "ldms_host table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - ldms_host is missing")
fi

if [[ ! " ${tables[@]} " =~ "measurementfull" ]]; then
    echo "measurementfull table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - measurementfull is missing")
fi

if [[ ! " ${tables[@]} " =~ "measurementsource" ]]; then
    echo "measurementsource table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - measurementsource is missing")
fi

if [[ ! " ${tables[@]} " =~ "metric_filter" ]]; then
    echo "metric_filter table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - metric_filter is missing")
fi

if [[ ! " ${tables[@]} " =~ "seastream_data" ]]; then
    echo "seastream_data table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - seastream_data is missing")
fi

if [[ ! " ${tables[@]} " =~ "seastream_device" ]]; then
    echo "seastream_device table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - seastream_device is missing")
fi

if [[ ! " ${tables[@]} " =~ "seastream_host" ]]; then
    echo "seastream_host table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - seastream_host is missing")
fi

if [[ ! " ${tables[@]} " =~ "system" ]]; then
    echo "system table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - system is missing")
fi

if [[ ! " ${tables[@]} " =~ "tenant" ]]; then
    echo "tenant table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - tenant is missing")
fi

if [[ ! " ${tables[@]} " =~ "triplets" ]]; then
    echo "triplets table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - triplets is missing")
fi

if [[ ! " ${tables[@]} " =~ "version" ]]; then
    echo "version table is missing"
    errs=$((errs+1))
    failures+=("Postgres Tables - version is missing")
fi
unset tables


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
echo "Postgres tables look good"

exit 0