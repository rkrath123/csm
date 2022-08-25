#!/bin/bash
# set -x

binpath=`dirname "$0"`
. $binpath/sma_tools

interval="5 min"
since="(NOW() - INTERVAL '$interval')"

sma_data_tables=( "ldms_data" "seastream_data" "jobstats_data" )
meta_tables=( "ldms_device" "ldms_host" "seastream_device" "seastream_host" "measurementfull" "measurementsource" )
ldms_views=( "ldms_view" "ldms_iostat_view" "ldms_vmstat_grafana_view" "ldms_iostat_grafana_view")
seastream_views=( "seastream_view" "seastream_lustre_view" "seastream_lustre_calc_view" "seastream_linux_view" )
sma_data_tables+=( "${ldms_views[@]}" "${seastream_views[@]}" )

pm_data_tables=( "cc_data" "fabric_crit_data" "fabric_data" "fabric_perf_data" "river_data" "sc_data" )
pm_views=( "cc_view" "fabric_crit_view" "fabric_perf_view" "fabric_view" "nc_view" "river_view" "sc_view" )
pm_data_tables+=( "${pm_views[@]}" )

sma_errs=0
pm_errs=0
postgres_pod=$(get_postgres_leader)

kubectl -n sma exec ${postgres_pod} -t -- /bin/sh -c "echo '\dt sma.*' | psql -d sma -U postgres"
if [ $? -ne 0 ]; then
	sma_errs=$((sma_errs+1))
fi

echo
kubectl -n sma exec ${postgres_pod} -t -- /bin/sh -c "echo '\dv sma.*' | psql -d sma -U postgres"
if [ $? -ne 0 ]; then
	sma_errs=$((sma_errs+1))
fi

if [ "$sma_errs" -eq 0 ]; then
	echo
	kubectl -n sma exec ${postgres_pod} -t -- /bin/sh -c "echo '\d+ sma.*' | psql -d sma -U postgres"
fi

echo
kubectl -n sma exec ${postgres_pod} -t -- /bin/sh -c "echo '\dt pmdb.*' | psql -d pmdb -U postgres"
if [ $? -ne 0 ]; then
	pm_errs=$((sma_errs+1))
fi

echo
kubectl -n sma exec ${postgres_pod} -t -- /bin/sh -c "echo '\dv pmdb.*' | psql -d pmdb -U postgres"
if [ $? -ne 0 ]; then
	pm_errs=$((sma_errs+1))
fi

if [ "$pm_errs" -eq 0 ]; then
	echo
	kubectl -n sma exec ${postgres_pod} -t -- /bin/sh -c "echo '\d+ pmdb.*' | psql -d pmdb -U postgres"
fi

echo
echo "Table row counts.  If zero(0) no metrics were found in last '$interval'"

if [ "$sma_errs" -eq 0 ]; then
	echo
	for table in "${sma_data_tables[@]}"
	do
		count=$(kubectl -n sma exec ${postgres_pod} -- psql -U postgres -d sma -t -c "select count(*) from sma.$table where ts >= $since")
		echo $table: $count

#		oldest=$(kubectl -n sma exec ${postgres_pod} -- psql -U postgres -d sma -t -c "select * from sma.$table limit 1")
#		oldest=$(echo ${oldest} | awk '{ print $1 " " $2 }')
#		echo
#		kubectl -n sma exec ${postgres_pod} -- psql -U postgres -d sma -c "select * from sma.$table limit 5"
	done
fi

if [ "$pm_errs" -eq 0 ]; then
	echo
	for table in "${pm_data_tables[@]}"
	do
		count=$(kubectl -n sma exec ${postgres_pod} -- psql -U postgres -d pmdb -t -c "select count(*) from pmdb.$table where timestamp >= $since")
		echo $table: $count

#		oldest=$(kubectl -n sma exec ${postgres_pod} -- psql -U postgres -d pmdb -t -c "select * from pmdb.$table limit 1")
#		oldest=$(echo ${oldest} | awk '{ print $1 " " $2 }')
#		echo
#		kubectl -n sma exec ${postgres_pod} -- psql -U postgres -d pmdb -c "select * from pmdb.$table limit 5"
	done
fi

echo
for table in "${meta_tables[@]}"
do
	count=$(kubectl -n sma exec ${postgres_pod} -- psql -U postgres -d sma -t -c "select count(*) from sma.$table")
	echo $table: $count
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
