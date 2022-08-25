#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the SMA user exists."
    echo "$0 > sma_component_postgres_user-\`date +%Y%m%d.%H%M\`"
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

########################################
# Test case: Postgres SMA User Exists
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)
#  	Log in as default postgres user and confirm that the sma_user exists
smauser=$(kubectl -n sma exec -t $postgrespod -c postgres -- psql sma -U postgres -c "\\du" | grep smauser | awk '{print $1}')

if [[ $smauser="smauser" ]]; then
    echo "sma user exists"; else
    errs=$((errs+1))
    failures+=("Postgres sma user - smauser does not exist")
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
echo "Postgres sma user exists"

exit 0