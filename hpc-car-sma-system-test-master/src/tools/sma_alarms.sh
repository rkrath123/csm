#!/bin/bash
# set -o xtrace
# set -o nounset
# set -o pipefail
# set -o errexit

# Remove all alarms
# cd /etc/sma-data; docker-compose run alarms /usr/local/bin/remove_all_alarms.sh

# docker run --rm -v $PWD/code:/home/code -it ubuntu /bin/bash -c "cp -r /home/code /var/code; /bin/bash"

binpath=`dirname "$0"`
. ${binpath}/sma_tools

date=`date +'%Y%m%d.%H%M'`

docker info > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "unable to talk to the docker daemon...failed"
  exit 1
fi

alarms_container=$(docker images --format="{{.ID}}" cray_sma/alarms)
if [ -z "$alarms_container" ]; then
	echo "SMA alarms container not loaded...failed"
	exit 1
fi
if [ -z "$1" ]; then
	output=sma_ALARMS_${date}.out

	echo "----- sma version" |& tee -a ${output}
	sma_version > ${output} 2>&1

else
	output=$1
fi

echo "----- email notification list" |& tee -a ${output}
cmd="docker run --name=sma_system-test_alarms --network=sma_default --rm $alarms_container monasca notification-list"
runit ${cmd} >> ${output} 2>&1

echo "----- alarm definition list" |& tee -a ${output}
cmd="docker run --name=sma_system-test_alarms --network=sma_default --rm $alarms_container monasca alarm-definition-list"
runit ${cmd} >> ${output} 2>&1

echo "----- alarm list" |& tee -a ${output}
cmd="docker run --name=sma_system-test_alarms --network=sma_default --rm $alarms_container monasca alarm-list"
runit ${cmd} >> ${output} 2>&1

echo "----- alarm history list" |& tee -a ${output}
cmd="docker run --name=sma_system-test_alarms --network=sma_default --rm $alarms_container monasca alarm-history-list"
runit ${cmd} >> ${output} 2>&1

echo "----- alarm state" |& tee -a ${output}
alarms_container=$(docker images --format="{{.ID}}" cray_sma/alarms)
if [ -n "${alarms_container}" ]; then

	alarm_state="$(docker run --name=sma_system-test_alarms --network=sma_default -v /etc/sma-data:/etc/sma-data -v /root/sma-sos:/root/sma-sos --rm $alarms_container /root/sma-sos/check_alarms.py)"

	echo "${alarm_state}" >> ${output} 2>&1
#	num_alarm="$(echo "${alarm_state}" | grep ALARM | wc -l)"
#	num_undet="$(echo "${alarm_state}" | grep UNDETERMINED | wc -l)"
#	echo "$num_alarm ALARM, $num_undet UNDETERMINED alarms were found" >> ${output} 2>&1
else
	echo "SMA alarms container not loaded" >> ${output} 2>&1
fi

if [ -z "$1" ]; then
	echo "DONE: ${output}"
fi

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
