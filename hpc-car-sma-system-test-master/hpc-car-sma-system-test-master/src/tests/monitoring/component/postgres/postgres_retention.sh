#!/bin/bash
# Copyright 2022 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Shows the retention policy."
    echo "$0 > sma_component_postgres_retention-\`date +%Y%m%d.%H%M\`"
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


########################################
# Test case: Postgres retention period
retention=$(kubectl -n sma describe cm postgres-config |awk '/pg_retention:/{getline; getline; print}')
echo "Postgres retention period: $retention"
