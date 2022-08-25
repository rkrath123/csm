#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application"
    echo "Verifies that the expected views exist."
    echo "$0 > sma_component_postgres_views-\`date +%Y%m%d.%H%M\`"
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
# Test case: Postgres SMA Views Exist
declare -a views
#   Confirm that the sma schema and it's expected tables exist.
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)

for i in $(kubectl -n sma exec -t $postgrespod -c postgres -- psql -t sma -U postgres -c "\\dv sma.*" | awk '{print $3}');
    do views+=($i);
    echo "sma view "$i" exists";
done

if [[ ! " ${views[@]} " =~ "clusterstor_status_view" ]]; then
    echo "clusterstor_status_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - clusterstor_status_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_calc_grafana_view" ]]; then
    echo "jobstats_calc_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_calc_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_calc_view" ]]; then
    echo "jobstats_calc_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_calc_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_device_grafana_view" ]]; then
    echo "jobstats_device_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_device_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_device_view" ]]; then
    echo "jobstats_device_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_device_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_jobcnt_grafana_view" ]]; then
    echo "jobstats_jobcnt_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_jobcnt_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_jobcnt_view" ]]; then
    echo "jobstats_jobcnt_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_jobcnt_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_score_grafana_view" ]]; then
    echo "jobstats_score_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_score_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_score_view" ]]; then
    echo "jobstats_score_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_score_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_view" ]]; then
    echo "jobstats_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_iostat_grafana_view" ]]; then
    echo "ldms_iostat_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_iostat_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_iostat_view" ]]; then
    echo "ldms_iostat_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_iostat_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_view" ]]; then
    echo "ldms_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_vmstat_grafana_view" ]]; then
    echo "ldms_vmstat_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_vmstat_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_vmstat_view" ]]; then
    echo "ldms_vmstat_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_vmstat_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_linux_grafana_view" ]]; then
    echo "seastream_linux_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_linux_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_linux_view" ]]; then
    echo "seastream_linux_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_linux_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_lustre_calc_grafana_view" ]]; then
    echo "seastream_lustre_calc_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_lustre_calc_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_lustre_calc_view" ]]; then
    echo "seastream_lustre_calc_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_lustre_calc_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_lustre_grafana_view" ]]; then
    echo "seastream_lustre_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_lustre_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_lustre_view" ]]; then
    echo "seastream_lustre_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_lustre_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_view" ]]; then
    echo "seastream_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_view is missing")
fi

unset views

#########################################
# Test case: Postgres pmdb Views Exist
declare -a views
#   Confirm that the pmdb schema and it's expected tables exist.
#   Return the master postgres pod
postgrespod=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o=custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role | grep master | cut -d " " -f 1)

for i in $(kubectl -n sma exec -t $postgrespod -c postgres -- psql -t sma -U postgres -c "\\dv sma.*" | awk '{print $3}');
    do views+=($i);
    echo "sma view "$i" exists";
done

if [[ ! " ${views[@]} " =~ "clusterstor_status_view" ]]; then
    echo "clusterstor_status_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - clusterstor_status_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_calc_grafana_view" ]]; then
    echo "jobstats_calc_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_calc_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_calc_view" ]]; then
    echo "jobstats_calc_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_calc_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_device_grafana_view" ]]; then
    echo "jobstats_device_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_device_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_device_view" ]]; then
    echo "jobstats_device_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_device_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_jobcnt_grafana_view" ]]; then
    echo "jobstats_jobcnt_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_jobcnt_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_jobcnt_view" ]]; then
    echo "jobstats_jobcnt_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_jobcnt_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_score_grafana_view" ]]; then
    echo "jobstats_score_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_score_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_score_view" ]]; then
    echo "jobstats_score_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_score_view is missing")
fi

if [[ ! " ${views[@]} " =~ "jobstats_view" ]]; then
    echo "jobstats_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - jobstats_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_iostat_grafana_view" ]]; then
    echo "ldms_iostat_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_iostat_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_iostat_view" ]]; then
    echo "ldms_iostat_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_iostat_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_view" ]]; then
    echo "ldms_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_vmstat_grafana_view" ]]; then
    echo "ldms_vmstat_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_vmstat_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "ldms_vmstat_view" ]]; then
    echo "ldms_vmstat_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - ldms_vmstat_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_linux_grafana_view" ]]; then
    echo "seastream_linux_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_linux_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_linux_view" ]]; then
    echo "seastream_linux_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_linux_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_lustre_calc_grafana_view" ]]; then
    echo "seastream_lustre_calc_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_lustre_calc_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_lustre_calc_view" ]]; then
    echo "seastream_lustre_calc_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_lustre_calc_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_lustre_grafana_view" ]]; then
    echo "seastream_lustre_grafana_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_lustre_grafana_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_lustre_view" ]]; then
    echo "seastream_lustre_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_lustre_view is missing")
fi

if [[ ! " ${views[@]} " =~ "seastream_view" ]]; then
    echo "seastream_view is missing"
    errs=$((errs+1))
    failures+=("Postgres Views - seastream_view is missing")
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
echo "Postgres views look good"

exit 0