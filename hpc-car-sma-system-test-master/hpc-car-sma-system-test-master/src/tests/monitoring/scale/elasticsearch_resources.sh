#!/bin/bash
# Copyright 2022 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Elasticsearch data persistence service in HPE Cray's Shasta System Monitoring Application"
    echo "reports the CPU, Memory, and Storage utilization of each Elasticsearch pod, as well as the percentage of the limits that"
    echo "that number represents."
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

 exit 0
