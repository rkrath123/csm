#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies a valid environment"
    echo "and initial configuration, as well as the ability to create, modify, and delete an index."
    echo "$0 > sma_component_elasticsearch-\`date +%Y%m%d.%H%M\`"
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

#############################################
# Test Case: Elasticsearch Pods Exists in SMA Namespace

curatorstatus=$(kubectl -n sma get pods | grep elasticsearch-curator | awk '{print $3}')
if [[ ! $curatorstatus ]]; then
    echo "elasticsearch-curator is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-curator not found")
elif [[ ! $curatorstatus == "Running" ]]; then
    echo "elasticsearch-curator is $curatorstatus"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-curator $curatorstatus")
else
    echo "elasticsearch-curator is Running"
fi

master0status=$(kubectl -n sma get pods | grep elasticsearch-master-0 | awk '{print $3}')
if [[ ! $master0status ]]; then
    echo "elasticsearch-master-0 is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-0 not found")
elif [[ ! $master0status == "Running" ]]; then
    echo "elasticsearch-master-0 is $master0status"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-0 $master0status")
else
    echo "elasticsearch-master-0 is Running"
fi

master1status=$(kubectl -n sma get pods | grep elasticsearch-master-1 | awk '{print $3}')
if [[ ! $master1status ]]; then
    echo "elasticsearch-master-1 is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-1 not found")
elif [[ ! $master1status == "Running" ]]; then
    echo "elasticsearch-master-1 is $master1status"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-1 $master0status")
else
    echo "elasticsearch-master-1 is Running"
fi

master2status=$(kubectl -n sma get pods | grep elasticsearch-master-2 | awk '{print $3}')
if [[ ! $master2status ]]; then
    echo "elasticsearch-master-2 is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-2 not found")
elif [[ ! $master2status == "Running" ]]; then
    echo "elasticsearch-master-2 is $master2status"
    errs=$((errs+1))
    failures+=("Elasticsearch Pods - elasticsearch-master-2 $master0status")
else
    echo "elasticsearch-master-2 is Running"
fi

#########################################
# Test Case: Elasticsearch is Running as a K8S Service

declare -a svcs
for i in $(kubectl -n sma get svc | grep elastic | awk '{print $1}');
    do svcs+=($i);
done

if [[ " ${pods[@]} " -eq "elasticsearch" ]]; then
    echo "elasticsearch service exists"
else
    echo "elasticsearch service is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Services - elasticsearch service missing")
fi

if [[ " ${pods[@]} " -eq "elasticsearch-curator" ]]; then
    echo "elasticsearch-curator service exists"
else
    echo "elasticsearch-curator service is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Services - elasticsearch-curator service missing")
fi

if [[ " ${pods[@]} " -eq "elasticsearch-master" ]]; then
    echo "elasticsearch-master service exists"
else
    echo "elasticsearch-master service is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Services - elasticsearch-master service missing")
fi

if [[ " ${pods[@]} " -eq "elasticsearch-master-headless" ]]; then
    echo "elasticsearch-master-headless service exists"
else
    echo "elasticsearch-master-headless service is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch Services - elasticsearch-master-headless service missing")
fi

unset svcs

#######################################
# Test Case: Elasticsearch Persistent Volume Claim
#   Confirm Kubernetes persistent volume claim for elastic is bound
declare -a pvcs
declare -A pvcstatus
declare -A accessmode
declare -A storageclass

# get pvc name, status, access mode and storage class
for i in $(kubectl -n sma get pvc | grep elasticsearch | awk '{print $1}');
    do pvcs+=($i);
    status=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $2}')
    pvcstatus[$i]=$status;
    mode=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $5}')
    accessmode[$i]=$mode;
    class=$(kubectl -n sma --no-headers=true get pvc $i | awk '{print $6}')
    storageclass[$i]=$class;
done

# Confirm PVCs are bound
if [[ " ${pvcs[@]} " =~ "elasticsearch-master-elasticsearch-master-0" ]]; then
    if [[ ! " ${pvcstatus[elasticsearch-master-elasticsearch-master-0]} " =~ "Bound" ]]; then
        echo "elasticsearch-master-elasticsearch-master-0 is ${pvcstatus[elasticsearch-master-elasticsearch-master-0]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - elasticsearch-master-elasticsearch-master-0 ${pvcstatus[elasticsearch-master-elasticsearch-master-0]}")
    else
        echo "elasticsearch-master-elasticsearch-master-0 is Bound"
    fi
else
    echo "elasticsearch-master-elasticsearch-master-0 pvc is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch PVCs - elasticsearch-master-elasticsearch-master-0 missing")
fi

if [[ " ${pvcs[@]} " =~ "elasticsearch-master-elasticsearch-master-1" ]]; then
    if [[ ! " ${pvcstatus[elasticsearch-master-elasticsearch-master-1]} " =~ "Bound" ]]; then
        echo "elasticsearch-master-elasticsearch-master-1 is ${pvcstatus[elasticsearch-master-elasticsearch-master-1]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - elasticsearch-master-elasticsearch-master-1 ${pvcstatus[elasticsearch-master-elasticsearch-master-1]}")
    else
        echo "elasticsearch-master-elasticsearch-master-1 is Bound"
    fi
else
    echo "elasticsearch-master-elasticsearch-master-1 pvc is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch PVCs - elasticsearch-master-elasticsearch-master-1 missing")
fi

if [[ " ${pvcs[@]} " =~ "elasticsearch-master-elasticsearch-master-2" ]]; then
    if [[ ! " ${pvcstatus[elasticsearch-master-elasticsearch-master-2]} " =~ "Bound" ]]; then
        echo "elasticsearch-master-elasticsearch-master-2 is ${pvcstatus[elasticsearch-master-elasticsearch-master-2]}"
        errs=$((errs+1))
        failures+=("Postgres PVCs - elasticsearch-master-elasticsearch-master-2 ${pvcstatus[elasticsearch-master-elasticsearch-master-2]}")
    else
        echo "elasticsearch-master-elasticsearch-master-2 is Bound"
    fi
else
    echo "elasticsearch-master-elasticsearch-master-2 pvc is missing"
    errs=$((errs+1))
    failures+=("Elasticsearch PVCs - elasticsearch-master-elasticsearch-master-2 missing")
fi

unset pvcs
unset pvcstatus
unset accessmode
unset storageclass

###############################
# Test Case: Elasticsearch Replication
#   Verify that ES data is being replicated to multiple servers
declare -a replicas
pricount=0
repcount=0
esmaster=$()
shard=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET 'elasticsearch:9200/_cat/shards/'| cat | head -n 1 | cut -d  ' ' -f 1")
for i in $(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET 'elasticsearch:9200/_cat/shards/$shard'|cut -d ' ' -f 3");
    do replicas+=($i);
done
for i in "${replicas[@]}";
    do if [ $i == "p" ]; then
      pricount=$((pricount+1));
      elif [ $i == "r" ]; then
      repcount=$((repcount+1));
      fi
done
echo "$pricount primary and $repcount replicas in shard $shard"
if [ $pricount -eq $repcount ]; then
    echo "Primary shards are replicated"
else
    echo "Insufficient replicas found for $shard"
    errs=$((errs+1))
    failures+=("Elasticsearch Replication - Missing replica(s) for $shard")
fi

unset replicas

###############################
# Test Case: Elasticsearch Health

#       Confirm that Elasticsearch self-reports a healthy state.
health=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET "elasticsearch:9200/_cat/health?format=yaml"| grep status" | cut -d "\"" -f 2)
result=1
for i in $health; do if [ $i != "green" ]; then result=0
    echo "Elasticsearch self-reports $i health state"
    failures+=("Elasticsearch Health - $health health state")
  fi
done
if [ $result == 1 ]; then echo "Elasticsearch self-reports a healthy state"; else
    errs=$((errs+1))
fi

################################
# Test Case: Expected Elasticsearch Nodes Exist
#   Confirm that Elasticsearch nodes contain localhost.
declare -a nodes

for i in $(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET "elasticsearch:9200/_cat/nodes?h=name"");
    do nodes+=($i);
done


if [[ " ${nodes[@]} " =~ "elasticsearch-master-0" ]]; then
    echo "Node elasticsearch-master-0 is a member of the cluster"
else
    echo "Node elasticsearch-master-0 is not a member of the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Node - elasticsearch-master-0 not in cluster")
fi

if [[ " ${nodes[@]} " =~ "elasticsearch-master-1" ]]; then
    echo "Node elasticsearch-master-1 is a member of the cluster"
else
    echo "Node elasticsearch-master-1 is not a member of the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Node - elasticsearch-master-1 not in cluster")
fi

if [[ " ${nodes[@]} " =~ "elasticsearch-master-2" ]]; then
    echo "Node elasticsearch-master-2 is a member of the cluster"
else
    echo "Node elasticsearch-master-2 is not a member of the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Node - elasticsearch-master-2 not in cluster")
fi

unset nodes

#############################
# Test Case: Expected Elasticsearch Indices Exist
#   Confirm that expected Elasticsearch indices exist.
declare -a indices

for i in $(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET "elasticsearch:9200/_cat/indices?h=index"");
    do indices+=($i);
done


if [[ " ${indices[@]} " =~ "elastalert_status" ]]; then
    echo "Index elastalert_status is in the cluster"
else
    echo "Index elastalert_status is not found in the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Index - elastalert_status not in cluster")
fi

if [[ " ${indices[@]} " =~ ".kibana_1" ]]; then
    echo "Index .kibana_1 is in the cluster"
else
    echo "Index .kibana_1 is not found in the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Index - .kibana_1 not in cluster")
fi

if [[ " ${indices[@]} " =~ "shasta-logs-" ]]; then
    echo "Index shasta-logs- is in the cluster"
else
    echo "Index shasta-logs- is not found in the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Index - shasta-logs- not in cluster")
fi

unset indices

######################
#Test Case: Add Elasticsearch Index
#   Verify the ability to add a test index and confirm that it exists via the REST API.
kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -X PUT "elasticsearch:9200/test?pretty""
testindex=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET "elasticsearch:9200/_cat/indices?h=index" | grep test")
if [ $testindex == "test" ]; then
    echo "Test index created"; else
    echo "Test index creation failure"
    errs=$((errs+1))
    failures+=("Elasticsearch Index Creation - Test index creation failure")
fi

######################
#Test Case: Add Elasticsearch Document
#   Add a document to the test index and verify that it exists.
kubectl -n sma exec -t elasticsearch-master-0 -- curl -sSX PUT "elasticsearch:9200/test/doc/1?pretty" -H 'Content-Type: application/json' -d'{"name": "Seymour Cray" }'
testdoc=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sSI -XGET "elasticsearch:9200/test/doc/1?pretty" | head -n 1 | cut -d ' ' -f 2")
if [ $testdoc == "200" ]; then
    echo "Test document created"; else
    echo "Test document creation failure"
    errs=$((errs+1))
    failures+=("Elasticsearch Document Creation - Test document creation failure")
fi

#####################
#Test Case: Delete Elasticsearch Document
#   Delete a document from the test index and verify that it no longer exists.
kubectl -n sma exec -t elasticsearch-master-0 -- curl -sS -X DELETE "elasticsearch:9200/test/doc/1?pretty"
testdoc=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sSI -XGET "elasticsearch:9200/test/doc/1?pretty" | head -n 1 | cut -d ' ' -f 2")
if [ $testdoc == "404" ]; then
    echo "Test document deleted"; else
    echo "Test document deletion failure"
    errs=$((errs+1))
    failures+=("Elasticsearch Document Deletion - Test document deletion failure")
fi

######################
#Test Case: Delete Elasticsearch Index
#   Delete the test index and verify that it no longer exists.
kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -X DELETE "elasticsearch:9200/test?pretty" "
testindex=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sSI -XGET "elasticsearch:9200/_cat/indices?h=index" | head -n 1 | cut -d ' ' -f 2")
if [ ! $testindex == "404" ]; then
    echo "Test index deleted"; else
    echo "Test index deletion failure"
    errs=$((errs+1))
    failures+=("Elasticsearch Index Deletion - Test index deletion failure")
fi

###############################
#Test Case: Elasticsearch current logs
#The following checks for current elasticsearch data. It should report green status and non-zero log count:

when=$(date +%Y.%m.%d)
(IFS='
';
for i in `kubectl -n sma exec -it elasticsearch-master-0 -- curl -X GET "elasticsearch:9200/_cat/indices?v"|grep $when`;
   do status=$(echo $i | awk '{print $1}');
      count=$(echo $i | awk '{print $7}');
      logname=$(echo $i | awk '{print $3}');
      if [ $status == "green" ]; then
        echo "Current index shasta-logs-$when is green";
      else echo "Current index shasta-logs-$when is $status"
        errs=$((errs+1))
        failures+=("Elasticsearch Activity - Current index shasta-logs-$when is $status")
      fi

      if [ $count -gt 0 ]; then
        echo "Current index $logname is populated with $count logs";
      else echo "Current index $logname is unpopulated"
        errs=$((errs+1))
        failures+=("Elasticsearch Activity - Current index $logname is unpopulated")
      fi
done)

#############################################
# Test case: Elasticsearch Resources

# get cpu and memory limits from elasticsearch-master statefulsets
esmcpulimit=$(kubectl -n sma describe statefulsets.apps elasticsearch-master | grep cpu | head -n 1 |awk '{print $2}')
esmmemlimit=$(kubectl -n sma describe statefulsets.apps elasticsearch-master | grep memory | head -n 1 |awk '{print $2}')
esmrawmemlimit=$(echo $esmmemlimit | numfmt --from=auto)

# get cpu and memory limits from elasticsearch-curator replicasets
for i in $(kubectl -n sma get replicasets.apps |grep elasticsearch-curator | awk '{print $1}');
  do ready=$( kubectl -n sma get replicasets.apps | grep $i | awk '{print $4}');
     if [[ $ready == 1 ]];
        then repset=$(echo $i | awk '{print $1}');
     fi
  done
esccpulimit=$(kubectl -n sma describe replicasets.apps $repset | grep cpu | head -n 1 |awk '{print $2}')
escmemlimit=$(kubectl -n sma describe replicasets.apps $repset | grep memory | head -n 1 |awk '{print $2}')
escrawmemlimit=$(echo $escmemlimit | numfmt --from=auto)

# get cpu and memory utilization for each elasticsearch-master pod
for i in $(kubectl -n sma get pods | grep elasticsearch-master | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $esmcpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $esmcpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $esmrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $esmmemlimit memory limit."

# get data storage utilization for each elasticsearch-master pod
     volsize=$(kubectl -n sma exec -it  elasticsearch-master-0 -- df -h | grep data | awk '{print $2}');
     volused=$(kubectl -n sma exec -it  elasticsearch-master-0 -- df -h | grep data | awk '{print $3}');
     volpct=$(kubectl -n sma exec -it  elasticsearch-master-0 -- df -h | grep data | awk '{print $5}');
     echo "pod $i is using $volused storage, $volpct of the $volsize total."
     echo
  done

# get cpu and memory utilization for each elasticsearch-curator pod
for i in $(kubectl -n sma get pods | grep elasticsearch-curator | awk '{print $1}');
  do podcpu=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $2}');
     rawcpu=$(echo $podcpu | cut -d m -f 1)
     cpu=$(echo "scale=2 ; $rawcpu / 10" | bc)
     pctcpu=$(echo "scale=2 ; $cpu / $esccpulimit" | bc)
     echo "pod $i is using $podcpu cores, $pctcpu% of the $esccpulimit CPU limit."

     podmem=$(kubectl -n sma top pods $i | tail -n 1 | awk '{print $3}');
     rawmem=$(echo $podmem | numfmt --from=auto)
     pctmem=$(echo "scale=2 ; 100 * $rawmem / $escrawmemlimit" | bc)
     echo "pod $i is using $podmem memory, $pctmem% of the $escmemlimit memory limit."
  done

# get elasticsearch JAVA_OPTS
# Xmx specifies the maximum memory allocation pool for a Java virtual machine (JVM)
# Xms specifies the initial memory allocation pool
     xmx=$(kubectl -n sma describe statefulsets.apps elasticsearch-master | grep ES_JAVA_OPTS | awk '{print $2}');
     xms=$(kubectl -n sma describe statefulsets.apps elasticsearch-master | grep ES_JAVA_OPTS | awk '{print $3}');
     echo "Elasticsearch master is configured with an initial heap memory allocation pool of $xms and a max of $xmx."

# get elasticsearch configuration options
     edh=$(kubectl -n sma describe cm elasticsearch-config | awk 'c&&!--c;/es_disk_highwater:/{c=2}')
     edl=$(kubectl -n sma describe cm elasticsearch-config | awk 'c&&!--c;/es_disk_lowwater:/{c=2}')
     edmi=$(kubectl -n sma describe cm elasticsearch-config | awk 'c&&!--c;/es_disk_minimum_indices:/{c=2}')
     emia=$(kubectl -n sma describe cm elasticsearch-config | awk 'c&&!--c;/es_max_index_age:/{c=2}')
     enor=$(kubectl -n sma describe cm elasticsearch-config | awk 'c&&!--c;/es_number_of_replicas:/{c=2}')
     enos=$(kubectl -n sma describe cm elasticsearch-config | awk 'c&&!--c;/es_number_of_shards:/{c=2}')
     echo "es_disk_highwater: $edh"
     echo "es_disk_lowwater: $edl"
     echo "es_disk_minimum_indices: $edmi"
     echo "es_max_index_age: $emia"
     echo "es_number_of_replicas: $enor"
     echo "es_number_of_shards: $enos"

#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch looks healthy"

exit 0
