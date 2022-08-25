#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

postgres_dump="${BINPATH}/sma_postgres_dump.sh"

function usage()
{
    echo "usage: $0"
    echo
    echo "This command checks if the SMA postgres cluster appears healthy."
    echo "$0 [-v] > sma_POSTGRES_HEALTH-\`date +%Y%m%d.%H%M\`"
    echo
    exit 1
}

verbose=false
while getopts vh option
do
    case "${option}"
    in
        v) verbose=true;;
        h) usage;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echoerr "unable to talk to kubectl"
	exit 3
fi

show_shasta_config
echo
kubectl -n sma get pods -owide | grep craysma-postgres-cluster
kubectl -n sma get pods -owide | grep postgres-operator
kubectl -n sma get pods -owide | grep postgres-persister
echo

postgres_pods=( "craysma-postgres-cluster-0" "craysma-postgres-cluster-1" )
leader=$(kubectl -n sma get pod -l application=spilo -L spilo-role -o wide | grep master | awk '{ print $1 }')
leader=$(get_postgres_leader)

if [ "$verbose" = true ] ; then
	echo
	echo "sma tables by size"
	kubectl -n sma exec ${leader} -- psql -U postgres -d sma -t -c "SELECT schema_name, relname, pg_size_pretty(table_size) AS size, table_size FROM ( SELECT pg_catalog.pg_namespace.nspname AS schema_name, relname, pg_relation_size(pg_catalog.pg_class.oid) AS table_size FROM pg_catalog.pg_class JOIN pg_catalog.pg_namespace ON relnamespace = pg_catalog.pg_namespace.oid) t WHERE schema_name NOT LIKE 'pg_%' ORDER BY table_size DESC"
	echo
	echo "pmdb tables by size"
	kubectl -n sma exec ${leader} -- psql -U postgres -d pmdb -t -c "SELECT schema_name, relname, pg_size_pretty(table_size) AS size, table_size FROM ( SELECT pg_catalog.pg_namespace.nspname AS schema_name, relname, pg_relation_size(pg_catalog.pg_class.oid) AS table_size FROM pg_catalog.pg_class JOIN pg_catalog.pg_namespace ON relnamespace = pg_catalog.pg_namespace.oid) t WHERE schema_name NOT LIKE 'pg_%' ORDER BY table_size DESC"

#	wal_size=$(kubectl -n sma exec -it ${leader} -- sh -c "echo 'select * from pg_ls_waldir()' | psql -U postgres | grep rows")
#	wal_size=$(sed 's/(//' <<< $wal_size)
#	wal_size=$(sed 's/)//' <<< $wal_size)
#	echo "WAL size= ${wal_size}"
fi

postgres_persistent_dir="/home/postgres/pgdata"

for pod in "${postgres_pods[@]}"
do
	echo "postgres (${pod}) top memory usage"
	kubectl -n sma exec ${pod} -- sh -c 'COLUMNS=1000 top -o RES -U postgres -c -n 1 -b | grep -v top'

	echo
	echo "postgres (${pod}) top %cpu"
	kubectl -n sma exec ${pod} -- sh -c 'COLUMNS=1000 top -o %CPU -U postgres -c -n 1 -b | grep -v top'

	echo
	${BINPATH}/sma_cgroup_stats.sh ${pod}

	echo
	echo "postgres (${pod}) processes"
	kubectl -n sma exec ${pod} -- sh -c 'ps -e -u postgres -o pid,lstart,comm,args'
done

for pod in "${postgres_pods[@]}"
do
	postgres_data=$(kubectl -n sma exec ${pod} -- df -k ${postgres_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
	echo
	echo "postgres (${pod}) data usage= ${postgres_data}%"
	kubectl -n sma exec ${pod} -- df -h ${postgres_persistent_dir}
	echo
	kubectl -n sma exec ${pod} -- sh -c "cd ${postgres_persistent_dir}/pgroot/data; du -hd 1 | sort -rh"
	echo
done

echo
echo "list of databases"
kubectl -n sma exec ${leader} -- /bin/sh -c "echo '\l+' | psql -U postgres"
db_size=$(kubectl -n sma exec ${leader} -- psql -U postgres -d sma -t -c "select pg_size_pretty( pg_database_size('sma') )")
echo "sma database size= ${db_size}"
db_size=$(kubectl -n sma exec ${leader} -- psql -U postgres -d pmdb -t -c "select pg_size_pretty( pg_database_size('pmdb') )")
echo "pmdb database size= ${db_size}"

echo
kubectl -n sma exec craysma-postgres-cluster-0 -- patronictl -c postgres.yml list
kubectl -n sma exec craysma-postgres-cluster-1 -- patronictl -c postgres.yml list

err=0

echo
kubectl -n sma get pod -l application=spilo -L spilo-role -o wide | grep master
if [ $? -ne 0 ]; then
	echo
	echoerr "Postgres cluster is not healthy - master not found"
	err=$((err+1))
fi

kubectl -n sma get pod -l application=spilo -L spilo-role -o wide | grep replica
if [ $? -ne 0 ]; then
	echo
	echoerr "Postgres cluster is not healthy - replica not found"
	err=$((err+1))
fi

if [ "$verbose" = true ] ; then
	echo
	${postgres_dump}
fi

if [ "$err" -eq 0 ]; then
	echo
	echo "Postgres cluster looks healthy"
fi

exit ${errs}

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
