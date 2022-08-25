#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for the postgreSQL datastore in Cray's Shasta System Monitoring Application."
    echo "The test focuses on verification of a valid environment and initial configuration, and tests the ability to"
    echo "create, modify, and delete views and tables."
    echo "$0 > sma_component_postgres-\`date +%Y%m%d.%H%M\`"
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

##############################################
##############################################
# Test case: Confirm Postgres Pods are Running in SMA Namespace
declare -a pods
declare -A podstatus
declare -A podnode
pg_pods=('sma-postgres-cluster-0' 'sma-postgres-cluster-1')

# get name, status, and the node on which each postgres pod resides
for i in $(kubectl -n sma get pods | grep 'postgres' | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

for pod in "${pg_pods[@]}"
do
# Confirm each pod is Running
if [[ " ${pods[@]} " =~ $pod ]]; then
    if [[ ! " ${podstatus[$pod]} " =~ "Running" ]]; then
    echo "$pod is ${podstatus[$pod]} on ${podnode[$pod]}"
    errs=$((errs+1))
    failures+=("Postgres Pods - $pod ${podstatus[$pod]}")
    else
        echo "$pod is Running on ${podnode[$pod]}"
    fi
else
    echo "$pod is missing"
    errs=$((errs+1))
    failures+=("Postgres Pods - $pod is missing")
fi
done

#confirm each pod on a distinct node
dupnodes=$(printf '%s\n' ${pods[@]} | sort |uniq -d)
if [ -z $dupnodes]; then
    echo "Postgres Cluster pods are running on distinct nodes."
else
    echo "Postgres cluster pods are colocated!"
    errs=$((errs+1))
    failures+=("Postgres Pods - Postgres Cluster pods are running on the same node.")
fi

unset pods
unset podstatus
unset podnode

# get name, status, and the node on which each postgres persister pod resides
declare -a pods
declare -A podstatus
declare -A podnode

for i in $(kubectl -n sma get pods | grep sma-pg-persister | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n sma --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n sma --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "sma-pg-persister-" ]]; then
  for i in $(seq 0 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "sma-pg-persister-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Postgres Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "sma-pg-persister is missing"
  errs=$((errs+1))
  failures+=("Postgres Pods - sma-pg-persister is missing")
fi

unset pods
unset podstatus
unset podnode

# Test case: pgdb-prune Pod Exists
podname=$(kubectl -n sma get pods | grep sma-pgdb-prune | awk '{print $1}');
podstatus=$(kubectl -n sma --no-headers=true get pod $podname | awk '{print $3}');

if [[ "$podname" =~ "sma-pgdb-prune" ]]; then
  if [[ "$podstatus" =~ "Running" ]]; then
    echo "$podname is Running";
  else
    echo "$podname is $podstatus"
    errs=$((errs+1))
    failures+=("Postgres pod - $podname is $podstatus")
  fi
else
  echo "sma-pgdb-prune pod is missing"
  errs=$((errs+1))
  failures+=("Postgres Pod - sma-pgdb-prune pod is missing")
fi


###################################################
# Test case: Confirm Postgres Persistent Volume Claim
declare -a pvcs
declare -A pvcstatus
declare -A accessmode
declare -A storageclass
declare -A capacity

# get pvc name, status, access mode and storage class
for i in $(kubectl -n sma get pvc | grep postgres | awk '{print $1}');
    do pvcs+=($i);
    status=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $2}')
    pvcstatus[$i]=$status;
    capacity=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $4}')
    pvccap[$i]=$capacity;
    mode=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $5}')
    accessmode[$i]=$mode;
    class=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $6}')
    storageclass[$i]=$class;
done

# Confirm pgdata-sma-postgres-cluster-0 exists
if [[ " ${pvcs[@]} " =~ "pgdata-sma-postgres-cluster-0" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[pgdata-sma-postgres-cluster-0]} " =~ "Bound" ]]; then
        echo "pgdata-sma-postgres-cluster-0 is ${pvcstatus[pgdata-sma-postgres-cluster-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-0 ${pvcstatus[pgdata-sma-postgres-cluster-0]}")
    else
        echo "pvc pgdata-sma-postgres-cluster-0 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[pgdata-sma-postgres-cluster-0]} " =~ "sma-block-replicated" ]]; then
        echo "pgdata-sma-postgres-cluster-0 is ${storageclass[pgdata-sma-postgres-cluster-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-0 ${storageclass[pgdata-sma-postgres-cluster-0]}")
    else
        echo "pgdata-sma-postgres-cluster-0 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[pgdata-sma-postgres-cluster-0]} " =~ "RWO" ]]; then
        echo "pgdata-sma-postgres-cluster-0 has acccess mode ${accessmode[pgdata-sma-postgres-cluster-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-0 ${pvcstatus[pgdata-sma-postgres-cluster-0]}")
    else
        echo "pgdata-sma-postgres-cluster-0 has acccess mode RWO, as expected"
    fi
else
    echo "pgdata-sma-postgres-cluster-0 pvc is missing"
    errs=$((errs+1))
    failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-0 missing")
fi
echo

# Confirm pgdata-sma-postgres-cluster-1 exists
if [[ " ${pvcs[@]} " =~ "pgdata-sma-postgres-cluster-1" ]]; then
    # Confirm PVC is bound
    if [[ ! " ${pvcstatus[pgdata-sma-postgres-cluster-1]} " =~ "Bound" ]]; then
        echo "pgdata-sma-postgres-cluster-1 is ${pvcstatus[pgdata-sma-postgres-cluster-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-1 ${pvcstatus[pgdata-sma-postgres-cluster-1]}")
    else
        echo "pvc pgdata-sma-postgres-cluster-1 is Bound"
    fi
    # Confirm PVC is using sma-block-replicated storage
    if [[ ! " ${storageclass[pgdata-sma-postgres-cluster-1]} " =~ "sma-block-replicated" ]]; then
        echo "pgdata-sma-postgres-cluster-1 is ${storageclass[pgdata-sma-postgres-cluster-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-1 ${storageclass[pgdata-sma-postgres-cluster-1]}")
    else
        echo "pgdata-sma-postgres-cluster-1 is using sma-block-replicated storage, as expected"
    fi
    # Confirm access mode is RWO
    if [[ ! " ${accessmode[pgdata-sma-postgres-cluster-1]} " =~ "RWO" ]]; then
        echo "pgdata-sma-postgres-cluster-1 has acccess mode ${accessmode[pgdata-sma-postgres-cluster-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-1 ${pvcstatus[pgdata-sma-postgres-cluster-1]}")
    else
        echo "pgdata-sma-postgres-cluster-1 has acccess mode RWO, as expected"
    fi
else
    echo "pgdata-sma-postgres-cluster-1 pvc is missing"
    errs=$((errs+1))
    failures+=("Postgres PVCs - pgdata-sma-postgres-cluster-1 missing")
fi

unset pvcs
unset pvcstatus
unset accessmode
unset storageclass
unset capacity

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

#########################################
# Test case: Postgres SMA Schema and Tables Exist
declare -a tables
#   Confirm that the sma schema and it's expected tables exist.
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

#######################################
# Test case: Postgres SMA Schema Version
#   Confirm that the sma schema version has the correct, major, minor, and gen number
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

#########################################
# Test case: Postgres SMA Views Exist
declare -a views
#   Confirm that the sma schema and it's expected tables exist.
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

#######################################
# Test Case: SMA measurementsource Table is Populated
#   Confirm that the sma schema's measurementsource table has been populated with data.

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
# Test Case: Create and Delete Test View in SMA Schema
#   Create a new view called "test" in the sma postgreSQL schema and confirm it exists

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

#####################################
# Test Case: Create, Modify, and Drop Table in SMA Schema
#   Create a test table in the sma schema
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
kubectl -n sma exec -t ${postgrespod} -c postgres -c postgres -- psql sma -U postgres -c "DROP TABLE sma.test"
testtable=$(kubectl -n sma exec -t ${postgrespod} -c postgres -- psql sma -U postgres -c "\\dt sma.*" | grep test | awk '{print $3}')
if [[ ! $testtable ]]; then
    echo "Test table deleted as expected"; else
    errs=$((errs+1))
    failures+=("Postgres Table Deletion - test table not deleted")
fi

#######################################
# Test Case: Leader Running
status=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Leader | cut -d '|' -f 5 | xargs")
if [[ $status == *running* ]]; then
    echo "Leader is Running"; else
    errs=$((errs+1))
    failures+=("No Running Leader found for SMA postgres cluster")
fi

#######################################
# Test Case: Replica Running
status=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Replica | cut -d '|' -f 5 | xargs")
if [[ $status == *running* ]]; then
    echo "Replica is Running"; else
    errs=$((errs+1))
    failures+=("No Running Replica found for SMA postgres cluster")
fi

#######################################
# Test Case: Timeline
ldrtl=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Leader | cut -d '|' -f 6 | xargs")
reptl=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Replica | cut -d '|' -f 6 | xargs")
if [[ $ldrtl == $reptl ]]; then
    echo "Timelines are consistent"; else
    errs=$((errs+1))
    failures+=("Leader and Replica Timelines are Different. Leader: $ldrtl Replica: $reptl")
fi

#######################################
# Test Case: Lag in MB
lag=$(kubectl -n sma exec -it $postgrespod -c postgres -- bash -c "patronictl list | grep Replica | cut -d '|' -f 7 | xargs")
echo "Replica lag in MB: $lag"

########################################
# Test case: Postgres retention period
retention=$(kubectl -n sma describe cm postgres-config |awk '/pg_retention:/{getline; getline; print}')
echo "Postgres retention period: $retention"

#############################################
# Test case: Postgres Resources

# get cpu and memory limits from sma-postgres-cluster statefulsets
pgccpulimit=$(kubectl -n sma describe statefulsets.apps sma-postgres-cluster | grep cpu | head -n 1 |awk '{print $2}')
pgcmemlimit=$(kubectl -n sma describe statefulsets.apps sma-postgres-cluster | grep memory | head -n 1 |awk '{print $2}')
pgcrawmemlimit=$(echo $pgcmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-pg-persister replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-pg-persister | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
pgpcpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
pgpmemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
pgprawmemlimit=$(echo $pgpmemlimit | numfmt --from=auto)

# get cpu and memory limits from sma-pgdb-prune replicasets
for i in $(kubectl -n sma get replicasets.apps |grep sma-pgdb-prune | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
dbpcpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
dbpmemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
dbprawmemlimit=$(echo $dbpmemlimit | numfmt --from=auto)

# get cpu and memory utilization for each sma-postgres-cluster pod
for i in $(kubectl -n sma get pods | grep sma-postgres-cluster | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $pgccpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $pgccpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $pgcrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $pgcmemlimit memory limit."

     # get data storage utilization for each sma-postgres-cluster pod
     volsize=$(kubectl -n sma exec -it  sma-postgres-cluster-0 -c postgres -- df -h | grep data | awk '{print $2}');
     volused=$(kubectl -n sma exec -it  sma-postgres-cluster-0 -c postgres -- df -h | grep data | awk '{print $3}');
     volpct=$(kubectl -n sma exec -it  sma-postgres-cluster-0 -c postgres -- df -h | grep data | awk '{print $5}');
     echo "pod $i is using $volused storage, $volpct of the $volsize total."
     echo
  done

# get cpu and memory utilization for each postgres-persister pod
for i in $(kubectl -n sma get pods | grep sma-pg-persister | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $pgpcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $pgpcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $pgprawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $pgpmemlimit memory limit."
  done

# get cpu and memory utilization for each pgdb-prune pod
for i in $(kubectl -n sma get pods | grep sma-pgdb-prune | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $dbpcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $dbpcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $dbprawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $dbpmemlimit memory limit."
  done

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
echo "Postgres cluster looks healthy"

exit 0